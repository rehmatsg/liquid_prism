#import "Extractor.h"
#import <objc/runtime.h>

// KVC on private Core Animation objects can throw; Swift cannot catch that.
static id Safe(id o, NSString *key) { @try { return [o valueForKey:key]; } @catch (NSException *e) { return nil; } }

#if TARGET_OS_IPHONE
static NSString *RectString(CGRect r) { return NSStringFromCGRect(r); }
static NSString *PointString(CGPoint p) { return NSStringFromCGPoint(p); }
static NSData *PNG(CGImageRef image) { return UIImagePNGRepresentation([UIImage imageWithCGImage:image]); }
#else
static NSString *RectString(CGRect r) { return NSStringFromRect(NSRectFromCGRect(r)); }
static NSString *PointString(CGPoint p) { return NSStringFromPoint(NSPointFromCGPoint(p)); }
static NSData *PNG(CGImageRef image) {
  return [[[NSBitmapImageRep alloc] initWithCGImage:image] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}
#endif

static NSString *OutDir;
static NSString *Prefix;
static int ImageCount;

static id Encode(id o);

static id ImageInfo(CGImageRef image) {
  if (!image) return [NSNull null];
  NSString *file = [NSString stringWithFormat:@"%@-image-%d.png", Prefix, ImageCount++];
  [PNG(image) writeToFile:[OutDir stringByAppendingPathComponent:file] atomically:YES];
  CGColorSpaceRef cs = CGImageGetColorSpace(image);
  return @{@"file": file, @"width": @(CGImageGetWidth(image)), @"height": @(CGImageGetHeight(image)),
           @"colorSpace": cs ? ((__bridge_transfer NSString *)CGColorSpaceCopyName(cs) ?: @"unnamed") : @"none"};
}

static id Encode(id o) {
  if (!o) return [NSNull null];
  if ([o isKindOfClass:NSNumber.class]) { double x = [o doubleValue]; return isfinite(x) ? o : @"non-finite"; }
  if ([o isKindOfClass:NSString.class]) return o;
  if ([o isKindOfClass:NSValue.class]) return [o description];
  if ([o isKindOfClass:NSArray.class]) { NSMutableArray *a = [NSMutableArray new]; for (id v in o) [a addObject:Encode(v)]; return a; }
  if ([o isKindOfClass:NSDictionary.class]) { NSMutableDictionary *d = [NSMutableDictionary new]; for (id k in o) d[[k description]] = Encode(o[k]); return d; }
  CFTypeID type = CFGetTypeID((__bridge CFTypeRef)o);
  if (type == CGColorGetTypeID()) {
    CGColorRef c = (__bridge CGColorRef)o; size_t n = CGColorGetNumberOfComponents(c); const CGFloat *v = CGColorGetComponents(c);
    NSMutableArray *a = [NSMutableArray new]; for (size_t i = 0; i < n; i++) [a addObject:@(v[i])];
    CGColorSpaceRef s = CGColorGetColorSpace(c);
    return @{@"components": a, @"colorSpace": s ? ((__bridge_transfer NSString *)CGColorSpaceCopyName(s) ?: @"unnamed") : @"none"};
  }
  if (type == CGImageGetTypeID()) return ImageInfo((__bridge CGImageRef)o);
  return [NSString stringWithFormat:@"<%@> %@", NSStringFromClass([o class]), [o description]];
}

/// Declared properties whose values KVC can box safely: objects, scalars and
/// plain geometry structs. Pointer-typed getters can crash when boxed.
static NSArray *DeclaredProperties(Class cls, Class stop) {
  NSMutableArray *keys = [NSMutableArray new];
  for (Class c = cls; c && c != stop; c = class_getSuperclass(c)) {
    unsigned n = 0; objc_property_t *p = class_copyPropertyList(c, &n);
    for (unsigned i = 0; i < n; i++) {
      const char *attrs = property_getAttributes(p[i]);
      char t = attrs[1];
      BOOL ok = strchr("@cislqCISLQfdB", t) != NULL
        || strncmp(attrs + 1, "{CGRect", 7) == 0 || strncmp(attrs + 1, "{CGPoint", 8) == 0
        || strncmp(attrs + 1, "{CGSize", 7) == 0;
      if (t == '@' && attrs[2] == '?') ok = NO; // blocks
      if (ok) [keys addObject:@(property_getName(p[i]))];
    }
    free(p);
  }
  return keys;
}

static NSDictionary *Filter(id f) {
  NSMutableSet *keys = [NSMutableSet new];
  for (NSString *k in DeclaredProperties([f class], NSObject.class)) if ([k hasPrefix:@"input"]) [keys addObject:k];
  // CAFilter exposes most inputs by key only: try the known ones, then every
  // input name its archive mentions.
  for (NSString *k in @[@"inputRadius", @"inputMaskImage", @"inputNormalizeEdges", @"inputNormalizeEdgesTransparency",
                        @"inputHardEdges", @"inputQuality", @"inputIntermediateBitDepth", @"inputDither", @"inputFade",
                        @"inputAmount", @"inputColor", @"inputBounds", @"inputScale", @"inputColorMatrix", @"inputOpacity",
                        @"inputEdges", @"inputEdgeMode", @"inputTileMode", @"inputClamp"]) [keys addObject:k];
  NSString *archive = @"";
  @try {
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:f requiringSecureCoding:NO error:nil];
    id plist = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:nil error:nil] : nil;
    archive = [plist description] ?: @"";
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"input[A-Za-z0-9]+" options:0 error:nil];
    for (NSTextCheckingResult *m in [re matchesInString:archive options:0 range:NSMakeRange(0, archive.length)])
      [keys addObject:[archive substringWithRange:m.range]];
  } @catch (NSException *e) {}
  NSMutableDictionary *inputs = [NSMutableDictionary new];
  for (NSString *k in [[keys allObjects] sortedArrayUsingSelector:@selector(compare:)]) { id v = Safe(f, k); if (v) inputs[k] = Encode(v); }
  return @{@"class": NSStringFromClass([f class]), @"name": Encode(Safe(f, @"name")), @"type": Encode(Safe(f, @"type")),
           @"enabled": Encode(Safe(f, @"enabled")), @"description": [f description], @"inputs": inputs, @"archive": archive};
}

