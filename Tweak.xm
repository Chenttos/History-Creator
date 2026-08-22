/*
 * SearchGlass
 * Liquid Glass renderer adapted from the public Liquid (Gl)ass project:
 * https://github.com/winaviation-tweaks/liquidass
 *
 * Uses the same Liquid (Gl)ass render-server approach:
 * CABackdropLayer + CAFilter + live refraction + specular reflection.
 *
 * GPL-3.0 applies to code derived from Liquid (Gl)ass.
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Liquid Glass constants

static NSString * const kSGFilterType = @"dylv.liquidglass.searchpill";
static NSString * const kSGGroupNamespace = @"dylv.liquidglass";
static NSString * const kSGGroupName = @"SearchGlass";

static Class SGBackdropClass(void) {
    return NSClassFromString(@"CABackdropLayer");
}

static Class SGFilterClass(void) {
    return NSClassFromString(@"CAFilter");
}

static id SGFilterWithType(NSString *type) {
    Class cls = SGFilterClass();
    if (!cls || !type.length) return nil;

    SEL selector = NSSelectorFromString(@"filterWithType:");
    if (![cls respondsToSelector:selector]) return nil;

    return ((id (*)(Class, SEL, NSString *))objc_msgSend)(cls, selector, type);
}

static id SGFilterWithName(NSString *name) {
    Class cls = SGFilterClass();
    if (!cls || !name.length) return nil;

    SEL selector = NSSelectorFromString(@"filterWithName:");
    if (![cls respondsToSelector:selector]) return nil;

    return ((id (*)(Class, SEL, NSString *))objc_msgSend)(cls, selector, name);
}

static void SGSetValue(id object, id value, NSString *key) {
    if (!object || !key.length) return;

    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {
    }
}

static NSString *SGEffectiveFilterType(UIView *view) {
    NSString *type = kSGFilterType;

    if (@available(iOS 13.0, *)) {
        if (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            type = [type stringByAppendingString:@".dark"];
    }

    return type;
}

#pragma mark - Live Liquid Glass

@interface SGLiveGlassView : UIView
@property(nonatomic, assign) CGFloat cornerRadius;
@property(nonatomic, assign) BOOL liquidFilterAvailable;
- (void)applyLiquidGlass;
@end

@implementation SGLiveGlassView {
    CAGradientLayer *_specular;
    CAGradientLayer *_specularBoost;
    CAShapeLayer *_specularMask;
    CAShapeLayer *_specularBoostMask;
    CALayer *_nativeBlurLayer;
}

+ (Class)layerClass {
    Class backdrop = SGBackdropClass();
    return backdrop ?: [CALayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;

    self.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    self.cornerRadius =
        MIN(CGRectGetWidth(frame), CGRectGetHeight(frame)) * 0.5;

    [self setupSpecular];
    [self updateSpecularAppearance];
    [self applyLiquidGlass];

    return self;
}

- (void)setupSpecular {
    /*
     * Visible edge specular highlight.
     *
     * The previous implementation used a transparent fill mask with a
     * 1pt stroke and an overlay blend mode. On a CABackdropLayer this can
     * become effectively invisible. We instead use a normal source-over
     * gradient and a thicker edge-band mask. This is still a highlight,
     * not a permanent border: its alpha varies along the edge.
     */
    _specular = [CAGradientLayer layer];
    _specularBoost = [CAGradientLayer layer];

    _specularMask = [CAShapeLayer layer];
    _specularBoostMask = [CAShapeLayer layer];

    _specular.mask = _specularMask;
    _specularBoost.mask = _specularBoostMask;

    _specular.zPosition = 100.0;
    _specularBoost.zPosition = 101.0;

    _specularBoost.compositingFilter = nil;

    [self.layer addSublayer:_specular];
    [self.layer addSublayer:_specularBoost];
}

