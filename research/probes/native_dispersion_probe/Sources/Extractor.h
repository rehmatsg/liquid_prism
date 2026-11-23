#import <UIKit/UIKit.h>
// Research only. Never ship: dumps private CAFilter inputs of every layer.
void StartDispersionCapture(NSString *run);
void DumpFilters(NSString *name);
// Seconds from touch-down to the dump and marker (default 1.0); set before
// StartDispersionCapture. Longer delays let drag-then-hold gestures settle.
void SetDispersionDumpDelay(double seconds);
