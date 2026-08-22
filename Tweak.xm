#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Private compatibility declarations

@interface PSListController : UIViewController
@end

@interface UISearchBar (SGPrivate)
- (void)searchFieldBecomeFirstResponder;
@end

#pragma mark - SearchGlass button

@interface SGGlassButton : UIControl
@property(nonatomic,strong) UIVisualEffectView *blurView;
@property(nonatomic,strong) UILabel *titleLabelSG;
@property(nonatomic,strong) CAGradientLayer *specularLayer;
@property(nonatomic,strong) CAGradientLayer *edgeLayer;
@property(nonatomic,strong) CAShapeLayer *edgeMask;
@property(nonatomic,strong) CALayer *highlightLayer;
@property(nonatomic,assign) BOOL sgDark;
- (void)sgUpdateAppearance;
@end

@implementation SGGlassButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.cornerRadius = 16.0;
    self.layer.borderWidth = 0.55;

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    self.blurView.userInteractionEnabled = NO;
    self.blurView.alpha = 0.96;
    self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
    self.blurView.layer.cornerRadius = 16.0;
    self.blurView.clipsToBounds = YES;
    [self addSubview:self.blurView];

    self.titleLabelSG = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabelSG.text = @"Search";
    self.titleLabelSG.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    self.titleLabelSG.textAlignment = NSTextAlignmentCenter;
    self.titleLabelSG.userInteractionEnabled = NO;
    [self addSubview:self.titleLabelSG];

    // Soft internal highlight. It follows the exact same rounded mask as the button,
    // preventing the specular corner-radius mismatch seen in earlier builds.
    self.specularLayer = [CAGradientLayer layer];
    self.specularLayer.startPoint = CGPointMake(0.0, 0.0);
    self.specularLayer.endPoint = CGPointMake(1.0, 1.0);
    self.specularLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.035].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.specularLayer.locations = @[@0.0, @0.22, @0.58];
    [self.layer addSublayer:self.specularLayer];

    self.highlightLayer = [CALayer layer];
    self.highlightLayer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    self.highlightLayer.opacity = 1.0;
    [self.layer addSublayer:self.highlightLayer];

    // Edge reflection / bezel.
    self.edgeLayer = [CAGradientLayer layer];
    self.edgeLayer.startPoint = CGPointMake(0.0, 0.0);
    self.edgeLayer.endPoint = CGPointMake(1.0, 1.0);
    self.edgeLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor
    ];
    self.edgeLayer.locations = @[@0.0, @0.25, @0.60, @1.0];
    [self.layer addSublayer:self.edgeLayer];

    self.edgeMask = [CAShapeLayer layer];
    self.edgeMask.fillColor = UIColor.clearColor.CGColor;
    self.edgeMask.strokeColor = UIColor.whiteColor.CGColor;
    self.edgeMask.lineWidth = 0.8;
    self.edgeLayer.mask = self.edgeMask;

    [self sgUpdateAppearance];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat r = MIN(16.0, CGRectGetHeight(self.bounds) * 0.5);

    self.blurView.frame = self.bounds;
    self.blurView.layer.cornerRadius = r;

    self.titleLabelSG.frame = CGRectInset(self.bounds, 8.0, 0.0);

    self.specularLayer.frame = self.bounds;
    self.highlightLayer.frame = CGRectMake(1.0, 1.0,
                                           MAX(0.0, CGRectGetWidth(self.bounds) - 2.0),
                                           MAX(0.0, CGRectGetHeight(self.bounds) * 0.42));

    self.edgeLayer.frame = self.bounds;

    CGRect b = CGRectInset(self.bounds, 0.45, 0.45);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:MAX(0.0, r - 0.45)];
    self.edgeMask.frame = self.bounds;
    self.edgeMask.path = p.CGPath;
}

- (void)sgUpdateAppearance {
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = self.traitCollection.userInterfaceStyle;
        self.sgDark = (style == UIUserInterfaceStyleDark);
    } else {
        self.sgDark = YES;
    }

    // Requested: white text in dark mode, black in light mode.
    self.titleLabelSG.textColor = self.sgDark ? UIColor.whiteColor : UIColor.blackColor;

    // Very subtle tint only to keep the glass readable; no opaque color wash.
    UIColor *tint = self.sgDark
        ? [UIColor colorWithWhite:1.0 alpha:0.045]
        : [UIColor colorWithWhite:0.0 alpha:0.035];

    self.backgroundColor = tint;
    self.layer.borderColor = (self.sgDark
        ? [UIColor colorWithWhite:1.0 alpha:0.24].CGColor
        : [UIColor colorWithWhite:0.0 alpha:0.16].CGColor);

    self.blurView.alpha = 0.98;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self sgUpdateAppearance];
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    [UIView animateWithDuration:0.12 animations:^{
        self.alpha = highlighted ? 0.72 : 1.0;
        self.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985)
                                     : CGAffineTransformIdentity;
    }];
}

@end

#pragma mark - Settings integration

static void SGAddBlockTarget(UIControl *control, void (^block)(id sender));

static const NSInteger SGButtonTag = 0x53474254; // "SGBT"

