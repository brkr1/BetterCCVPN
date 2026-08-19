#import <Foundation/Foundation.h>

// Minimal forward declaration of Preferences.framework's PSSpecifier, the
// row model Settings.app lists (including the VPN picker) are built from.
typedef NS_ENUM(NSInteger, BCVPNSpecifierCellType) {
    BCVPNSpecifierCellTypeGroupCell = 0,  // section header, not a tappable row
    // Confirmed on-device: every real VPN row uses cellType 1; "Status" and
    // "Add VPN Configuration..." use other values, so this is an allowlist.
    BCVPNSpecifierCellTypeLinkList = 1,
};

@interface PSSpecifier : NSObject
- (NSString *)name;
- (NSString *)identifier;
- (NSInteger)cellType;
@end