- (void)updateSpecularAppearance {
    BOOL dark = NO;

    if (@available(iOS 13.0, *))
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

    CGFloat highlightWhite = dark ? 1.0 : 0.0;

    UIColor *strong =
        [UIColor colorWithWhite:highlightWhite alpha:0.95];

    UIColor *medium =
        [UIColor colorWithWhite:highlightWhite alpha:0.62];

    UIColor *soft =
        [UIColor colorWithWhite:highlightWhite alpha:0.18];

    _specular.colors = @[
        (id)strong.CGColor,
        (id)soft.CGColor,
        (id)UIColor.clearColor.CGColor,
        (id)medium.CGColor,
        (id)strong.CGColor
    ];

    _specular.locations = @[
        @0.0, @0.12, @0.48, @0.82, @1.0
    ];

    _specularBoost.colors = @[
        (id)[UIColor colorWithWhite:highlightWhite alpha:0.55].CGColor,
        (id)UIColor.clearColor.CGColor,
        (id)[UIColor colorWithWhite:highlightWhite alpha:0.48].CGColor
    ];

    _specularBoost.locations = @[
        @0.0, @0.50, @1.0
    ];
}

- (void)layoutSpecular {
    CGRect bounds = self.bounds;
    CGFloat radius = MAX(0.0, self.cornerRadius);

    if (CGRectIsEmpty(bounds))
        return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _specular.frame = bounds;
    _specularBoost.frame = bounds;

    /*
     * A 2.6pt edge band makes the highlight clearly visible while
     * remaining a lighting effect rather than a uniform outline.
     */
    CGFloat inset = 1.30;
    CGFloat edgeWidth = 2.60;

    UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(bounds, inset, inset)
            cornerRadius:MAX(0.0, radius - inset)];

    _specularMask.frame = bounds;
    _specularMask.path = path.CGPath;
    _specularMask.fillColor = UIColor.clearColor.CGColor;
    _specularMask.strokeColor = UIColor.whiteColor.CGColor;
    _specularMask.lineWidth = edgeWidth;

    _specularBoostMask.frame = bounds;
    _specularBoostMask.path = path.CGPath;
    _specularBoostMask.fillColor = UIColor.clearColor.CGColor;
    _specularBoostMask.strokeColor = UIColor.whiteColor.CGColor;
    _specularBoostMask.lineWidth = edgeWidth * 0.72;

    /*
     * Diagonal Fresnel-like highlight, matching the LiquidAss visual
     * direction. The color itself is supplied by updateSpecularAppearance,
     * so it is white in dark mode and black in light mode.
     */
    CGFloat angle = -M_PI_4;
    CGFloat dx = cos(angle) * 0.5;
    CGFloat dy = sin(angle) * 0.5;

    _specular.startPoint = CGPointMake(0.5 + dx, 0.5 + dy);
    _specular.endPoint   = CGPointMake(0.5 - dx, 0.5 - dy);

    _specularBoost.startPoint = _specular.startPoint;
    _specularBoost.endPoint   = _specular.endPoint;

    [CATransaction commit];
}

- (void)applyNativeBlurFallback {
    Class backdropClass = SGBackdropClass();

    if (!backdropClass)
        return;

    id blur = SGFilterWithName(@"gaussianBlur");

    if (!blur)
        return;

    SGSetValue(blur, @2.0, @"inputRadius");
    SGSetValue(blur, @YES, @"inputNormalizeEdges");

    if (!_nativeBlurLayer) {
        _nativeBlurLayer = [backdropClass layer];

        SGSetValue(_nativeBlurLayer,
                   @NO,
                   @"layerUsesCoreImageFilters");

        SGSetValue(_nativeBlurLayer,
                   @YES,
                   @"windowServerAware");

        SGSetValue(_nativeBlurLayer,
                   kSGGroupName,
                   @"groupName");

        SGSetValue(_nativeBlurLayer,
                   kSGGroupNamespace,
                   @"groupNamespace");

        SGSetValue(_nativeBlurLayer,
                   @YES,
                   @"ignoresScreenClip");

        SGSetValue(_nativeBlurLayer,
                   @1.0,
                   @"scale");

        [self.layer insertSublayer:_nativeBlurLayer atIndex:0];
    }

    _nativeBlurLayer.frame = self.bounds;
    _nativeBlurLayer.cornerRadius = self.cornerRadius;
    _nativeBlurLayer.masksToBounds = YES;
    _nativeBlurLayer.filters = @[blur];
}

