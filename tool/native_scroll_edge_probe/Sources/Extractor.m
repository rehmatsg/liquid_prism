#import "Extractor.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static id Safe(id o, NSString *key) { @try { return [o valueForKey:key]; } @catch (NSException *e) { return nil; } }
static NSURL *OutDir(NSString *sub) {
  NSURL *dir = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  dir = [dir URLByAppendingPathComponent:sub];
  [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
  return dir;
}
static int ImageCount;
/// Saves a CGImage as PNG and samples its centre column and centre row as
/// RGBA bytes (unpremultiplied where possible) so a 1-D profile can be read.
static NSDictionary *Image(CGImageRef image, NSString *name) {
  if (!image) return nil;
  size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
  NSString *file = [NSString stringWithFormat:@"%@-%d.png", name, ImageCount++];
  NSData *png = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
  [png writeToURL:[OutDir(@"images") URLByAppendingPathComponent:file] atomically:YES];
  NSMutableDictionary *d = [@{@"file": file, @"width": @(w), @"height": @(h),
    @"bitsPerComponent": @(CGImageGetBitsPerComponent(image)), @"bitsPerPixel": @(CGImageGetBitsPerPixel(image)),
    @"alphaInfo": @(CGImageGetAlphaInfo(image))} mutableCopy];
  CGColorSpaceRef cs = CGImageGetColorSpace(image);
  d[@"colorSpace"] = cs ? (__bridge_transfer NSString *)CGColorSpaceCopyName(cs) ?: @"unnamed" : @"none";
  if (w == 0 || h == 0) return d;
  unsigned char *pixels = calloc(w * h * 4, 1);
  CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
  CGContextRef cx = CGBitmapContextCreate(pixels, w, h, 8, w * 4, rgb, kCGImageAlphaPremultipliedLast);
  CGContextDrawImage(cx, CGRectMake(0, 0, w, h), image);
  NSMutableArray *column = [NSMutableArray new], *row = [NSMutableArray new];
  size_t cx0 = w / 2, cy0 = h / 2;
  for (size_t y = 0; y < h; y++) { unsigned char *p = pixels + (y * w + cx0) * 4; [column addObject:@[@(p[0]), @(p[1]), @(p[2]), @(p[3])]]; }
  for (size_t x = 0; x < w; x++) { unsigned char *p = pixels + (cy0 * w + x) * 4; [row addObject:@[@(p[0]), @(p[1]), @(p[2]), @(p[3])]]; }
  // Bitmap rows run top to bottom in CG's flipped draw; record the order used.
  d[@"column"] = column; d[@"row"] = row; d[@"order"] = @"index 0 is the bottom of the image as CGContextDrawImage lays it out";
  CGContextRelease(cx); CGColorSpaceRelease(rgb); free(pixels);
  return d;
}
static id Encode(id o, NSString *name) {
  if (!o) return [NSNull null];
  if ([o isKindOfClass:NSNumber.class]) { double x = [o doubleValue]; return isfinite(x) ? o : @"non-finite"; }
  if ([o isKindOfClass:NSString.class]) return o;
  if ([o isKindOfClass:NSValue.class]) return @{@"objCType": @([o objCType]), @"value": [o description]};
  if ([o isKindOfClass:NSArray.class]) { NSMutableArray *a = [NSMutableArray new]; for (id v in o) [a addObject:Encode(v, name)]; return a; }
  if ([o isKindOfClass:NSDictionary.class]) { NSMutableDictionary *d = [NSMutableDictionary new]; for (id k in o) d[[k description]] = Encode(o[k], name); return d; }
  if ([o isKindOfClass:UIColor.class]) { CGFloat r, g, b, a; if ([o getRed:&r green:&g blue:&b alpha:&a]) return @{@"rgba": @[@(r), @(g), @(b), @(a)]}; }
  CFTypeID type = CFGetTypeID((__bridge CFTypeRef)o);
  if (type == CGColorGetTypeID()) {
    CGColorRef c = (__bridge CGColorRef)o; size_t n = CGColorGetNumberOfComponents(c); const CGFloat *v = CGColorGetComponents(c);
    NSMutableArray *a = [NSMutableArray new]; for (size_t i = 0; i < n; i++) [a addObject:@(v[i])];
    CGColorSpaceRef s = CGColorGetColorSpace(c);
    return @{@"components": a, @"colorSpace": s ? (__bridge_transfer NSString *)CGColorSpaceCopyName(s) ?: @"unnamed" : @"none"};
  }
  if (type == CGImageGetTypeID()) return Image((__bridge CGImageRef)o, name) ?: [NSNull null];
  return [NSString stringWithFormat:@"<%@> %@", NSStringFromClass([o class]), [o description]];
}
static NSDictionary *Filter(id f, NSString *name) {
  NSMutableSet *keys = [NSMutableSet new];
  for (Class c = [f class]; c; c = class_getSuperclass(c)) {
    unsigned n = 0; objc_property_t *p = class_copyPropertyList(c, &n);
    for (unsigned i = 0; i < n; i++) { NSString *k = @(property_getName(p[i])); if ([k hasPrefix:@"input"]) [keys addObject:k]; }
    free(p);
  }
  // CAFilter exposes its inputs by key only; try the ones variable blurs and
  // gradients are known to use plus whatever the archive lists.
  for (NSString *k in @[@"inputRadius", @"inputMaskImage", @"inputNormalizeEdges", @"inputAmount", @"inputColor", @"inputBounds", @"inputScale", @"inputQuality", @"inputHardEdges", @"inputDither", @"inputSaturation", @"inputBrightness", @"inputColorMatrix", @"inputOpacity"]) [keys addObject:k];
  @try {
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:f requiringSecureCoding:NO error:nil];
    id plist = [NSPropertyListSerialization propertyListWithData:d options:0 format:nil error:nil];
    NSString *s = [plist description];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"input[A-Za-z]+" options:0 error:nil];
    for (NSTextCheckingResult *m in [re matchesInString:s options:0 range:NSMakeRange(0, s.length)]) [keys addObject:[s substringWithRange:m.range]];
  } @catch (NSException *e) {}
  NSMutableDictionary *d = [@{@"class": NSStringFromClass([f class]), @"name": Encode(Safe(f, @"name"), name), @"description": [f description], @"enabled": Encode(Safe(f, @"enabled"), name)} mutableCopy];
  NSMutableDictionary *inputs = [NSMutableDictionary new];
  for (NSString *k in [[keys allObjects] sortedArrayUsingSelector:@selector(compare:)]) { id v = Safe(f, k); if (v) inputs[k] = Encode(v, name); }
  d[@"inputs"] = inputs;
  return d;
}
static void Layer(CALayer *l, NSString *path, NSString *name, NSMutableArray *out) {
  CALayer *root = l; while (root.superlayer) root = root.superlayer;
  CGRect win = [l convertRect:l.bounds toLayer:root];
  NSMutableDictionary *d = [@{@"path": path, @"class": NSStringFromClass(l.class), @"name": l.name ?: @"",
    @"frame": NSStringFromCGRect(l.frame), @"bounds": NSStringFromCGRect(l.bounds), @"window": NSStringFromCGRect(win),
    @"opacity": @(l.opacity), @"hidden": @(l.hidden), @"masksToBounds": @(l.masksToBounds),
    @"presentationOpacity": @(l.presentationLayer ? l.presentationLayer.opacity : -1),
    @"presentationHidden": @(l.presentationLayer ? l.presentationLayer.hidden : NO),
    @"backgroundColor": Encode((__bridge id)l.backgroundColor, name), @"contentsScale": @(l.contentsScale),
    @"delegateClass": l.delegate ? NSStringFromClass([l.delegate class]) : @"",
    @"compositingFilter": l.compositingFilter ? Filter(l.compositingFilter, name) : [NSNull null],
    @"cornerRadius": @(l.cornerRadius), @"allowsGroupOpacity": @(l.allowsGroupOpacity)} mutableCopy];
  if ([l.delegate isKindOfClass:UIView.class]) {
    UIView *v = (id)l.delegate;
    d[@"viewFrameInWindow"] = NSStringFromCGRect([v convertRect:v.bounds toView:v.window]);
    d[@"accessibilityIdentifier"] = v.accessibilityIdentifier ?: @"";
    d[@"viewAlpha"] = @(v.alpha);
    // Scroll edge effect views carry their style and configuration here.
    // Only UIKit classes: KVC on a SwiftUI view's property trips a Swift
    // assertion that no @try can catch.
    NSMutableDictionary *props = [NSMutableDictionary new];
    NSString *vcls = NSStringFromClass(v.class);
    BOOL uikit = ([vcls hasPrefix:@"UI"] || [vcls hasPrefix:@"_UI"]) && ![vcls containsString:@"."];
    BOOL edgy = [vcls containsString:@"Edge"] || [vcls containsString:@"Effect"] || [vcls containsString:@"Blur"] || [vcls containsString:@"Backdrop"] || [vcls containsString:@"NavigationBar"];
    for (Class c = uikit && edgy ? [v class] : Nil; c && c != UIView.class; c = class_getSuperclass(c)) {
      unsigned n = 0; objc_property_t *ps = class_copyPropertyList(c, &n);
      for (unsigned i = 0; i < n; i++) {
        NSString *k = @(property_getName(ps[i]));
        if ([@[@"description", @"debugDescription", @"superclass", @"hash", @"nextResponder", @"window", @"superview", @"subviews", @"layer", @"gestureRecognizers", @"interactions", @"constraints", @"delegate", @"dataSource"] containsObject:k]) continue;
        id val = Safe(v, k);
        if (val && ![val isKindOfClass:UIView.class] && ![val isKindOfClass:CALayer.class]) props[k] = Encode(val, name);
      }
      free(ps);
    }
    if (props.count) d[@"viewProperties"] = props;
  }
  if ([l isKindOfClass:CAGradientLayer.class]) {
    CAGradientLayer *g = (id)l;
    d[@"gradient"] = @{@"type": g.type, @"colors": Encode(g.colors, name), @"locations": Encode(g.locations, name),
      @"startPoint": NSStringFromCGPoint(g.startPoint), @"endPoint": NSStringFromCGPoint(g.endPoint)};
  }
  NSMutableArray *filters = [NSMutableArray new];
  for (id f in l.filters) [filters addObject:Filter(f, name)];
  if (filters.count) d[@"filters"] = filters;
  if (l.contents) d[@"contents"] = Encode(l.contents, name);
  // Private scroll edge effect state lives on the layers' delegates and on
  // CABackdropLayer; list every non-standard property name for the record.
  NSString *cls = NSStringFromClass(l.class);
  if ([cls hasPrefix:@"CA"] && ![cls containsString:@"."] && ![cls isEqualToString:@"CALayer"] && ![cls isEqualToString:@"CAGradientLayer"]) {
    NSMutableDictionary *props = [NSMutableDictionary new];
    for (Class c = [l class]; c && c != CALayer.class; c = class_getSuperclass(c)) {
      unsigned n = 0; objc_property_t *ps = class_copyPropertyList(c, &n);
      for (unsigned i = 0; i < n; i++) {
        NSString *k = @(property_getName(ps[i]));
        if ([@[@"description", @"debugDescription", @"superclass", @"hash", @"superlayer", @"sublayers", @"delegate", @"mask"] containsObject:k]) continue;
        id val = Safe(l, k); if (val && ![val isKindOfClass:CALayer.class]) props[k] = Encode(val, name);
      }
      free(ps);
    }
    if (props.count) d[@"layerProperties"] = props;
  }
  [out addObject:d];
  int i = 0;
  for (CALayer *s in l.sublayers) Layer(s, [path stringByAppendingFormat:@"/%d", i++], name, out);
  if (l.mask) Layer(l.mask, [path stringByAppendingString:@"/mask"], name, out);
}
void ExtractScrollEdge(NSString *name, NSDictionary *configuration) {
  NSMutableArray *layers = [NSMutableArray new]; int i = 0;
  for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
    if ([s isKindOfClass:UIWindowScene.class])
      for (UIWindow *w in [(UIWindowScene *)s windows]) Layer(w.layer, [NSString stringWithFormat:@"window%d", i++], name, layers);
  NSDictionary *d = @{@"configuration": configuration, @"os": NSProcessInfo.processInfo.operatingSystemVersionString,
    @"screen": @{@"bounds": NSStringFromCGRect(UIScreen.mainScreen.bounds), @"scale": @(UIScreen.mainScreen.scale)},
    @"layers": layers};
  NSData *json = nil;
  @try { json = [NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil]; } @catch (NSException *e) { json = [[NSString stringWithFormat:@"{\"error\":\"%@\"}", e.reason] dataUsingEncoding:NSUTF8StringEncoding]; }
  [json writeToURL:[OutDir(@"extracted") URLByAppendingPathComponent:[name stringByAppendingString:@".json"]] atomically:YES];
  [[NSData data] writeToURL:[OutDir(@"extracted") URLByAppendingPathComponent:[name stringByAppendingString:@".done"]] atomically:YES];
}
