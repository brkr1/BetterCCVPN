#import <Foundation/Foundation.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import "BetterCCVPNContentViewController.h"

@interface BetterCCVPNModule : NSObject <CCUIContentModule>
@property (nonatomic, readonly) BetterCCVPNContentViewController *contentViewController;
// Declared here so Clang auto-synthesizes a nil-returning getter; we have
// no separate background view controller.
@property (nonatomic, readonly) UIViewController *backgroundViewController;
@end
