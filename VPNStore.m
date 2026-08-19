#import "VPNStore.h"
#import "PSSpecifier.h"
#import <dlfcn.h>
#import <objc/message.h>

// Built against VPNController, the private class behind Settings > VPN on
// iOS 16 (successor to the older, no-longer-present VPNNEController).
// _controller is typed `id` since no header declares its real interface.
@implementation BCVPNEntry
@end

@implementation BCVPNStore {
    id _controller;
    NSString *_lastActivatedDisplayName;
}

+ (instancetype)sharedStore {
    static BCVPNStore *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[BCVPNStore alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self bcv_setUp];
    }
    return self;
}

- (void)bcv_setUp {
    NSString *bundlePath = @"/System/Library/PreferenceBundles/VPNPreferences.bundle/VPNPreferences";
    void *handle = dlopen([bundlePath fileSystemRepresentation], RTLD_NOW);
    if (!handle) {
        return;
    }

    Class controllerClass = NSClassFromString(@"VPNController");
    if (!controllerClass) {
        return;
    }

    @try {
        _controller = [[controllerClass alloc] init];
    } @catch (NSException *exception) {
        _controller = nil;
    }
}

- (BOOL)available {
    return _controller != nil;
}

- (NSArray<BCVPNEntry *> *)availableVPNs {
    if (!_controller || ![_controller respondsToSelector: @selector(specifiers)]) {
        return @[];
    }

    NSArray<PSSpecifier *> *specifiers = nil;
    @try {
        // No @interface declares -specifiers on this dynamically-typed
        // controller, so a plain message send won't compile.
        specifiers = ((id (*)(id, SEL)) objc_msgSend)(_controller, @selector(specifiers));
    } @catch (NSException *exception) {
        return @[];
    }

    NSSet<NSString *> *activeNames = [self bcv_activeVPNNames];

    NSMutableArray<BCVPNEntry *> *entries = [NSMutableArray array];
    for (PSSpecifier *specifier in specifiers) {
        NSString *name = nil;
        NSInteger cellType = -1;
        @try {
            name = [specifier respondsToSelector: @selector(name)] ? [specifier name] : nil;
            cellType = [specifier respondsToSelector: @selector(cellType)] ? [specifier cellType] : -1;
        } @catch (NSException *exception) {
            continue;
        }

        if (cellType != BCVPNSpecifierCellTypeLinkList) {
            continue; // group headers, "Status", "Add VPN Configuration..." - not a VPN choice
        }
        if (name.length == 0) {
            continue;
        }

        BCVPNEntry *entry = [[BCVPNEntry alloc] init];
        entry.displayName = name;
        entry.identifier = [specifier respondsToSelector: @selector(identifier)] ? [specifier identifier] : name;
        entry.specifier = specifier;
        entry.active = [activeNames containsObject: name];
        [entries addObject: entry];
    }

    // Manually-configured profiles resolve to "Unknown" instead of a real
    // name (see bcv_activeVPNNames) - fall back to whichever entry we
    // ourselves last activated when nothing else matched.
    BOOL matchedAny = NO;
    for (BCVPNEntry *entry in entries) {
        if (entry.active) {
            matchedAny = YES;
            break;
        }
    }
    if (!matchedAny && activeNames.count > 0 && _lastActivatedDisplayName) {
        for (BCVPNEntry *entry in entries) {
            if ([entry.displayName isEqualToString: _lastActivatedDisplayName]) {
                entry.active = YES;
                break;
            }
        }
    }

    return entries;
}

// Resolves activeVPNIDWithGrade: (a UUID) back to a display name via
// appNameForServiceID:withGrade:, across all four VPN grades.
- (NSSet<NSString *> *)bcv_activeVPNNames {
    NSMutableSet<NSString *> *names = [NSMutableSet set];

    Class storeClass = NSClassFromString(@"VPNConnectionStore");
    if (![storeClass respondsToSelector: @selector(sharedInstance)]) {
        return names;
    }
    id store = ((id (*)(id, SEL)) objc_msgSend)(storeClass, @selector(sharedInstance));
    if (![store respondsToSelector: @selector(activeVPNIDWithGrade:)] ||
        ![store respondsToSelector: @selector(appNameForServiceID:withGrade:)]) {
        return names;
    }

    for (NSUInteger grade = 0; grade < 4; grade++) {
        @try {
            // activeVPNIDWithGrade: returns an NSUUID, not an NSString.
            id activeID = ((id (*)(id, SEL, NSUInteger)) objc_msgSend)(store, @selector(activeVPNIDWithGrade:), grade);
            if (!activeID) {
                continue;
            }
            id name = ((id (*)(id, SEL, id, NSUInteger)) objc_msgSend)(store, @selector(appNameForServiceID:withGrade:), activeID, grade);
            if ([name isKindOfClass: [NSString class]]) {
                [names addObject: name];
            }
        } @catch (NSException *exception) {
            continue;
        }
    }
    return names;
}