- (void)configureRefractionFilter:(id)glassFilter {
    if (!glassFilter)
        return;

    /*
     * Stronger Liquid Glass refraction.
     * These are intentionally applied only to the Liquid Glass
     * filter, leaving the existing blur/specular design unchanged.
     */
    SGSetValue(glassFilter, @6.0, @"inputRefraction");
    SGSetValue(glassFilter, @4.0, @"inputDisplacement");
    SGSetValue(glassFilter, @4.0, @"inputDisplacementRadius");
    SGSetValue(glassFilter, @3.0, @"inputDistortion");
    SGSetValue(glassFilter, @2.0, @"inputDistortionScale");
    SGSetValue(glassFilter, @2.15, @"inputRefractiveIndex");
    SGSetValue(glassFilter, @1.20, @"inputScale");
    SGSetValue(glassFilter, @1.45, @"inputBlur");
    SGSetValue(glassFilter, @1.15, @"inputSpecular");

    /*
     * Liquid (Gl)ass SearchPill builds use these shorter keys.
     * Setting both forms is harmless because SGSetValue safely
     * ignores keys that are not exposed by the current filter.
     */
    SGSetValue(glassFilter, @6.0, @"refraction");
    SGSetValue(glassFilter, @2.15, @"refractiveIndex");
    SGSetValue(glassFilter, @1.45, @"blur");
    SGSetValue(glassFilter, @1.15, @"specular");
}

- (void)applyLiquidGlass {
    Class backdropClass = SGBackdropClass();
    CALayer *layer = self.layer;

    if (!backdropClass ||
        ![layer isKindOfClass:backdropClass]) {

        [self layoutSpecular];
        return;
    }

    @try {
        /*
         * These are the same private render-server properties
         * configured by LGLiveBackdropView in Liquid (Gl)ass.
         */

        SGSetValue(layer,
                   @NO,
                   @"layerUsesCoreImageFilters");

        SGSetValue(layer,
                   @YES,
                   @"windowServerAware");

        SGSetValue(layer,
                   kSGGroupName,
                   @"groupName");

        SGSetValue(layer,
                   kSGGroupNamespace,
                   @"groupNamespace");

        SGSetValue(layer,
                   @YES,
                   @"ignoresScreenClip");

        /*
         * SearchPill in LGHostRegistry:
         *
         * refraction       = 1.6
         * refractiveIndex  = 1.70
         * blur             = 1.0
         * specular         = 1.0
         *
         * The actual Liquid (Gl)ass filter consumes these parameters
         * through its registered filter type.
         */

        SGSetValue(layer, @1.0, @"scale");

        NSString *filterType =
            SGEffectiveFilterType(self);

        id glassFilter =
            SGFilterWithType(filterType);

        /*
         * Some builds register only the base filter name.
         * Try it before falling back to gaussian blur.
         */

        if (!glassFilter &&
            ![filterType isEqualToString:kSGFilterType]) {

            glassFilter =
                SGFilterWithType(kSGFilterType);
        }

        if (glassFilter) {
            [self configureRefractionFilter:glassFilter];

            layer.filters = @[glassFilter];
            self.liquidFilterAvailable = YES;

            if (_nativeBlurLayer) {
                [_nativeBlurLayer removeFromSuperlayer];
                _nativeBlurLayer = nil;
            }
        } else {
            self.liquidFilterAvailable = NO;
            [self applyNativeBlurFallback];
        }

    } @catch (__unused NSException *exception) {
        self.liquidFilterAvailable = NO;
        [self applyNativeBlurFallback];
    }

    [self layoutSpecular];
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;

    self.layer.cornerRadius = cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;

    [self layoutSpecular];
    [self applyLiquidGlass];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (previousTraitCollection.userInterfaceStyle !=
            self.traitCollection.userInterfaceStyle) {

            [self updateSpecularAppearance];
            [self applyLiquidGlass];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.layer.cornerRadius = self.cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;

    [self layoutSpecular];

    if (!self.liquidFilterAvailable)
        [self applyNativeBlurFallback];
}

@end

#pragma mark - Search button

static UISearchBar *SGFindRealSearchBarInView(UIView *view);

@interface SGSearchButton : UIControl
@property(nonatomic, strong) SGLiveGlassView *glassView;
@property(nonatomic, strong) UIImageView *searchIcon;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIImageView *micIcon;

@end

@implementation SGSearchButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self)
        return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.exclusiveTouch = YES;
    self.userInteractionEnabled = YES;

    self.layer.cornerCurve = kCACornerCurveContinuous;

    [self buildUI];

    [self addTarget:self
             action:@selector(searchPressed:)
   forControlEvents:UIControlEventTouchUpInside];

    [self addTarget:self
             action:@selector(sgTouchDown:)
   forControlEvents:UIControlEventTouchDown |
                    UIControlEventTouchDragEnter];

    [self addTarget:self
             action:@selector(sgTouchUp:)
   forControlEvents:UIControlEventTouchUpInside |
                    UIControlEventTouchCancel |
                    UIControlEventTouchDragExit];

    return self;
}