static BOOL SGIsMainSettingsController(UIViewController *controller) {
    if (!controller) return NO;

    // Main Settings is the root PSListController. This avoids relying on the
    // private -isMainSettingsController selector that caused the previous build error.
    UINavigationController *nav = controller.navigationController;
    if (nav) {
        UIViewController *root = nav.viewControllers.firstObject;
        if (root != controller) return NO;
    }

    // Main Settings has no pushed Settings controller above it.
    if (controller.presentedViewController) return NO;

    NSString *title = controller.title ?: @"";
    if ([title isEqualToString:@"Settings"]) return YES;

    // Fallback used by some iOS builds where the title is not populated yet.
    if ([controller isKindOfClass:NSClassFromString(@"PSListController")]) {
        UINavigationController *n = controller.navigationController;
        if (n && n.viewControllers.count == 1) return YES;
    }

    return NO;
}

static UISearchBar *SGFindSearchBar(UIView *view) {
    if (!view) return nil;

    if ([view isKindOfClass:[UISearchBar class]]) {
        return (UISearchBar *)view;
    }

    for (UIView *subview in view.subviews) {
        UISearchBar *found = SGFindSearchBar(subview);
        if (found) return found;
    }

    return nil;
}

static UIViewController *SGFindSearchController(UIViewController *controller) {
    if (!controller) return nil;

    if ([controller isKindOfClass:[UISearchController class]]) {
        return controller;
    }

    for (UIViewController *child in controller.childViewControllers) {
        UIViewController *found = SGFindSearchController(child);
        if (found) return found;
    }

    return nil;
}

static void SGActivateSettingsSearch(UIViewController *controller) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // First try the currently loaded search bar.
        UISearchBar *bar = SGFindSearchBar(controller.view);
        if (bar) {
            [bar becomeFirstResponder];
            return;
        }

        // Some Settings builds keep UISearchController outside the visible tree.
        UISearchController *searchController = (UISearchController *)SGFindSearchController(controller);
        if (searchController) {
            searchController.active = YES;
            [searchController.searchBar becomeFirstResponder];
            return;
        }

        // Last fallback: locate any UISearchBar in the Settings window.
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            UISearchBar *globalBar = SGFindSearchBar(window);
            if (globalBar) {
                [globalBar becomeFirstResponder];
                return;
            }
        }
    });
}

static void SGRemoveButtonFromController(UIViewController *controller) {
    for (UIView *v in [controller.view.subviews copy]) {
        if (v.tag == SGButtonTag) {
            [v removeFromSuperview];
        }
    }
}

static void SGInstallButtonOnController(UIViewController *controller) {
    if (!SGIsMainSettingsController(controller)) {
        SGRemoveButtonFromController(controller);
        return;
    }

    if (!controller.isViewLoaded || !controller.view.window) return;

    UIView *existing = [controller.view viewWithTag:SGButtonTag];
    if (existing) {
        [existing.superview bringSubviewToFront:existing];
        return;
    }

    SGGlassButton *button = [[SGGlassButton alloc] initWithFrame:CGRectZero];
    button.tag = SGButtonTag;
    button.accessibilityLabel = @"Search";
    button.accessibilityTraits = UIAccessibilityTraitButton;

    __weak UIViewController *weakController = controller;
    SGAddBlockTarget(button, ^(id sender) {
        UIViewController *strongController = weakController;
        if (strongController) {
            SGActivateSettingsSearch(strongController);
        }
    });

    [controller.view addSubview:button];

    // Compact size, slightly larger than the previous build but still unobtrusive.
    CGFloat width = 112.0;
    CGFloat height = 38.0;

    // Keep it above the bottom search area while respecting the safe area.
    CGFloat bottom = MAX(18.0, controller.view.safeAreaInsets.bottom + 14.0);
    button.frame = CGRectMake((CGRectGetWidth(controller.view.bounds) - width) * 0.5,
                              CGRectGetHeight(controller.view.bounds) - bottom - height,
                              width,
                              height);

    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleTopMargin;

    [controller.view bringSubviewToFront:button];
}

#pragma mark - Lightweight block support

// Avoids requiring any private API or external library for UIControl callbacks.
@interface SGActionTarget : NSObject
@property(nonatomic,copy) void (^block)(id sender);
@end

@implementation SGActionTarget
- (void)invoke:(id)sender {
    if (self.block) self.block(sender);
}
@end

static const void *SGActionTargetKey = &SGActionTargetKey;

static void SGAddBlockTarget(UIControl *control, void (^block)(id sender)) {
    SGActionTarget *target = [SGActionTarget new];
    target.block = block;

    objc_setAssociatedObject(control, SGActionTargetKey, target,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [control addTarget:target action:@selector(invoke:) forControlEvents:UIControlEventTouchUpInside];
}

%hook PSListController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (SGIsMainSettingsController(self)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SGInstallButtonOnController(self);
        });
    } else {
        SGRemoveButtonFromController(self);
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (SGIsMainSettingsController(self)) {
        SGGlassButton *button = (SGGlassButton *)[self.view viewWithTag:SGButtonTag];
        if (button) {
            CGFloat width = 112.0;
            CGFloat height = 38.0;
            CGFloat bottom = MAX(18.0, self.view.safeAreaInsets.bottom + 14.0);

            button.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - width) * 0.5,
                                      CGRectGetHeight(self.view.bounds) - bottom - height,
                                      width,
                                      height);
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;

    if (!SGIsMainSettingsController(self)) {
        SGRemoveButtonFromController(self);
    }
}

%end

%ctor {
    @autoreleasepool {
        // No Settings search button is created outside PSListController,
        // keeping the tweak scoped to the Settings application.
    }
}