// activeVPNIDWithGrade: tracks the *selected* VPN, not whether it's
// connected - it stays put after disconnecting. The tile's green state
// needs live connection status instead, which these coarse per-grade
// getters (same answer for every specifier in a grade) do reflect.
- (BOOL)isAnyVPNActive {
    if (!_controller) {
        return NO;
    }

    PSSpecifier *anySpecifier = [self availableVPNs].firstObject.specifier;
    if (!anySpecifier) {
        return NO;
    }

    SEL candidates[] = {
        @selector(getPersonalConnectionStateForSpecifier:),
        @selector(getEnterpriseConnectionStateForSpecifier:),
        @selector(getAOVPNEnabledForSpecifier:),
    };
    for (unsigned i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        SEL sel = candidates[i];
        if (![_controller respondsToSelector: sel]) {
            continue;
        }
        @try {
            id value = ((id (*)(id, SEL, id)) objc_msgSend)(_controller, sel, anySpecifier);
            if ([value respondsToSelector: @selector(boolValue)] && [value boolValue]) {
                return YES;
            }
        } @catch (NSException *exception) {
            continue;
        }
    }
    return NO;
}

- (void)setAnyVPNActive:(BOOL)active {
    if (!_controller) {
        return;
    }

    NSArray<BCVPNEntry *> *entries = [self availableVPNs];

    if (active) {
        // Reactivate whichever VPN was last selected, or the first
        // configured one, same as tapping the collapsed tile in CCVPN.
        BCVPNEntry *target = entries.firstObject;
        for (BCVPNEntry *entry in entries) {
            if (entry.active) {
                target = entry;
                break;
            }
        }
        if (target) {
            [self activateEntry: target];
        }
        return;
    }

    BCVPNEntry *activeEntry = nil;
    for (BCVPNEntry *entry in entries) {
        if (entry.active) {
            activeEntry = entry;
            break;
        }
    }
    if (!activeEntry) {
        return;
    }

    // Try both grade setters unconditionally - one can "succeed" silently
    // without doing anything on the wrong grade, so stopping early risks
    // never reaching the one that actually disconnects.
    SEL candidates[] = {
        @selector(setPersonalVPNActive:specifier:),
        @selector(setEnterpriseVPNActive:specifier:),
    };
    for (unsigned i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        SEL sel = candidates[i];
        if (![_controller respondsToSelector: sel]) {
            continue;
        }
        @try {
            ((void (*)(id, SEL, BOOL, id)) objc_msgSend)(_controller, sel, NO, activeEntry.specifier);
        } @catch (NSException *exception) {
            continue;
        }
    }
}

- (void)activateEntry:(BCVPNEntry *)entry {
    if (!_controller || !entry.specifier) {
        return;
    }

    _lastActivatedDisplayName = entry.displayName;

    if ([_controller respondsToSelector: @selector(changeActiveVPN:)]) {
        @try {
            ((void (*)(id, SEL, id)) objc_msgSend)(_controller, @selector(changeActiveVPN:), entry.specifier);
        } @catch (NSException *exception) {
            // ignored
        }
    }

    // changeActiveVPN: alone only marks the selection - these grade
    // setters are what actually starts the connection.
    SEL candidates[] = {
        @selector(setPersonalVPNActive:specifier:),
        @selector(setEnterpriseVPNActive:specifier:),
    };
    for (unsigned i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        SEL sel = candidates[i];
        if (![_controller respondsToSelector: sel]) {
            continue;
        }
        @try {
            ((void (*)(id, SEL, BOOL, id)) objc_msgSend)(_controller, sel, YES, entry.specifier);
        } @catch (NSException *exception) {
            continue;
        }
    }
}

@end