- (void)buildUI {
    UIBlurEffect *buttonBlurEffect =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];

    UIVisualEffectView *buttonBlur =
        [[UIVisualEffectView alloc] initWithEffect:buttonBlurEffect];

    buttonBlur.frame = self.bounds;
    buttonBlur.userInteractionEnabled = NO;
    buttonBlur.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
    buttonBlur.layer.cornerRadius = 22.0;
    buttonBlur.layer.cornerCurve = kCACornerCurveContinuous;
    buttonBlur.clipsToBounds = YES;
    buttonBlur.alpha = 0.72;

    [self addSubview:buttonBlur];

    self.glassView =
        [[SGLiveGlassView alloc] initWithFrame:self.bounds];

    /*
     * IMPORTANT:
     * The glass is visual only. It cannot steal touches from
     * the SGSearchButton underneath it.
     */
    self.glassView.userInteractionEnabled = NO;
    self.glassView.cornerRadius = 22.0;

    [self addSubview:self.glassView];

    UIImageSymbolConfiguration *searchConfig =
        [UIImageSymbolConfiguration
            configurationWithPointSize:15.0
            weight:UIImageSymbolWeightRegular];

    UIImage *searchImage =
        [UIImage systemImageNamed:@"magnifyingglass"
                withConfiguration:searchConfig];

    self.searchIcon =
        [[UIImageView alloc] initWithImage:searchImage];

    self.searchIcon.tintColor =
        [UIColor colorWithWhite:0.0 alpha:0.92];

    self.searchIcon.contentMode =
        UIViewContentModeScaleAspectFit;

    self.searchIcon.userInteractionEnabled = NO;

    [self addSubview:self.searchIcon];

    self.titleLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    self.titleLabel.text = @"Search";

    self.titleLabel.font =
        [UIFont systemFontOfSize:15.0
                          weight:UIFontWeightRegular];

    self.titleLabel.textColor = UIColor.labelColor;

    self.titleLabel.textAlignment =
        NSTextAlignmentLeft;

    self.titleLabel.backgroundColor =
        UIColor.clearColor;

    self.titleLabel.userInteractionEnabled = NO;

    [self addSubview:self.titleLabel];

    UIImageSymbolConfiguration *micConfig =
        [UIImageSymbolConfiguration
            configurationWithPointSize:15.0
            weight:UIImageSymbolWeightRegular];

    UIImage *micImage =
        [UIImage systemImageNamed:@"mic"
                withConfiguration:micConfig];

    self.micIcon =
        [[UIImageView alloc] initWithImage:micImage];

    self.micIcon.tintColor =
        [UIColor colorWithWhite:0.0 alpha:0.92];

    self.micIcon.contentMode =
        UIViewContentModeScaleAspectFit;

    self.micIcon.userInteractionEnabled = NO;

    [self addSubview:self.micIcon];

    [self updateTextAppearance];
}

