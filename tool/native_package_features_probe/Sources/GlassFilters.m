#import "GlassFilters.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
// Research only (copied from tool/native_dispersion_probe/Sources/Extractor.m):
// records every layer's filters and all their input keys, for the --glass
// clear-outline fixture. Writes Documents/extracted/<name>.json.
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
 if(fs.count || effect || l.compositingFilter || l.borderWidth>0 || l.shadowOpacity>0){
  CGRect w=[p convertRect:p.bounds toLayer:win.presentationLayer ?: win];
  NSMutableDictionary *d=[@{@"path":path, @"class":NSStringFromClass(l.class), @"name":l.name?:@"", @"delegate":l.delegate?NSStringFromClass([l.delegate class]):@"",
    @"win":@[@(w.origin.x),@(w.origin.y),@(w.size.width),@(w.size.height)], @"filters":fs,
    @"cornerRadius":@(p.cornerRadius), @"opacity":@(p.opacity), @"borderWidth":@(p.borderWidth), @"borderColor":Enc((__bridge id)p.borderColor),
    @"backgroundColor":Enc((__bridge id)p.backgroundColor), @"shadowOpacity":@(p.shadowOpacity), @"shadowRadius":@(p.shadowRadius),
    @"shadowOffset":@[@(p.shadowOffset.width),@(p.shadowOffset.height)], @"shadowColor":Enc((__bridge id)p.shadowColor)} mutableCopy];
  if(l.compositingFilter) d[@"compositingFilter"]=[l.compositingFilter isKindOfClass:NSString.class]?l.compositingFilter:Filter(l.compositingFilter);
  if(effect){ NSMutableDictionary *e=[NSMutableDictionary new]; for(Class c=[effect class]; c && c!=NSObject.class; c=class_getSuperclass(c)){ unsigned n=0; objc_property_t *ps=class_copyPropertyList(c,&n); for(unsigned i=0;i<n;i++){ NSString *k=@(property_getName(ps[i])); if([@[@"description",@"debugDescription",@"superclass",@"hash"] containsObject:k]) continue; id v=Safe(effect,k); if(v) e[k]=Enc(v);} free(ps);} e[@"class"]=NSStringFromClass([effect class]); d[@"effect"]=e; }
  [out addObject:d];
 }
 int i=0; for(CALayer *s in l.sublayers) Walk(s, win, [path stringByAppendingFormat:@"/%d",i++], out);
 if(l.mask) Walk(l.mask, win, [path stringByAppendingString:@"/mask"], out);
}
void DumpGlassFilters(NSString *name){
 NSMutableArray *a=[NSMutableArray new]; int i=0;
 for(UIScene *s in UIApplication.sharedApplication.connectedScenes) if([s isKindOfClass:UIWindowScene.class]) for(UIWindow *w in [(UIWindowScene*)s windows]) Walk(w.layer, w.layer, [NSString stringWithFormat:@"window%d",i++], a);
 NSDictionary *d=@{@"state":name, @"os":NSProcessInfo.processInfo.operatingSystemVersionString, @"scale":@(UIScreen.mainScreen.scale), @"layers":a};
 NSURL *dir=[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"measurements"];
 [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
 NSData *json=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
 [json writeToURL:[dir URLByAppendingPathComponent:[NSString stringWithFormat:@"filters-%@.json",name]] atomically:YES];
}
