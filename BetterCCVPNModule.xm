#import "BetterCCVPNModule.h"
#import "ControlCenterUI-Structs.h"

@implementation BetterCCVPNModule

- (instancetype)init {
    if ((self = [super init])) {
        _contentViewController = [[BetterCCVPNContentViewController alloc] init];
    }
    return self;
}

- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation {
    return (CCUILayoutSize) { 1, 1 };
}

@end