- (void)updateTextAppearance {
    BOOL dark = NO;

    if (@available(iOS 13.0, *)) {
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *foreground =
        dark
        ? [UIColor colorWithWhite:1.0 alpha:1.0]
        : [UIColor colorWithWhite:0.0 alpha:1.0];

    // Text + both SF Symbols follow the interface appearance.
    self.titleLabel.textColor = foreground;
    self.searchIcon.tintColor = foreground;
    self.micIcon.tintColor = foreground;

    // Thin 0.8pt outline: white in Dark Mode, black in Light Mode.


}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (!previousTraitCollection ||
            previousTraitCollection.userInterfaceStyle !=
            self.traitCollection.userInterfaceStyle) {
            [self updateTextAppearance];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    self.glassView.frame = self.bounds;
    self.glassView.cornerRadius =
        MIN(22.0, height * 0.5);

    self.layer.cornerRadius = self.glassView.cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;


    self.searchIcon.frame =
        CGRectMake(11.0,
                   floor((height - 18.0) * 0.5),
                   18.0,
                   18.0);

    self.micIcon.frame =
        CGRectMake(width - 29.0,
                   floor((height - 18.0) * 0.5),
                   18.0,
                   18.0);

    self.titleLabel.frame =
        CGRectMake(37.0,
                   0.0,
                   MAX(0.0, width - 72.0),
                   height);
}

- (void)sgTouchDown:(id)sender {
    [UIView animateWithDuration:0.08
                     animations:^{
        self.transform =
            CGAffineTransformMakeScale(0.985, 0.985);

        self.alpha = 0.88;
    }];
}

- (void)sgTouchUp:(id)sender {
    [UIView animateWithDuration:0.12
                     animations:^{
        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];
}

#pragma mark - Search action

- (void)searchPressed:(id)sender {
    /*
     * The fake pill never performs its own search. It only reveals and
     * focuses Apple's real Settings search field.
     */
    UIViewController *vc = [self nearestViewController];
    if (!vc)
        return;

    UINavigationController *nav = vc.navigationController;
    UIViewController *root =
        nav ? nav.viewControllers.firstObject : vc;

    if (!root)
        return;

    if (nav && nav.topViewController != root) {
        [nav popToViewController:root animated:YES];
    }

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            UISearchBar *searchBar =
                SGFindRealSearchBarInView(root.view);

            if (!searchBar) {
                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW,
                                  (int64_t)(0.30 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(),
                    ^{
                        UISearchBar *retry =
                            SGFindRealSearchBarInView(root.view);

                        if (retry) {
                            UIScrollView *scroll =
                                [self findScrollViewContainingView:retry];

                            if (scroll) {
                                CGRect rect =
                                    [retry convertRect:retry.bounds
                                                toView:scroll];
                                [scroll scrollRectToVisible:rect animated:YES];
                            }

                            [retry setUserInteractionEnabled:YES];
                            [retry becomeFirstResponder];
                        }
                    });
                return;
            }

            UIScrollView *scroll =
                [self findScrollViewContainingView:searchBar];

            if (scroll) {
                CGRect rect =
                    [searchBar convertRect:searchBar.bounds
                                    toView:scroll];

                [scroll scrollRectToVisible:rect animated:YES];
            }

            [searchBar setUserInteractionEnabled:YES];
            [searchBar becomeFirstResponder];
        });
}

#pragma mark - View controller finder

- (UIViewController *)nearestViewController {
    UIResponder *responder = self;

    while (responder) {
        responder = [responder nextResponder];

        if ([responder
             isKindOfClass:[UIViewController class]]) {

            return (UIViewController *)responder;
        }
    }

    return nil;
}

#pragma mark - SearchBar finder

- (UISearchBar *)findSearchBarInView:(UIView *)view {
    if (!view)
        return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview in view.subviews) {
        UISearchBar *result =
            [self findSearchBarInView:subview];

        if (result)
            return result;
    }

    return nil;
}

#pragma mark - ScrollView finder

- (UIScrollView *)findScrollViewContainingView:(UIView *)target {
    UIView *view = target.superview;

    while (view) {
        if ([view isKindOfClass:[UIScrollView class]])
            return (UIScrollView *)view;

        view = view.superview;
    }

    return nil;
}

@end

#pragma mark - Settings installation

static const NSInteger kSGSearchGlassTag = 0x53474153;

