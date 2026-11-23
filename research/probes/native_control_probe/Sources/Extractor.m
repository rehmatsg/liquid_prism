#import "Extractor.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>
static id Sanitize(id o);
static void SnapshotNativeSpecs(NSString *name);
static NSDictionary *ObjectProperties(id o);
static id DeepSpecs(id o, int depth);
static NSDictionary *RootSpecs(void);
static void InstallTimingHooks(void);

static id Safe(id o, NSString *key) { @try { return [o valueForKey:key]; } @catch(NSException *e) { return nil; } }
static id Encode(id o) {
 if(!o) return [NSNull null];
 if([o isKindOfClass:NSNumber.class]) { double x=[o doubleValue]; return isfinite(x)?o:(isnan(x)?@"NaN":(x>0?@"+Infinity":@"-Infinity")); }
 if([o isKindOfClass:NSString.class])return o;
 if([o isKindOfClass:NSValue.class]) {
  const char *t=[o objCType]; NSUInteger size=0; NSGetSizeAndAlignment(t,&size,NULL);
  if(size==80){float m[20];[o getValue:m size:80];NSMutableArray *a=[NSMutableArray new];for(int i=0;i<20;i++)[a addObject:Encode(@(m[i]))];return @{ @"objCType":@(t),@"float32":a };}
  return @{ @"objCType":@(t),@"value":[o description] };
 }
 if([o isKindOfClass:UIColor.class]){CGFloat rr,gg,bb,aa;if([o getRed:&rr green:&gg blue:&bb alpha:&aa])return @{ @"rgba":@[@(rr),@(gg),@(bb),@(aa)],@"description":[o description] };}
 // Filter colors are CGColor objects; class name first avoids arbitrary CF type queries.
 if([NSStringFromClass([o class]) containsString:@"CGColor"] || ([NSStringFromClass([o class]) isEqualToString:@"__NSCFType"] && CFGetTypeID((__bridge CFTypeRef)o)==CGColorGetTypeID())){CGColorRef c=(__bridge CGColorRef)o;size_t n=CGColorGetNumberOfComponents(c);const CGFloat *v=CGColorGetComponents(c);NSMutableArray *a=[NSMutableArray new];for(int i=0;i<n;i++)[a addObject:@(v[i])];CGColorSpaceRef s=CGColorGetColorSpace(c);return @{ @"components":a,@"colorSpace":s?(__bridge_transfer NSString*)CGColorSpaceCopyName(s):@"none" };}
 if([o isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary new];for(id k in o)d[[k description]]=Encode(o[k]);return d;}
 if([o isKindOfClass:NSArray.class]){NSMutableArray*a=[NSMutableArray new];for(id v in o)[a addObject:Encode(v)];return a;}
 return [o description];
}
static void Keys(id o,NSMutableSet *keys){
 if([o isKindOfClass:NSString.class] && [o hasPrefix:@"input"])[keys addObject:o];
 else if([o isKindOfClass:NSArray.class])for(id v in o)Keys(v,keys);
 else if([o isKindOfClass:NSDictionary.class])for(id k in o){Keys(k,keys);Keys(o[k],keys);}
}
static NSDictionary *Filter(id f){
 NSMutableSet *keys=[NSMutableSet new];
 for(Class c=[f class];c;c=class_getSuperclass(c)){unsigned int n=0;objc_property_t*p=class_copyPropertyList(c,&n);for(unsigned int i=0;i<n;i++){NSString*k=@(property_getName(p[i]));if([k hasPrefix:@"input"])[keys addObject:k];}free(p);}
 @try{NSData*d=[NSKeyedArchiver archivedDataWithRootObject:f requiringSecureCoding:NO error:nil];id plist=[NSPropertyListSerialization propertyListWithData:d options:0 format:nil error:nil];Keys(plist,keys);} @catch(NSException*e){}
 NSMutableDictionary *d=[@{@"class":NSStringFromClass([f class]),@"name":Encode(Safe(f,@"name")),@"description":[f description]} mutableCopy];
 NSMutableDictionary *inputs=[NSMutableDictionary new];for(NSString*k in [[keys allObjects] sortedArrayUsingSelector:@selector(compare:)]){id v=Safe(f,k);if(v)inputs[k]=Encode(v);}d[@"inputs"]=inputs;return d;
}
static void Layer(CALayer*l,NSString*path,NSMutableArray*a){
 NSMutableDictionary*d=[@{@"path":path,@"class":NSStringFromClass(l.class),@"name":l.name?:@"",@"frame":NSStringFromCGRect(l.frame),@"bounds":NSStringFromCGRect(l.bounds),@"opacity":@(l.opacity),@"hidden":@(l.hidden),@"backgroundColor":Encode((__bridge id)l.backgroundColor),@"delegateClass":l.delegate?NSStringFromClass([l.delegate class]):@""} mutableCopy];
 if([NSStringFromClass(l.class) containsString:@"SDF"])d[@"sdfProperties"]=ObjectProperties(l);
 CATransform3D tr=l.transform;
 d[@"transform"]=@[@(tr.m11),@(tr.m12),@(tr.m21),@(tr.m22),@(tr.m41),@(tr.m42)];
 d[@"anchorPoint"]=NSStringFromCGPoint(l.anchorPoint);
 d[@"position"]=NSStringFromCGPoint(l.position);
 d[@"contentsScale"]=@(l.contentsScale);
 d[@"masksToBounds"]=@(l.masksToBounds);
 d[@"shadowColor"]=Encode((__bridge id)l.shadowColor);d[@"shadowOpacity"]=@(l.shadowOpacity);d[@"shadowRadius"]=@(l.shadowRadius);d[@"shadowOffset"]=NSStringFromCGSize(l.shadowOffset);d[@"cornerRadius"]=@(l.cornerRadius);
 if([l.delegate isKindOfClass:UIView.class]){UIView*v=(id)l.delegate;d[@"accessibilityIdentifier"]=v.accessibilityIdentifier?:@"";d[@"windowFrame"]=NSStringFromCGRect([v convertRect:v.bounds toView:v.window]);d[@"viewAlpha"]=@(v.alpha);d[@"traitUserInterfaceStyle"]=@(v.traitCollection.userInterfaceStyle);d[@"traitAccessibilityContrast"]=@(v.traitCollection.accessibilityContrast);d[@"tintAdjustmentMode"]=@(v.tintAdjustmentMode);d[@"tintColor"]=Encode([v.tintColor resolvedColorWithTraitCollection:v.traitCollection]);if([v isKindOfClass:UILabel.class])d[@"text"]=[(UILabel*)v text]?:@"";}
 NSMutableArray*f=[NSMutableArray new];for(id x in l.filters)[f addObject:Filter(x)];if(f.count)d[@"filters"]=f;if(l.compositingFilter)d[@"compositingFilter"]=Filter(l.compositingFilter);
 id effect=Safe(l,@"effect");if(effect){NSMutableDictionary*e=[NSMutableDictionary new];for(Class c=[effect class];c && c!=NSObject.class;c=class_getSuperclass(c)){unsigned n=0;objc_property_t*p=class_copyPropertyList(c,&n);for(unsigned i=0;i<n;i++){NSString*k=@(property_getName(p[i]));if(![@[@"description",@"debugDescription",@"superclass",@"hash"] containsObject:k]){id v=Safe(effect,k);if(v)e[k]=Encode(v);}}free(p);}d[@"effect"]=e;}
 [a addObject:d];int i=0;for(CALayer*s in l.sublayers)Layer(s,[path stringByAppendingFormat:@"/%d",i++],a);if(l.mask)Layer(l.mask,[path stringByAppendingString:@"/mask"],a);
}
void ExtractGlass(NSString*name,NSDictionary*configuration){
 SnapshotNativeSpecs(name);
 NSMutableArray*a=[NSMutableArray new];int i=0;for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class])for(UIWindow*w in [(UIWindowScene*)s windows])Layer(w.layer,[NSString stringWithFormat:@"window%d",i++],a);
 NSMutableDictionary*colors=[NSMutableDictionary new];for(NSString*n in @[@"systemBlueColor",@"systemGreenColor",@"systemOrangeColor",@"systemPinkColor",@"systemRedColor",@"systemYellowColor",@"systemPurpleColor",@"systemTealColor",@"systemCyanColor",@"systemIndigoColor",@"systemMintColor",@"systemBrownColor",@"labelColor",@"secondaryLabelColor",@"tertiaryLabelColor",@"quaternaryLabelColor",@"systemFillColor",@"secondarySystemFillColor",@"tertiarySystemFillColor",@"quaternarySystemFillColor"]){UIColor*c=Safe(UIColor.class,n);if(c){colors[n]=@{@"light":Encode([c resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]]),@"dark":Encode([c resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]])};}}
 NSDictionary*d=@{@"configuration":configuration,@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"timestamp":@([[NSDate date]timeIntervalSince1970]),@"layers":a,@"semanticColors":colors,@"reduceTransparency":@(UIAccessibilityIsReduceTransparencyEnabled()),@"darkerSystemColors":@(UIAccessibilityDarkerSystemColorsEnabled())};
 NSURL*dir=[[NSFileManager defaultManager]URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;dir=[dir URLByAppendingPathComponent:@"extracted"];[[NSFileManager defaultManager]createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];NSData*json=nil;@try{json=[NSJSONSerialization dataWithJSONObject:Sanitize(d) options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];}@catch(NSException*e){json=nil;}if(json)[json writeToURL:[dir URLByAppendingPathComponent:[name stringByAppendingString:@".json"]] atomically:YES];
}

