#import "BetterCCVPNContentViewController.h"
#import "VPNStore.h"
#import <objc/runtime.h>

static const CGFloat kRowHeight = 44.0;
static const CGFloat kExpandedPadding = 16.0;
static const CGFloat kTitleHeight = 28.0;
static const CGFloat kMaxExpandedHeight = 420.0;

static const void *kBCVRowEntryKey = &kBCVRowEntryKey;

@interface BetterCCVPNContentViewController ()
@property (nonatomic, strong) UIView *tileBackgroundView;
@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UIView *expandedContainer;
@property (nonatomic, strong) UILabel *expandedTitleLabel;
@property (nonatomic, strong) UIStackView *rowStack;
@property (nonatomic, assign) BOOL expanded;
@end

@implementation BetterCCVPNContentViewController

@synthesize preferredExpandedContentHeight = _preferredExpandedContentHeight;
@synthesize preferredExpandedContentWidth = _preferredExpandedContentWidth;
@synthesize providesOwnPlatter = _providesOwnPlatter;

- (void)loadView {
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = [UIColor clearColor];

    _providesOwnPlatter = NO;
    _preferredExpandedContentWidth = [UIScreen mainScreen].bounds.size.width * 0.856;
    _preferredExpandedContentHeight = kTitleHeight + kRowHeight + kExpandedPadding * 2;

    [self bcv_buildCollapsedContent];
    [self bcv_buildExpandedContent];
    self.expandedContainer.alpha = 0.0;
}

- (void)bcv_buildCollapsedContent {
    self.tileBackgroundView = [[UIView alloc] init];
    self.tileBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tileBackgroundView.layer.cornerRadius = 16;
    self.tileBackgroundView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview: self.tileBackgroundView];

    self.glyphView = [[UIImageView alloc] initWithImage:
        [[UIImage imageNamed: @"Icon" inBundle: [NSBundle bundleForClass: [self class]] compatibleWithTraitCollection: nil]
            imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate]];
    self.glyphView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glyphView.contentMode = UIViewContentModeScaleAspectFit;
    [self.tileBackgroundView addSubview: self.glyphView];

    [NSLayoutConstraint activateConstraints: @[
        [self.tileBackgroundView.leadingAnchor constraintEqualToAnchor: self.view.leadingAnchor],
        [self.tileBackgroundView.trailingAnchor constraintEqualToAnchor: self.view.trailingAnchor],
        [self.tileBackgroundView.topAnchor constraintEqualToAnchor: self.view.topAnchor],
        [self.tileBackgroundView.bottomAnchor constraintEqualToAnchor: self.view.bottomAnchor],

        [self.glyphView.centerXAnchor constraintEqualToAnchor: self.tileBackgroundView.centerXAnchor],
        [self.glyphView.centerYAnchor constraintEqualToAnchor: self.tileBackgroundView.centerYAnchor],
        [self.glyphView.widthAnchor constraintEqualToConstant: 42],
        [self.glyphView.heightAnchor constraintEqualToConstant: 42],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(bcv_tileTapped)];
    [self.tileBackgroundView addGestureRecognizer: tap];
    self.tileBackgroundView.userInteractionEnabled = YES;

    [self refreshCollapsedAppearance];
}

- (void)bcv_buildExpandedContent {
    self.expandedContainer = [[UIView alloc] init];
    self.expandedContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview: self.expandedContainer];

    [NSLayoutConstraint activateConstraints: @[
        [self.expandedContainer.leadingAnchor constraintEqualToAnchor: self.view.leadingAnchor constant: kExpandedPadding],
        [self.expandedContainer.trailingAnchor constraintEqualToAnchor: self.view.trailingAnchor constant: -kExpandedPadding],
        [self.expandedContainer.topAnchor constraintEqualToAnchor: self.view.topAnchor constant: kExpandedPadding],
        [self.expandedContainer.bottomAnchor constraintEqualToAnchor: self.view.bottomAnchor constant: -kExpandedPadding],
    ]];

    self.expandedTitleLabel = [[UILabel alloc] init];
    self.expandedTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.expandedTitleLabel.text = @"VPN";
    self.expandedTitleLabel.font = [UIFont boldSystemFontOfSize: 17];
    self.expandedTitleLabel.textColor = [UIColor labelColor];
    [self.expandedContainer addSubview: self.expandedTitleLabel];

    self.rowStack = [[UIStackView alloc] init];
    self.rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowStack.axis = UILayoutConstraintAxisVertical;
    self.rowStack.spacing = 4;
    [self.expandedContainer addSubview: self.rowStack];

    [NSLayoutConstraint activateConstraints: @[
        [self.expandedTitleLabel.topAnchor constraintEqualToAnchor: self.expandedContainer.topAnchor],
        [self.expandedTitleLabel.leadingAnchor constraintEqualToAnchor: self.expandedContainer.leadingAnchor],
        [self.expandedTitleLabel.trailingAnchor constraintEqualToAnchor: self.expandedContainer.trailingAnchor],
        [self.expandedTitleLabel.heightAnchor constraintEqualToConstant: kTitleHeight],

        [self.rowStack.topAnchor constraintEqualToAnchor: self.expandedTitleLabel.bottomAnchor constant: 4],
        [self.rowStack.leadingAnchor constraintEqualToAnchor: self.expandedContainer.leadingAnchor],
        [self.rowStack.trailingAnchor constraintEqualToAnchor: self.expandedContainer.trailingAnchor],
    ]];
}