static BOOL SGIsMainSettingsController(
    UIViewController *controller
) {
    if (!controller)
        return NO;

    Class psClass =
        NSClassFromString(@"PSListController");

    if (!psClass ||
        ![controller isKindOfClass:psClass]) {
        return NO;
    }

    /*
     * Only the root Settings page is allowed.
     * A pushed PSListController has more than one controller
     * in the navigation stack, so the SearchGlass disappears
     * automatically on every subpage.
     */
    UINavigationController *navigationController =
        controller.navigationController;

    if (!navigationController)
        return NO;

    if (navigationController.viewControllers.count != 1)
        return NO;

    if (navigationController.viewControllers.firstObject != controller)
        return NO;

    NSString *className =
        NSStringFromClass(controller.class);

    if ([className containsString:@"Search"])
        return NO;

    return YES;
}

#pragma mark - Real Settings Search visibility

static UISearchBar *SGFindRealSearchBarInView(UIView *view) {
    if (!view) return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview in view.subviews) {
        UISearchBar *found = SGFindRealSearchBarInView(subview);
        if (found) return found;
    }

    return nil;
}

static BOOL SGSearchBarIsActuallyVisible(UISearchBar *searchBar) {
    if (!searchBar || searchBar.hidden || searchBar.alpha < 0.01)
        return NO;

    UIWindow *window = searchBar.window;
    if (!window || window.hidden || window.alpha < 0.01)
        return NO;

    /*
     * A search bar can remain in the hierarchy while collapsed/off-screen.
     * Convert to window coordinates and require a meaningful visible area.
     */
    CGRect rect = [searchBar convertRect:searchBar.bounds toView:window];

    if (CGRectIsNull(rect) || CGRectIsEmpty(rect))
        return NO;

    CGRect visible = CGRectIntersection(rect, window.bounds);

    if (CGRectIsNull(visible) || CGRectIsEmpty(visible))
        return NO;

    CGFloat visibleArea =
        CGRectGetWidth(visible) * CGRectGetHeight(visible);

    CGFloat totalArea =
        MAX(1.0, CGRectGetWidth(rect) * CGRectGetHeight(rect));

    /*
     * If even a small sliver remains at the edge, keep the fake pill
     * hidden until the real search bar has actually left the screen.
     */
    if (visibleArea / totalArea < 0.08)
        return NO;

    return CGRectGetHeight(visible) >= 8.0 &&
           CGRectGetWidth(visible) >= 40.0;
}

static void SGSetSearchGlassVisibility(UIViewController *controller) {
    if (!controller || !controller.view)
        return;

    SGSearchButton *button =
        (SGSearchButton *)[controller.view viewWithTag:kSGSearchGlassTag];

    if (!button)
        return;

    /*
     * The button lives on the root Settings view. It must be hidden
     * whenever another Settings controller is on top.
     */
    UINavigationController *nav = controller.navigationController;

    if (!SGIsMainSettingsController(controller) ||
        (nav && nav.topViewController != controller)) {
        button.hidden = YES;
        return;
    }

    UISearchBar *realSearch =
        SGFindRealSearchBarInView(controller.view);

    /*
     * Real visible search = fake hidden.
     * Real search scrolled away = fake visible.
     */
    button.hidden = SGSearchBarIsActuallyVisible(realSearch);

    if (!button.hidden)
        [controller.view bringSubviewToFront:button];
}

static void SGInstallSearchGlass(
    UIViewController *controller
) {
    if (!controller.view ||
        !SGIsMainSettingsController(controller)) {

        return;
    }

    UIView *view = controller.view;

    SGSearchButton *existing =
        (SGSearchButton *)[view viewWithTag:kSGSearchGlassTag];

    if (existing) {
        existing.frame = CGRectMake(
            (CGRectGetWidth(view.bounds) - MIN(326.0, MAX(270.0, CGRectGetWidth(view.bounds) - 32.0))) * 0.5,
            CGRectGetHeight(view.bounds) - view.safeAreaInsets.bottom - 44.0 - 18.0,
            MIN(326.0, MAX(270.0, CGRectGetWidth(view.bounds) - 32.0)),
            44.0
        );
        [view bringSubviewToFront:existing];
        SGSetSearchGlassVisibility(controller);
        return;
    }

    /*
     * Smaller than the old 316 x 44 version.
     */
    CGFloat width =
        MIN(326.0,
            MAX(270.0,
                CGRectGetWidth(view.bounds) - 32.0));

    CGFloat height = 44.0;

    CGFloat x =
        (CGRectGetWidth(view.bounds) - width) * 0.5;

    CGFloat y =
        CGRectGetHeight(view.bounds) -
        view.safeAreaInsets.bottom -
        height -
        18.0;

    if (y < 20.0)
        y = 20.0;

    SGSearchButton *button =
        [[SGSearchButton alloc]
            initWithFrame:CGRectMake(x,
                                     y,
                                     width,
                                     height)];

    button.tag = kSGSearchGlassTag;

    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin;

    [view addSubview:button];
    [view bringSubviewToFront:button];
    SGSetSearchGlassVisibility(controller);
}

