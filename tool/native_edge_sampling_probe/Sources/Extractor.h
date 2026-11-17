#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <QuartzCore/QuartzCore.h>

/// Writes every layer under [root] (class, window frame, opacity, filters,
/// background filters, masks, backdrop and gradient properties) to
/// `<dir>/<name>.json`. Mask images are saved next to it as PNGs.
void PrismDumpLayers(CALayer *root, NSString *dir, NSString *name);
