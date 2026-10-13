#import "Extractor.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
// Research only: records every layer's filters (all input keys, found from the
// class properties and the keyed archive) 1.0 s after each touch begins, then
// writes a marker so the runner can screenshot the held state.
static NSString *Run; static int TouchCount;
static id Safe(id o, NSString *k){ @try { return [o valueForKey:k]; } @catch(NSException *e){ return nil; } }
static id Enc(id o){
 if(!o) return [NSNull null];
 if([o isKindOfClass:NSNumber.class]){ double x=[o doubleValue]; return isfinite(x)?o:@"nonfinite"; }
 if([o isKindOfClass:NSString.class]) return o;
 if([o isKindOfClass:NSArray.class]){ NSMutableArray *a=[NSMutableArray new]; for(id v in o)[a addObject:Enc(v)]; return a; }
 if([o isKindOfClass:NSDictionary.class]){ NSMutableDictionary *d=[NSMutableDictionary new]; for(id k in o) d[[k description]]=Enc(o[k]); return d; }
 if([NSStringFromClass([o class]) containsString:@"CGColor"]){ CGColorRef c=(__bridge CGColorRef)o; size_t n=CGColorGetNumberOfComponents(c); const CGFloat *v=CGColorGetComponents(c); NSMutableArray *a=[NSMutableArray new]; for(size_t i=0;i<n;i++)[a addObject:@(v[i])]; return a; }
 return [o description];
}
static void Keys(id o, NSMutableSet *keys){
 if([o isKindOfClass:NSString.class] && [o hasPrefix:@"input"]) [keys addObject:o];
 else if([o isKindOfClass:NSArray.class]) for(id v in o) Keys(v, keys);
 else if([o isKindOfClass:NSDictionary.class]) for(id k in o){ Keys(k, keys); Keys(o[k], keys); }
}
static NSDictionary *Filter(id f){
 NSMutableSet *keys=[NSMutableSet new];
 for(Class c=[f class]; c; c=class_getSuperclass(c)){ unsigned n=0; objc_property_t *p=class_copyPropertyList(c,&n); for(unsigned i=0;i<n;i++){ NSString *k=@(property_getName(p[i])); if([k hasPrefix:@"input"])[keys addObject:k]; } free(p); }
 @try { NSData *d=[NSKeyedArchiver archivedDataWithRootObject:f requiringSecureCoding:NO error:nil]; id pl=[NSPropertyListSerialization propertyListWithData:d options:0 format:nil error:nil]; Keys(pl, keys); } @catch(NSException *e){}
 NSMutableDictionary *in=[NSMutableDictionary new];
 for(NSString *k in keys){ id v=Safe(f,k); if(v) in[k]=Enc(v); }
 return @{@"name":Enc(Safe(f,@"name")), @"type":[f description], @"inputs":in};
}
static void Walk(CALayer *l, CALayer *win, NSString *path, NSMutableArray *out){
 CALayer *p=l.presentationLayer ?: l;
 NSMutableArray *fs=[NSMutableArray new]; for(id f in p.filters)[fs addObject:Filter(f)];
 id effect=Safe(p,@"effect");
 if(fs.count || effect || l.compositingFilter){
  CGRect w=[p convertRect:p.bounds toLayer:win.presentationLayer ?: win];
  NSMutableDictionary *d=[@{@"path":path, @"class":NSStringFromClass(l.class), @"name":l.name?:@"", @"delegate":l.delegate?NSStringFromClass([l.delegate class]):@"",
    @"win":@[@(w.origin.x),@(w.origin.y),@(w.size.width),@(w.size.height)], @"filters":fs} mutableCopy];
  if(l.compositingFilter) d[@"compositingFilter"]=Filter(l.compositingFilter);
  if(effect){ NSMutableDictionary *e=[NSMutableDictionary new]; for(Class c=[effect class]; c && c!=NSObject.class; c=class_getSuperclass(c)){ unsigned n=0; objc_property_t *ps=class_copyPropertyList(c,&n); for(unsigned i=0;i<n;i++){ NSString *k=@(property_getName(ps[i])); if([@[@"description",@"debugDescription",@"superclass",@"hash"] containsObject:k]) continue; id v=Safe(effect,k); if(v) e[k]=Enc(v);} free(ps);} e[@"class"]=NSStringFromClass([effect class]); d[@"effect"]=e; }
  [out addObject:d];
 }
 int i=0; for(CALayer *s in l.sublayers) Walk(s, win, [path stringByAppendingFormat:@"/%d",i++], out);
 if(l.mask) Walk(l.mask, win, [path stringByAppendingString:@"/mask"], out);
}
void DumpFilters(NSString *name){
 NSMutableArray *a=[NSMutableArray new]; int i=0;
 for(UIScene *s in UIApplication.sharedApplication.connectedScenes) if([s isKindOfClass:UIWindowScene.class]) for(UIWindow *w in [(UIWindowScene*)s windows]) Walk(w.layer, w.layer, [NSString stringWithFormat:@"window%d",i++], a);
 NSDictionary *d=@{@"run":Run?:@"", @"state":name, @"os":NSProcessInfo.processInfo.operatingSystemVersionString, @"scale":@(UIScreen.mainScreen.scale), @"layers":a};
 NSURL *dir=[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"extracted"];
 [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
 NSData *json=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
 [json writeToURL:[dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json",Run,name]] atomically:YES];
 [[NSData data] writeToURL:[dir URLByAppendingPathComponent:[name stringByAppendingString:@".done"]] atomically:YES];
}
@interface UIWindow (PrismDispersion) - (void)prism_dispersion_sendEvent:(UIEvent *)e; @end
@implementation UIWindow (PrismDispersion)
- (void)prism_dispersion_sendEvent:(UIEvent *)e {
 [self prism_dispersion_sendEvent:e];
 for(UITouch *t in e.allTouches) if(t.phase==UITouchPhaseBegan){
  int n=++TouchCount;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DumpFilters([NSString stringWithFormat:@"touch%d",n]); });
 }
}
@end
void StartDispersionCapture(NSString *run){
 Run=run; TouchCount=0;
 static dispatch_once_t once; dispatch_once(&once, ^{ method_exchangeImplementations(class_getInstanceMethod(UIWindow.class,@selector(sendEvent:)), class_getInstanceMethod(UIWindow.class,@selector(prism_dispersion_sendEvent:))); });
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DumpFilters(@"rest"); });
}