#pragma mark - Visibility polling

static const void *kSGVisibilityTimerKey = &kSGVisibilityTimerKey;

static void SGStartVisibilityPolling(UIViewController *controller) {
    if (!controller) return;

    NSTimer *oldTimer =
        objc_getAssociatedObject(controller, kSGVisibilityTimerKey);

    if (oldTimer && oldTimer.valid)
        return;

    __weak UIViewController *weakController = controller;

    NSTimer *timer =
        [NSTimer scheduledTimerWithTimeInterval:0.12
                                         repeats:YES
                                           block:^(NSTimer *t) {
        UIViewController *strongController = weakController;

        if (!strongController ||
            !strongController.view.window ||
            !SGIsMainSettingsController(strongController)) {
            [t invalidate];

            if (strongController)
                objc_setAssociatedObject(strongController,
                                         kSGVisibilityTimerKey,
                                         nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        SGSetSearchGlassVisibility(strongController);
    }];

    objc_setAssociatedObject(controller,
                             kSGVisibilityTimerKey,
                             timer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SGStopVisibilityPolling(UIViewController *controller) {
    if (!controller) return;

    NSTimer *timer =
        objc_getAssociatedObject(controller, kSGVisibilityTimerKey);

    [timer invalidate];

    objc_setAssociatedObject(controller,
                             kSGVisibilityTimerKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Logos hooks

@interface PSListController : UIViewController
@end

%hook PSListController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!SGIsMainSettingsController(self)) {
        SGStopVisibilityPolling(self);

        SGSearchButton *button =
            (SGSearchButton *)[self.view viewWithTag:kSGSearchGlassTag];

        if (button)
            button.hidden = YES;

        return;
    }

    SGInstallSearchGlass(self);
    SGStartVisibilityPolling(self);
    SGSetSearchGlassVisibility(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;

    SGStopVisibilityPolling(self);

    SGSearchButton *button =
        (SGSearchButton *)[self.view viewWithTag:kSGSearchGlassTag];

    if (button)
        button.hidden = YES;
}

%end

%hook UINavigationController

- (void)viewDidLayoutSubviews {
    %orig;

    if (!self.view.window.isKeyWindow)
        return;

    NSString *bundleID =
        [NSBundle.mainBundle bundleIdentifier];

    if (![bundleID isEqualToString:@"com.apple.Preferences"])
        return;

    UIViewController *root = self.viewControllers.firstObject;
    UIViewController *top = self.topViewController;

    if (!root)
        return;

    SGSearchButton *button =
        (SGSearchButton *)[root.view viewWithTag:kSGSearchGlassTag];

    if (!SGIsMainSettingsController(root) || top != root) {
        if (button)
            button.hidden = YES;
        return;
    }

    SGInstallSearchGlass(root);
    SGSetSearchGlassVisibility(root);
}

%end

%ctor {
    @autoreleasepool {
        /*
         * No private class is linked at build time.
         * CABackdropLayer and CAFilter are resolved dynamically.
         *
         * If Liquid (Gl)ass has registered the
         * dylv.liquidglass.searchpill filter, the button uses
         * the live Liquid Glass refraction engine.
         *
         * If the filter is unavailable, the code falls back to
         * a live CABackdropLayer gaussian blur rather than crashing.
         */
    }
}