- (void)refreshCollapsedAppearance {
    BOOL active = [[BCVPNStore sharedStore] isAnyVPNActive];
    self.tileBackgroundView.backgroundColor = active
        ? [UIColor systemGreenColor]
        : [[UIColor labelColor] colorWithAlphaComponent: 0.12];
    self.glyphView.tintColor = [UIColor whiteColor];
}

- (void)bcv_tileTapped {
    BOOL currentlyActive = [[BCVPNStore sharedStore] isAnyVPNActive];
    [[BCVPNStore sharedStore] setAnyVPNActive: !currentlyActive];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshCollapsedAppearance];
    });
}

- (void)bcv_rebuildExpandedRows {
    for (UIView *view in self.rowStack.arrangedSubviews) {
        [self.rowStack removeArrangedSubview: view];
        [view removeFromSuperview];
    }

    NSArray<BCVPNEntry *> *entries = [[BCVPNStore sharedStore] availableVPNs];

    if (entries.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = [BCVPNStore sharedStore].available
            ? @"Nenhuma VPN configurada"
            : @"Não foi possível ler as VPNs";
        emptyLabel.font = [UIFont systemFontOfSize: 15];
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        emptyLabel.numberOfLines = 0;
        emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyLabel.heightAnchor constraintGreaterThanOrEqualToConstant: kRowHeight].active = YES;
        [self.rowStack addArrangedSubview: emptyLabel];
    }

    for (BCVPNEntry *entry in entries) {
        UIButton *row = [UIButton buttonWithType: UIButtonTypeSystem];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [row.heightAnchor constraintEqualToConstant: kRowHeight].active = YES;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.titleLabel.font = [UIFont systemFontOfSize: 16];
        row.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent: 0.06];
        row.layer.cornerRadius = 10;
        row.layer.cornerCurve = kCACornerCurveContinuous;
        // contentEdgeInsets is deprecated but fine as long as .configuration
        // is never set on this button.
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        #pragma clang diagnostic pop

        NSString *title = entry.active ? [NSString stringWithFormat: @"✓ %@", entry.displayName] : entry.displayName;
        [row setTitle: title forState: UIControlStateNormal];
        [row setTitleColor: entry.active ? [UIColor systemGreenColor] : [UIColor labelColor] forState: UIControlStateNormal];

        objc_setAssociatedObject(row, kBCVRowEntryKey, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [row addTarget: self action: @selector(bcv_rowTapped:) forControlEvents: UIControlEventTouchUpInside];

        [self.rowStack addArrangedSubview: row];
    }
}

- (void)bcv_rowTapped:(UIButton *)sender {
    BCVPNEntry *entry = objc_getAssociatedObject(sender, kBCVRowEntryKey);
    if (!entry) {
        return;
    }

    [[BCVPNStore sharedStore] activateEntry: entry];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self bcv_rebuildExpandedRows];
        [self refreshCollapsedAppearance];
    });
}

#pragma mark - CCUIContentModuleContentViewController

- (BOOL)shouldBeginTransitionToExpandedContentModule {
    // Row count has to be fresh before returning, since CC reads
    // preferredExpandedContentHeight right after this to size the panel.
    NSArray<BCVPNEntry *> *entries = [[BCVPNStore sharedStore] availableVPNs];
    NSInteger rowCount = MAX((NSInteger) entries.count, 1);
    CGFloat height = kTitleHeight + 4 + (rowCount * (kRowHeight + 4)) + kExpandedPadding * 2;
    _preferredExpandedContentHeight = MIN(height, kMaxExpandedHeight);
    return YES;
}

- (void)willTransitionToExpandedContentMode:(BOOL)willTransition {
    self.expanded = willTransition;

    if (willTransition) {
        [self bcv_rebuildExpandedRows];
    }

    [UIView animateWithDuration: 0.2 animations: ^{
        self.tileBackgroundView.alpha = willTransition ? 0.0 : 1.0;
        self.expandedContainer.alpha = willTransition ? 1.0 : 0.0;
    }];
}

- (void)didTransitionToExpandedContentMode:(BOOL)didTransition {
    if (!didTransition) {
        [self refreshCollapsedAppearance];
    }
}

- (BOOL)shouldFinishTransitionToExpandedContentModule {
    return YES;
}

// canDismissPresentedContent / dismissPresentedContentAnimated:completion:
// deliberately not implemented - calling their untyped completion block
// crashed the device once. willTransitionToExpandedContentMode: is enough.

- (void)controlCenterWillPresent {
    [self refreshCollapsedAppearance];
}

- (void)controlCenterDidDismiss {
}

- (BOOL)_canShowWhileLocked {
    return YES;
}

@end
