#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
/// Writes Documents/extracted/<name>.json describing every layer of every
/// window: class, window frame, opacity, filters with all input values, mask
/// images and layer contents sampled down their centre column, gradient
/// layers' colors and locations. Research only; never shipped.
void ExtractScrollEdge(NSString *name, NSDictionary *configuration);