static id Sanitize(id o){
 if([o isKindOfClass:NSNumber.class]){double x=[o doubleValue];return isfinite(x)?o:(isnan(x)?@"NaN":(x>0?@"+Infinity":@"-Infinity"));}
 if([o isKindOfClass:NSArray.class]){NSMutableArray*a=[NSMutableArray new];for(id v in o)[a addObject:Sanitize(v)];return a;}
 if([o isKindOfClass:NSDictionary.class]){NSMutableDictionary*d=[NSMutableDictionary new];for(id k in o)d[k]=Sanitize(o[k]);return d;}
 if([o isKindOfClass:NSString.class]||[o isKindOfClass:NSNull.class])return o;
 return [o description];
}
static NSNumber *N(double x){ return @(isfinite(x)?x:0); }
static NSString *LastError;
// ---- Motion log: presentation-layer samples every display frame, animation objects, touches.
static NSMutableArray *Frames, *Animations, *Touches; static NSMutableSet *SeenAnimations;
static NSString *MotionName; static NSDictionary *MotionConfiguration; static CFTimeInterval MotionStart; static double MotionSeconds; static CFTimeInterval TouchStart=-1; static CADisplayLink *Link;
static BOOL Interesting(CALayer *l){
 if([l.delegate isKindOfClass:UIView.class]) return YES;
 if(l.filters.count||l.compositingFilter||l.shadowOpacity>0)return YES;
 NSString*c=NSStringFromClass(l.class);
 return [c isEqualToString:@"CABackdropLayer"]||[c isEqualToString:@"CASDFLayer"]||[c containsString:@"Glass"]||[c containsString:@"Portal"];
}
static NSDictionary *Timing(CAMediaTimingFunction*t){ if(!t)return nil; float a[2],b[2];[t getControlPointAtIndex:1 values:a];[t getControlPointAtIndex:2 values:b];return @{@"c1":@[@(a[0]),@(a[1])],@"c2":@[@(b[0]),@(b[1])]}; }
static NSDictionary *Animation(CAAnimation*a){
 NSMutableDictionary*d=[@{@"class":NSStringFromClass(a.class),@"duration":@(a.duration),@"beginTime":@(a.beginTime),@"speed":@(a.speed),@"timeOffset":@(a.timeOffset),@"fillMode":a.fillMode?:@"",@"removedOnCompletion":@(a.removedOnCompletion)} mutableCopy];
 if(a.timingFunction)d[@"timingFunction"]=Timing(a.timingFunction);
 if([a isKindOfClass:CAPropertyAnimation.class]){d[@"keyPath"]=[(CAPropertyAnimation*)a keyPath]?:@"";d[@"additive"]=@([(CAPropertyAnimation*)a isAdditive]);}
 if([a isKindOfClass:CABasicAnimation.class]){CABasicAnimation*b=(id)a;d[@"fromValue"]=Encode(b.fromValue);d[@"toValue"]=Encode(b.toValue);d[@"byValue"]=Encode(b.byValue);}
 if([a isKindOfClass:CAKeyframeAnimation.class]){CAKeyframeAnimation*k=(id)a;d[@"values"]=Encode(k.values);d[@"keyTimes"]=Encode(k.keyTimes);d[@"calculationMode"]=k.calculationMode?:@"";}
 if([a isKindOfClass:CASpringAnimation.class]){CASpringAnimation*s=(id)a;d[@"mass"]=@(s.mass);d[@"stiffness"]=@(s.stiffness);d[@"damping"]=@(s.damping);d[@"initialVelocity"]=@(s.initialVelocity);d[@"settlingDuration"]=@(s.settlingDuration);
  if([s respondsToSelector:@selector(perceptualDuration)]){d[@"perceptualDuration"]=@(s.perceptualDuration);d[@"bounce"]=@(s.bounce);}}
 if([a isKindOfClass:CAAnimationGroup.class]){NSMutableArray*g=[NSMutableArray new];for(CAAnimation*x in [(CAAnimationGroup*)a animations])[g addObject:Animation(x)];d[@"animations"]=g;}
 return d;
}
static void SampleFlex(UIView *v, NSMutableArray *out) {
 for(id f in v.interactions) if([NSStringFromClass([f class]) containsString:@"FlexInteraction"]) {
  NSMutableDictionary *d=[@{@"view":NSStringFromClass(v.class),@"layerID":[NSString stringWithFormat:@"%p",v.layer],@"preferredVariant":Encode(Safe(f,@"preferredVariant"))} mutableCopy];
  for(NSString *k in @[@"scaleX",@"scaleY",@"driftX",@"driftY",@"translationY"]) {
   id a=Safe(f,k);if(a) d[k]=@{@"value":Encode(Safe(a,@"value")),@"presentationValue":Encode(Safe(a,@"presentationValue")),@"velocity":Encode(Safe(a,@"velocity"))};
  }
  [out addObject:d];
 }
 for(UIView *s in v.subviews)SampleFlex(s,out);
}
static void Sample(CALayer*l,CALayer*windowPres,CALayer*windowModel,NSString*path,CFTimeInterval t,NSMutableArray*out){
 NSMutableArray*below=[NSMutableArray new];int i=0;for(CALayer*s in l.sublayers)Sample(s,windowPres,windowModel,[path stringByAppendingFormat:@"/%d",i++],t,below);
 if(Interesting(l)||below.count){
  CALayer*p=l.presentationLayer; BOOL pres=(p!=nil && windowPres!=nil); if(!pres)p=l;
  CGRect win=pres?[p convertRect:p.bounds toLayer:windowPres]:[l convertRect:l.bounds toLayer:windowModel];
  CATransform3D m=p.transform;
  NSMutableDictionary*d=[@{@"id":[NSString stringWithFormat:@"%p",l],@"path":path,@"class":NSStringFromClass(l.class),@"name":l.name?:@"",@"pres":@(pres),
   @"win":@[N(win.origin.x),N(win.origin.y),N(win.size.width),N(win.size.height)],
   @"bounds":@[N(p.bounds.size.width),N(p.bounds.size.height)],@"position":@[N(p.position.x),N(p.position.y)],
   @"m":@[N(m.m11),N(m.m12),N(m.m21),N(m.m22),N(m.m41),N(m.m42),N(m.m33)],@"opacity":N(p.opacity),@"hidden":@(p.hidden),
   @"cornerRadius":N(p.cornerRadius),@"shadow":@[N(p.shadowOpacity),N(p.shadowRadius),N(p.shadowOffset.width),N(p.shadowOffset.height)],@"shadowColor":Encode((__bridge id)p.shadowColor)} mutableCopy];
  if(l.shadowPath)d[@"shadowPath"]=@YES;
  NSMutableArray*fs=[NSMutableArray new];for(id f in p.filters){NSMutableDictionary*e=[@{@"name":Encode(Safe(f,@"name")),@"class":NSStringFromClass([f class])} mutableCopy];
   for(NSString*k in @[@"inputAmount",@"inputRadius",@"inputColorMatrix",@"inputFaceOpacity",@"inputBlurRadius",@"inputRefractionAmount",@"inputAberrationAmount",@"inputEdgeStart",@"inputEdgeEnd",@"inputScale",@"inputOpacity"]){id v=Safe(f,k);if(v)e[k]=Encode(v);}
   [fs addObject:e];}
  if(fs.count)d[@"filters"]=fs;
  id effect=Safe(p,@"effect");if(effect){NSMutableDictionary*e=[NSMutableDictionary new];for(NSString*k in @[@"curvature",@"keyAmount",@"fillAmount",@"diffuseAmountScale",@"keyAngle",@"fillAngle"]){id v=Safe(effect,k);if(v)e[k]=Encode(v);}d[@"effect"]=e;}
  NSArray*keys=l.animationKeys;if(keys.count){d[@"animationKeys"]=keys;for(NSString*k in keys){NSString*seen=[NSString stringWithFormat:@"%p|%@",l,k];if(![SeenAnimations containsObject:seen]){[SeenAnimations addObject:seen];CAAnimation*a=[l animationForKey:k];if(a)[Animations addObject:@{@"t":@(t),@"id":[NSString stringWithFormat:@"%p",l],@"path":path,@"class":NSStringFromClass(l.class),@"key":k,@"animation":Animation(a)}];}}}
  [out addObject:d];
 }
 [out addObjectsFromArray:below];
}
@interface MotionTick:NSObject @end
@implementation MotionTick
-(void)tick:(CADisplayLink*)link{
 CFTimeInterval t=link.timestamp-MotionStart; CFTimeInterval began=CACurrentMediaTime();
 NSMutableArray*layers=[NSMutableArray new];NSMutableArray*flex=[NSMutableArray new];int i=0;
 for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class])for(UIWindow*w in [(UIWindowScene*)s windows]){@try{SampleFlex(w,flex);Sample(w.layer,w.layer.presentationLayer,w.layer,[NSString stringWithFormat:@"window%d",i++],t,layers);}@catch(NSException*e){LastError=[NSString stringWithFormat:@"sample: %@ %@",e.name,e.reason];}}
 [Frames addObject:@{@"t":N(t),@"target":N(link.targetTimestamp-MotionStart),@"cost":N(CACurrentMediaTime()-began),@"layers":layers,@"flex":flex}];
 if(TouchStart<0){while(Frames.count>40)[Frames removeObjectAtIndex:0];}
 if((TouchStart>=0 && t-TouchStart>=MotionSeconds) || t>=25){[link invalidate];Link=nil;
  NSDictionary*d=@{@"configuration":MotionConfiguration,@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"screenScale":@(UIScreen.mainScreen.scale),@"maxFPS":@(UIScreen.mainScreen.maximumFramesPerSecond),@"frames":Frames,@"animations":Animations,@"touches":Touches};
  NSURL*dir=[[NSFileManager defaultManager]URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;dir=[dir URLByAppendingPathComponent:@"motion"];[[NSFileManager defaultManager]createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSData*json=nil;@try{json=[NSJSONSerialization dataWithJSONObject:Sanitize(d) options:NSJSONWritingSortedKeys error:nil];}@catch(NSException*e){LastError=[NSString stringWithFormat:@"json: %@ %@",e.name,e.reason];}
  if(json)[json writeToURL:[dir URLByAppendingPathComponent:[MotionName stringByAppendingString:@".json"]] atomically:YES];
  if(LastError)[LastError writeToURL:[dir URLByAppendingPathComponent:[MotionName stringByAppendingString:@".error"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [[NSData data] writeToURL:[dir URLByAppendingPathComponent:[MotionName stringByAppendingString:@".done"]] atomically:YES];
  ExtractGlass([MotionName stringByAppendingString:@"-model-end"],MotionConfiguration);}
}
@end
@interface UIWindow (PrismMotionTouches)
- (void)prism_motion_sendEvent:(UIEvent *)event;
@end
@implementation UIWindow (PrismMotionTouches)
- (void)prism_motion_sendEvent:(UIEvent *)event {
 [self prism_motion_sendEvent:event];
 if(!Touches||!Link)return;
 for(UITouch*touch in event.allTouches){
 if(touch.phase==UITouchPhaseBegan) {
   double stamp=touch.timestamp-MotionStart;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
     ExtractGlass([MotionName stringByAppendingFormat:@"-contact-%.3f",stamp],MotionConfiguration);
   });
 }
 if(TouchStart<0&&touch.phase==UITouchPhaseBegan)TouchStart=touch.timestamp-MotionStart;CGPoint p=[touch locationInView:nil];[Touches addObject:@{@"t":N(touch.timestamp-MotionStart),@"phase":@(touch.phase),@"x":N(p.x),@"y":N(p.y),@"view":touch.view?NSStringFromClass(touch.view.class):@""}];}
}
@end
void StartMotionLog(NSString*name,NSDictionary*configuration,double seconds){
 Frames=[NSMutableArray new];Animations=[NSMutableArray new];Touches=[NSMutableArray new];SeenAnimations=[NSMutableSet new];
 InstallTimingHooks();
 MotionName=name;MotionConfiguration=configuration;MotionSeconds=seconds;MotionStart=CACurrentMediaTime();TouchStart=-1;
 static dispatch_once_t once;dispatch_once(&once,^{method_exchangeImplementations(class_getInstanceMethod(UIWindow.class,@selector(sendEvent:)),class_getInstanceMethod(UIWindow.class,@selector(prism_motion_sendEvent:)));});
 static MotionTick*target;target=[MotionTick new];Link=[CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
 Link.preferredFrameRateRange=CAFrameRateRangeMake(60,120,120);[Link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
 ExtractGlass([name stringByAppendingString:@"-model-start"],configuration);
}

// Research only: inspect native geometry, typography and timing objects without
// attempting to reconstruct these values from rendered pixels.
static NSMutableArray *TimingCalls;
static NSDictionary *ObjectProperties(id o) {
 NSMutableDictionary *out=[NSMutableDictionary new];
 for(Class c=[o class]; c && c!=UIView.class && c!=CALayer.class && c!=NSObject.class; c=class_getSuperclass(c)) {
   unsigned n=0;objc_property_t *ps=class_copyPropertyList(c,&n);
   for(unsigned i=0;i<n;i++) {
     NSString *k=@(property_getName(ps[i]));
     if([@[@"description",@"debugDescription",@"superclass",@"hash",@"nextResponder"] containsObject:k])continue;
     id v=Safe(o,k);if(v)out[k]=Encode(v);
   }
   free(ps);
 }
 return out;
}
static NSDictionary *TimingObject(id o) {
 NSMutableDictionary *d=[@{@"class":NSStringFromClass([o class]),@"properties":ObjectProperties(o)} mutableCopy];
 for(NSString *k in @[@"mass",@"stiffness",@"damping",@"dampingRatio",@"initialVelocity",@"duration",@"bounce",@"perceptualDuration",@"settlingDuration",@"_spring",@"spring",@"timingParameters"]){id v=Safe(o,k);if(v)d[k]=Encode(v);}
 return d;
}
static void TimingRecord(id obj, NSString *method, NSDictionary *args) {
 if(!TimingCalls)TimingCalls=[NSMutableArray new];
 if(TimingCalls.count>2000)return;
 [TimingCalls addObject:@{@"t":@(CACurrentMediaTime()-MotionStart),@"method":method,@"object":TimingObject(obj),@"arguments":args,@"stack":[NSThread callStackSymbols]}];
}
static void InstallTimingHooks(void) {
 static dispatch_once_t once;dispatch_once(&once,^{
  Class behavior=NSClassFromString(@"UIViewSpringAnimationBehavior");
  SEL behaviorSel=NSSelectorFromString(@"initWithDampingRatio:response:");
  Method bm=class_getInstanceMethod(behavior,behaviorSel);IMP bo=method_getImplementation(bm);
  method_setImplementation(bm,imp_implementationWithBlock(^id(id self,double damping,double response){
   id obj=((id(*)(id,SEL,double,double))bo)(self,behaviorSel,damping,response);
   TimingRecord(obj,@"UIViewSpringAnimationBehavior.init",@{@"dampingRatio":@(damping),@"response":@(response)});return obj;
  }));
  SEL setSel=NSSelectorFromString(@"setDampingRatio:response:");Method setM=class_getInstanceMethod(behavior,setSel);IMP setO=method_getImplementation(setM);
  method_setImplementation(setM,imp_implementationWithBlock(^(id self,double ratio,double response){
   ((void(*)(id,SEL,double,double))setO)(self,setSel,ratio,response);
   TimingRecord(self,@"UIViewSpringAnimationBehavior.set",@{@"dampingRatio":@(ratio),@"response":@(response)});
  }));
  SEL trackSel=NSSelectorFromString(@"setTrackingDampingRatio:response:dampingRatioSmoothing:responseSmoothing:");Method trackM=class_getInstanceMethod(behavior,trackSel);IMP trackO=method_getImplementation(trackM);
  method_setImplementation(trackM,imp_implementationWithBlock(^(id self,double ratio,double response,double ratioSmoothing,double responseSmoothing){
   ((void(*)(id,SEL,double,double,double,double))trackO)(self,trackSel,ratio,response,ratioSmoothing,responseSmoothing);
   TimingRecord(self,@"UIViewSpringAnimationBehavior.tracking",@{@"dampingRatio":@(ratio),@"response":@(response),@"dampingRatioSmoothing":@(ratioSmoothing),@"responseSmoothing":@(responseSmoothing)});
  }));
  Class c=UISpringTimingParameters.class;
  SEL sel=@selector(initWithMass:stiffness:damping:initialVelocity:);
  Method m=class_getInstanceMethod(c,sel);IMP orig=method_getImplementation(m);
  method_setImplementation(m,imp_implementationWithBlock(^id(id self,CGFloat mass,CGFloat stiffness,CGFloat damping,CGVector velocity){
   id obj=((id(*)(id,SEL,CGFloat,CGFloat,CGFloat,CGVector))orig)(self,sel,mass,stiffness,damping,velocity);
   TimingRecord(obj,NSStringFromSelector(sel),@{@"mass":@(mass),@"stiffness":@(stiffness),@"damping":@(damping),@"initialVelocity":NSStringFromCGVector(velocity)});return obj;
  }));
  sel=@selector(initWithDampingRatio:initialVelocity:);m=class_getInstanceMethod(c,sel);IMP origRatio=method_getImplementation(m);SEL ratioSel=sel;
  method_setImplementation(m,imp_implementationWithBlock(^id(id self,CGFloat damping,CGVector velocity){
   id obj=((id(*)(id,SEL,CGFloat,CGVector))origRatio)(self,ratioSel,damping,velocity);
   TimingRecord(obj,NSStringFromSelector(ratioSel),@{@"dampingRatio":@(damping),@"initialVelocity":NSStringFromCGVector(velocity)});return obj;
  }));
  c=UIViewPropertyAnimator.class;sel=@selector(initWithDuration:timingParameters:);m=class_getInstanceMethod(c,sel);IMP origAnimator=method_getImplementation(m);SEL animatorSel=sel;
  method_setImplementation(m,imp_implementationWithBlock(^id(id self,NSTimeInterval duration,id timing){
   id obj=((id(*)(id,SEL,NSTimeInterval,id))origAnimator)(self,animatorSel,duration,timing);
   TimingRecord(obj,NSStringFromSelector(animatorSel),@{@"duration":@(duration),@"timing":TimingObject(timing)});return obj;
  }));
 });
}
static void ViewSpecs(UIView *v, NSString *path, NSMutableArray *out) {
 NSMutableDictionary *d=[@{@"path":path,@"class":NSStringFromClass(v.class),@"bounds":NSStringFromCGRect(v.bounds),@"frame":NSStringFromCGRect(v.frame),@"win":NSStringFromCGRect([v convertRect:v.bounds toView:v.window]),@"transform":NSStringFromCGAffineTransform(v.transform),@"alpha":@(v.alpha),@"hidden":@(v.hidden),@"layerID":[NSString stringWithFormat:@"%p",v.layer]} mutableCopy];
 if([v isKindOfClass:UILabel.class]){UILabel *l=(id)v;d[@"text"]=l.text?:@"";d[@"font"]=@{@"name":l.font.fontName,@"size":@(l.font.pointSize),@"ascender":@(l.font.ascender),@"descender":@(l.font.descender),@"lineHeight":@(l.font.lineHeight),@"capHeight":@(l.font.capHeight),@"xHeight":@(l.font.xHeight),@"traits":Encode(l.font.fontDescriptor.fontAttributes)};d[@"baselineAdjustment"]=@(l.baselineAdjustment);}
 if([v isKindOfClass:UIImageView.class]){UIImageView *iv=(id)v;UIImage *im=iv.image;if(im){d[@"image"]=@{@"size":NSStringFromCGSize(im.size),@"scale":@(im.scale),@"isSymbol":@(im.isSymbolImage),@"baseline":@(im.baselineOffsetFromBottom),@"symbolConfiguration":Encode(im.symbolConfiguration),@"alignmentInsets":NSStringFromUIEdgeInsets(im.alignmentRectInsets)};}d[@"contentMode"]=@(iv.contentMode);
 if(im){ CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();unsigned char pixel[4]={0};CGContextRef cx=CGBitmapContextCreate(pixel,1,1,8,4,cs,kCGImageAlphaPremultipliedLast);CGContextTranslateCTM(cx,-im.size.width*im.scale/2,-im.size.height*im.scale/2);CGContextDrawImage(cx,CGRectMake(0,0,im.size.width*im.scale,im.size.height*im.scale),im.CGImage);d[@"imageCenterRGBA"]=@[@(pixel[0]),@(pixel[1]),@(pixel[2]),@(pixel[3])];CGContextRelease(cx);CGColorSpaceRelease(cs);}
}
 if([v respondsToSelector:NSSelectorFromString(@"image")]){
  UIImage *im=Safe(v,@"image");if([im isKindOfClass:UIImage.class])d[@"symbolImage"]=@{@"size":NSStringFromCGSize([im size]),@"symbolConfiguration":Encode([im symbolConfiguration]),@"scale":@([im scale]),@"baseline":@([im baselineOffsetFromBottom])};
 }
 NSString *cls=NSStringFromClass(v.class);
 if([cls containsString:@"LensView"]||[cls containsString:@"PlatterView"]||[cls containsString:@"Switch"]||[cls containsString:@"Slider"]||[cls containsString:@"Segment"]||[cls isEqualToString:@"UITabBar"]){
  NSMutableDictionary *specs=[NSMutableDictionary new];
  for(NSString *k in @[@"spec",@"flexInteraction",@"_visualProvider",@"morphTargetSpringBehavior",@"lifted",@"liftedContentMode",@"warpsContentBelow",@"_visualElement",@"visualElement",@"on",@"value",@"minimumValue",@"maximumValue",@"selectedSegmentIndex",@"onTintColor",@"thumbTintColor",@"minimumTrackTintColor",@"maximumTrackTintColor",@"_thumbView",@"_styleProvider"]){
   if([v respondsToSelector:NSSelectorFromString(k)]){id value=Safe(v,k);if(value)specs[k]=DeepSpecs(value,0);}
  }
   NSMutableArray *interactions=[NSMutableArray new];for(id interaction in v.interactions)if([NSStringFromClass([interaction class]) containsString:@"FlexInteraction"])[interactions addObject:DeepSpecs(interaction,0)];if(interactions.count)specs[@"attachedInteractions"]=interactions;
  if([v isKindOfClass:UISegmentedControl.class]){id provider=Safe(v,@"_styleProvider");if(provider)specs[@"styleProvider"]=ObjectProperties(provider);}
  d[@"nativeSpecs"]=specs;
 }
 [out addObject:d];int i=0;for(UIView *s in v.subviews)ViewSpecs(s,[path stringByAppendingFormat:@"/%d",i++],out);
}
static void SnapshotNativeSpecs(NSString *name) {
 NSMutableArray *views=[NSMutableArray new];int i=0;
 for(UIScene *s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class])for(UIWindow *w in [(UIWindowScene*)s windows])ViewSpecs(w,[NSString stringWithFormat:@"window%d",i++],views);
 unsigned n=0;Class *classes=objc_copyClassList(&n);NSMutableDictionary *catalog=[NSMutableDictionary new];
 for(unsigned i=0;i<n;i++){
  NSString *name=NSStringFromClass(classes[i]);
  if(!([name containsString:@"Switch"]||[name containsString:@"Slider"]||[name containsString:@"Segment"]||[name containsString:@"Animatable"]||[name containsString:@"Image"]||[name containsString:@"TabButton"]||[name containsString:@"Flex"]||[name containsString:@"Platter"]||[name containsString:@"Solarium"]||[name containsString:@"Spec"]||[name containsString:@"Spring"]||[name containsString:@"Fluid"]||[name containsString:@"TabBar"]||[name containsString:@"SDF"]||[name containsString:@"Lens"]))continue;
  if(!([name hasPrefix:@"_UI"]||[name hasPrefix:@"UI"]||[name hasPrefix:@"UIKit"]||[name hasPrefix:@"CA"]))continue;
  unsigned count=0;Method *methods=class_copyMethodList(classes[i],&count);NSMutableArray *ms=[NSMutableArray new];for(unsigned j=0;j<count;j++)[ms addObject:@{@"name":NSStringFromSelector(method_getName(methods[j])),@"type":@(method_getTypeEncoding(methods[j])?:"")}];free(methods);
  objc_property_t *ps=class_copyPropertyList(classes[i],&count);NSMutableArray *props=[NSMutableArray new];for(unsigned j=0;j<count;j++)[props addObject:@{@"name":@(property_getName(ps[j])),@"type":@(property_getAttributes(ps[j])?:"")}];free(ps);
  Ivar *ivars=class_copyIvarList(classes[i],&count);NSMutableArray *ivs=[NSMutableArray new];for(unsigned j=0;j<count;j++)[ivs addObject:@{@"name":@(ivar_getName(ivars[j])),@"type":@(ivar_getTypeEncoding(ivars[j])?:""),@"offset":@(ivar_getOffset(ivars[j]))}];free(ivars);
  Method *cms=class_copyMethodList(object_getClass(classes[i]),&count);NSMutableArray *cma=[NSMutableArray new];for(unsigned j=0;j<count;j++)[cma addObject:@{@"name":NSStringFromSelector(method_getName(cms[j])),@"type":@(method_getTypeEncoding(cms[j])?:"")}];free(cms);
  catalog[name]=@{@"super":NSStringFromClass(class_getSuperclass(classes[i])),@"methods":ms,@"classMethods":cma,@"properties":props,@"ivars":ivs};
 }free(classes);
 NSURL *dir=[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"specs"];
 [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
 NSDictionary *d=@{@"rootSpecs":RootSpecs(),@"views":views,@"classes":catalog,@"timingCalls":TimingCalls?:@[],@"screen":@{@"bounds":NSStringFromCGRect(UIScreen.mainScreen.bounds),@"scale":@(UIScreen.mainScreen.scale)}};
 NSData *data=[NSJSONSerialization dataWithJSONObject:Sanitize(d) options:NSJSONWritingSortedKeys error:nil];[data writeToURL:[dir URLByAppendingPathComponent:[name stringByAppendingString:@".json"]] atomically:YES];
}

static id DeepSpecs(id o, int depth) {
 if(!o)return NSNull.null;
 NSString *cls=NSStringFromClass([o class]);
 BOOL inspect=[cls containsString:@"Spec"]||[cls containsString:@"Settings"]||[cls containsString:@"AnimationBehavior"]||[cls containsString:@"AnimatableFloat"]||[cls containsString:@"AnimatableProperty"]||[cls isEqualToString:@"_UIFlexInteraction"];
 if(depth>5 || !inspect)return Encode(o);
 NSMutableDictionary *props=[NSMutableDictionary new];
 for(Class c=[o class];c && c!=NSObject.class && c!=UIView.class && c!=NSClassFromString(@"PTSettings");c=class_getSuperclass(c)){
  unsigned n=0;objc_property_t *ps=class_copyPropertyList(c,&n);
  for(unsigned i=0;i<n;i++) {
   NSString *key=@(property_getName(ps[i]));
   if([@[@"description",@"debugDescription",@"superclass",@"hash"] containsObject:key])continue;
   id v=Safe(o,key);if(v)props[key]=DeepSpecs(v,depth+1);
  }free(ps);
 }
 return @{@"class":cls,@"properties":props};
}
void PrepareNativeInspection(void) {MotionStart=CACurrentMediaTime();InstallTimingHooks();}

static NSDictionary *RootSpecs(void) {
 NSMutableDictionary *out=[NSMutableDictionary new];
 Class sw=NSClassFromString(@"_UISwitchSettings");SEL shared=NSSelectorFromString(@"sharedSettings");if([sw respondsToSelector:shared])out[@"_UISwitchSettings"]=DeepSpecs(((id(*)(id,SEL))objc_msgSend)(sw,shared),0);
 unsigned count=0;Class *classes=objc_copyClassList(&count);NSMutableArray *names=[NSMutableArray new];
 for(unsigned i=0;i<count;i++){NSString *n=NSStringFromClass(classes[i]);if([n containsString:@"SettingsDomain"] && ([n containsString:@"Switch"]||[n containsString:@"Slider"]||[n containsString:@"Segment"]||[n containsString:@"FlexInteraction"]))[names addObject:n];}free(classes);
 for(NSString *name in names){
  Class c=NSClassFromString(name);SEL sel=NSSelectorFromString(@"rootSettings");
  if([c respondsToSelector:sel]){id obj=((id(*)(id,SEL))objc_msgSend)(c,sel);out[name]=DeepSpecs(obj,0);}
 }
 return out;
}
