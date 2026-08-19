#import <Foundation/Foundation.h>

@class PSSpecifier;

// One selectable row from the real VPN picker (Personal / Enterprise / App).
// Wraps the underlying PSSpecifier so we can reuse Settings.app's own logic.
@interface BCVPNEntry : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, strong) PSSpecifier *specifier;
@end

@interface BCVPNStore : NSObject

+ (instancetype)sharedStore;

// NO if VPNPreferences.bundle or VPNController couldn't be loaded.
@property (nonatomic, readonly) BOOL available;

- (BOOL)isAnyVPNActive;

// Personal + Enterprise + App VPN entries, group headers filtered out.
- (NSArray<BCVPNEntry *> *)availableVPNs;

// Collapsed-tile tap: flips today's single active VPN on/off, matching the
// original CCVPN toggle behavior.
- (void)setAnyVPNActive:(BOOL)active;

// Long-press row tap: makes this specific VPN the active one.
- (void)activateEntry:(BCVPNEntry *)entry;

@end