static NSArray *Filters(NSArray *fs) {
  NSMutableArray *a = [NSMutableArray new];
  for (id f in fs) [a addObject:Filter(f)];
  return a;
}

static NSDictionary *Layer(CALayer *l, CALayer *root, NSString *path) {
  CGRect win = [l convertRect:l.bounds toLayer:root];
  NSMutableDictionary *d = [@{
    @"path": path, @"class": NSStringFromClass(l.class), @"name": l.name ?: @"",
    @"frame": RectString(l.frame), @"inRoot": RectString(win),
    @"opacity": @(l.opacity), @"hidden": @(l.hidden), @"masksToBounds": @(l.masksToBounds),
    @"contentsScale": @(l.contentsScale), @"cornerRadius": @(l.cornerRadius),
    @"geometryFlipped": @(l.geometryFlipped), @"rasterizationScale": @(l.rasterizationScale),
    @"backgroundColor": Encode((__bridge id)l.backgroundColor),
    @"delegateClass": l.delegate ? NSStringFromClass([(NSObject *)l.delegate class]) : @"",
  } mutableCopy];
  if (l.filters.count) d[@"filters"] = Filters(l.filters);
  if (l.backgroundFilters.count) d[@"backgroundFilters"] = Filters(l.backgroundFilters);
  if (l.compositingFilter) d[@"compositingFilter"] = [l.compositingFilter isKindOfClass:NSString.class] ? l.compositingFilter : Filter(l.compositingFilter);
  if (l.contents) d[@"contents"] = Encode(l.contents);
  if ([l isKindOfClass:CAGradientLayer.class]) {
    CAGradientLayer *g = (id)l;
    d[@"gradient"] = @{@"type": g.type ?: @"", @"colors": Encode(g.colors), @"locations": Encode(g.locations),
                       @"start": PointString(g.startPoint), @"end": PointString(g.endPoint)};
  }
  NSString *cls = NSStringFromClass(l.class);
  if (![cls isEqualToString:@"CALayer"] && ![l isKindOfClass:CAGradientLayer.class] && ![cls hasPrefix:@"NS"] && ![cls hasPrefix:@"UI"] && ![cls containsString:@"."]) {
    NSMutableDictionary *props = [NSMutableDictionary new];
    for (NSString *k in DeclaredProperties(l.class, CALayer.class)) {
      if ([@[@"description", @"debugDescription", @"superclass", @"hash"] containsObject:k]) continue;
      id v = Safe(l, k);
      if (v) props[k] = Encode(v);
    }
    d[@"properties"] = props;
  }
  if (l.mask) d[@"mask"] = Layer(l.mask, root, [path stringByAppendingString:@"/mask"]);
  NSMutableArray *children = [NSMutableArray new];
  NSUInteger i = 0;
  for (CALayer *s in l.sublayers) [children addObject:Layer(s, root, [NSString stringWithFormat:@"%@/%lu", path, (unsigned long)i++])];
  if (children.count) d[@"sublayers"] = children;
  return d;
}

void PrismDumpLayers(CALayer *root, NSString *dir, NSString *name) {
  OutDir = dir; Prefix = name; ImageCount = 0;
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  // Encode again so non-finite scalars anywhere in the tree become strings.
  id tree = Encode(Layer(root, root, @"root"));
  NSError *error = nil;
  NSData *json = [NSJSONSerialization dataWithJSONObject:tree options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
  if (!json) { NSLog(@"dump failed: %@", error); return; }
  [json writeToFile:[dir stringByAppendingPathComponent:[name stringByAppendingString:@".json"]] atomically:YES];
}
