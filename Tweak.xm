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

@interface UISearchBar (SGSearchPrivate)
- (void)searchFieldBecomeFirstResponder;
@end

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
    [self applyLiquidGlass];

    return self;
}

- (void)setupSpecular {
    /*
     * Same visual concept used by LGLiveBackdropView:
     * a normal specular gradient and a stronger overlay-blended
     * gradient, both clipped to the rounded glass shape.
     */

    _specular = [CAGradientLayer layer];

    _specular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.30].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor
    ];

    _specular.locations = @[
        @0.0,
        @0.50,
        @1.0
    ];

    _specularBoost = [CAGradientLayer layer];

    _specularBoost.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.32].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.16].CGColor
    ];

    _specularBoost.locations = @[
        @0.0,
        @0.50,
        @1.0
    ];

    _specularBoost.compositingFilter = @"overlayBlendMode";

    _specularMask = [CAShapeLayer layer];
    _specularBoostMask = [CAShapeLayer layer];

    _specular.mask = _specularMask;
    _specularBoost.mask = _specularBoostMask;

    [self.layer addSublayer:_specular];
    [self.layer addSublayer:_specularBoost];
}

- (void)layoutSpecular {
    CGRect bounds = self.bounds;
    CGFloat radius = self.cornerRadius;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _specular.frame = bounds;
    _specularBoost.frame = bounds;

    UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(bounds, 0.35, 0.35)
            cornerRadius:MAX(0.0, radius - 0.35)];

    _specularMask.frame = bounds;
    _specularMask.path = path.CGPath;
    _specularMask.fillColor = UIColor.clearColor.CGColor;
    _specularMask.strokeColor = UIColor.blackColor.CGColor;
    _specularMask.lineWidth = 1.0;

    _specularBoostMask.frame = bounds;
    _specularBoostMask.path = path.CGPath;
    _specularBoostMask.fillColor = UIColor.clearColor.CGColor;
    _specularBoostMask.strokeColor = UIColor.blackColor.CGColor;
    _specularBoostMask.lineWidth = 1.0;

    /*
     * Same default specular angle used by Liquid (Gl)ass.
     */
    CGFloat angle = -M_PI_4;
    CGFloat dx = cos(angle) * 0.5;
    CGFloat dy = sin(angle) * 0.5;

    _specular.startPoint =
        CGPointMake(0.5 + dx, 0.5 + dy);

    _specular.endPoint =
        CGPointMake(0.5 - dx, 0.5 - dy);

    _specularBoost.startPoint = _specular.startPoint;
    _specularBoost.endPoint = _specular.endPoint;

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

@interface SGSearchButton : UIControl
@property(nonatomic, strong) SGLiveGlassView *glassView;
@property(nonatomic, strong) UIImageView *searchIcon;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIImageView *micIcon;
@end

@interface SGSearchButton ()
- (UIViewController *)nearestViewController;
- (UISearchController *)findSearchController:(UIViewController *)controller;
- (UISearchBar *)findSearchBarInView:(UIView *)view;
- (UIScrollView *)findScrollViewContainingView:(UIView *)target;
@end

@implementation SGSearchButton


- (void)updateAppearance {
    BOOL darkMode = NO;

    if (@available(iOS 13.0, *)) {
        darkMode =
            (self.traitCollection.userInterfaceStyle ==
             UIUserInterfaceStyleDark);
    }

    UIColor *color =
        darkMode ? UIColor.whiteColor : UIColor.blackColor;

    self.titleLabel.textColor = color;
    self.searchIcon.tintColor = color;
    self.micIcon.tintColor = color;
}



- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self)
        return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.exclusiveTouch = YES;
    self.userInteractionEnabled = YES;

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
        [UIColor colorWithWhite:0.08 alpha:0.92];

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

    self.titleLabel.textColor =
        [UIColor colorWithWhite:0.20 alpha:0.88];

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
        [UIColor colorWithWhite:0.08 alpha:0.92];

    self.micIcon.contentMode =
        UIViewContentModeScaleAspectFit;

    self.micIcon.userInteractionEnabled = NO;

    [self addSubview:self.micIcon];

    [self updateAppearance];
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
    UIViewController *vc = [self nearestViewController];
    if (!vc)
        return;

    UINavigationController *nav = vc.navigationController;

    // The real Settings search lives on the root controller.
    if (nav && nav.viewControllers.count > 1) {
        [nav popToRootViewControllerAnimated:YES];
    }

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            UIViewController *root =
                nav ? nav.viewControllers.firstObject : vc;

            if (!root)
                return;

            // 1. Use the actual UISearchBar when it is already loaded.
            UISearchBar *bar = [self findSearchBarInView:root.view];

            if (bar) {
                UIScrollView *scroll =
                    [self findScrollViewContainingView:bar];

                if (scroll) {
                    CGRect rect =
                        [bar convertRect:bar.bounds toView:scroll];

                    [scroll scrollRectToVisible:rect animated:YES];
                }

                if ([bar respondsToSelector:
                     @selector(searchFieldBecomeFirstResponder)]) {
                    [bar searchFieldBecomeFirstResponder];
                } else {
                    [bar becomeFirstResponder];
                }
                return;
            }

            // 2. Some Settings versions keep the UISearchController in
            // the controller hierarchy rather than directly in the view.
            UISearchController *searchController =
                [self findSearchController:root];

            if (searchController) {
                searchController.active = YES;

                UISearchBar *searchBar =
                    searchController.searchBar;

                if ([searchBar respondsToSelector:
                     @selector(searchFieldBecomeFirstResponder)]) {
                    [searchBar searchFieldBecomeFirstResponder];
                } else {
                    [searchBar becomeFirstResponder];
                }
                return;
            }

            // 3. The search UI can be attached to a window/scene.
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in
                     UIApplication.sharedApplication.connectedScenes) {

                    if (![scene isKindOfClass:[UIWindowScene class]])
                        continue;

                    if (scene.activationState ==
                        UISceneActivationStateUnattached)
                        continue;

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window in windowScene.windows) {
                        UISearchBar *windowBar =
                            [self findSearchBarInView:window];

                        if (!windowBar)
                            continue;

                        if ([windowBar respondsToSelector:
                             @selector(searchFieldBecomeFirstResponder)]) {
                            [windowBar searchFieldBecomeFirstResponder];
                        } else {
                            [windowBar becomeFirstResponder];
                        }
                        return;
                    }
                }
            }

            // 4. Settings may finish creating its search bar a little later.
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(0.30 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    UISearchBar *retry =
                        [self findSearchBarInView:root.view];

                    if (!retry)
                        return;

                    if ([retry respondsToSelector:
                         @selector(searchFieldBecomeFirstResponder)]) {
                        [retry searchFieldBecomeFirstResponder];
                    } else {
                        [retry becomeFirstResponder];
                    }
                });
        });
}

#pragma mark - View controller finder

- (UIViewController *)nearestViewController {
    UIResponder *responder = self;

    while (responder) {
        responder = [responder nextResponder];

        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }

    return nil;
}

- (UISearchController *)findSearchController:
    (UIViewController *)controller {

    if (!controller)
        return nil;

    if ([controller isKindOfClass:[UISearchController class]])
        return (UISearchController *)controller;

    for (UIViewController *child in controller.childViewControllers) {
        UISearchController *found =
            [self findSearchController:child];

        if (found)
            return found;
    }

    if (controller.presentedViewController) {
        UISearchController *found =
            [self findSearchController:controller.presentedViewController];

        if (found)
            return found;
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

    Class psClass = NSClassFromString(@"PSListController");

    if (!psClass ||
        ![controller isKindOfClass:psClass]) {
        return NO;
    }

    NSString *className = NSStringFromClass(controller.class);

    /*
     * Settings has used more than one root controller name across
     * iOS versions. Prefer the explicit root names, but keep the
     * navigation-stack fallback so the button still appears on the
     * actual Settings home page.
     */
    if ([className isEqualToString:@"PSRootListController"] ||
        [className isEqualToString:@"PSRootController"]) {
        UINavigationController *nav = controller.navigationController;

        if (!nav ||
            nav.viewControllers.firstObject == controller) {
            return YES;
        }

        return NO;
    }

    /*
     * Fallback for iOS versions where the Settings root controller
     * has another private class name:
     *
     * - must be a PSListController
     * - must be the first controller in the navigation stack
     * - must be the only controller currently pushed
     * - search-related controllers are explicitly rejected
     */
    UINavigationController *nav = controller.navigationController;

    if (!nav)
        return NO;

    if (nav.viewControllers.firstObject != controller)
        return NO;

    if (nav.viewControllers.count != 1)
        return NO;

    if ([className rangeOfString:@"Search"
                         options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return NO;
    }

    return YES;
}

static void SGRemoveSearchGlass(
    UIViewController *controller
) {
    if (!controller)
        return;

    UIView *view = controller.view;
    SGSearchButton *button =
        (SGSearchButton *)[view viewWithTag:kSGSearchGlassTag];

    if (button)
        [button removeFromSuperview];
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
        [view bringSubviewToFront:existing];
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
}


#pragma mark - iOS 26/27 General banner + icons

static const NSInteger kSGGeneralBannerTag = 0x5347424E;
static NSString * const kSGGeneralBannerPath =
    @"/Library/Application Support/SearchGlass/GeneralBanner.png";
static NSString * const kSGAboutIconPath =
    @"/Library/Application Support/SearchGlass/AboutIcon.png";
static NSString * const kSGSoftwareUpdateIconPath =
    @"/Library/Application Support/SearchGlass/SoftwareUpdateIcon.png";

static char kSGGeneralOriginalContentInsetKey;
static char kSGGeneralOriginalIndicatorInsetKey;
static char kSGGeneralBannerInsetAppliedKey;

static BOOL SGIsGeneralController(UIViewController *controller) {
    if (!controller)
        return NO;

    NSString *title = controller.title;
    if (!title.length)
        title = controller.navigationItem.title;

    if ([title isEqualToString:@"General"])
        return YES;

    /*
     * Some Settings versions don't expose the title on the
     * controller itself. In that case use the navigation item.
     */
    NSString *navTitle = controller.navigationItem.title;
    return [navTitle isEqualToString:@"General"];
}

static UIImage *SGLoadGeneralAsset(NSString *path) {
    // Try installed package resources first.
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image)
        return image;

    // Rootless fallback.
    if ([path hasPrefix:@"/Library/"]) {
        NSString *rootless =
            [@"/var/jb" stringByAppendingString:path];
        image = [UIImage imageWithContentsOfFile:rootless];
        if (image)
            return image;
    }

    // The supplied iOS 26/27 assets are embedded so the tweak still
    // works even when the package resource path is not available.
    NSString *dataString = nil;

    if ([path hasSuffix:@"GeneralBanner.png"]) {
        dataString = @"/9j/4QEoRXhpZgAATU0AKgAAAAgABwESAAMAAAABAAEAAAEaAAUAAAABAAAAYgEbAAUAAAABAAAAagEoAAMAAAABAAIAAAEyAAIAAAAUAAAAcgITAAMAAAABAAEAAIdpAAQAAAABAAAAhgAAAAAAAACQAAAAAQAAAJAAAAABMjAyNjowODoyMyAwNzo1OTowMAAACZAAAAcAAAAEMDIyMZADAAIAAAAUAAAA+JEBAAcAAAAEAQIDAJKGAAcAAAASAAABDKAAAAcAAAAEMDEwMKABAAMAAAABAAEAAKACAAQAAAABAAAAeKADAAQAAAABAAAAeKQGAAMAAAABAAAAAAAAAAAyMDI2OjA4OjIzIDA3OjU5OjAwAEFTQ0lJAAAAU2NyZWVuc2hvdAAA/+EJ0Gh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgcGhvdG9zaG9wOkRhdGVDcmVhdGVkPSIyMDI2LTA4LTIzVDA3OjU5OjAwIiB4bXA6TW9kaWZ5RGF0ZT0iMjAyNi0wOC0yM1QwNzo1OTowMCIvPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg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";
    } else if ([path hasSuffix:@"AboutIcon.png"]) {
        dataString = @"/9j/4QEoRXhpZgAATU0AKgAAAAgABwESAAMAAAABAAEAAAEaAAUAAAABAAAAYgEbAAUAAAABAAAAagEoAAMAAAABAAIAAAEyAAIAAAAUAAAAcgITAAMAAAABAAEAAIdpAAQAAAABAAAAhgAAAAAAAACQAAAAAQAAAJAAAAABMjAyNjowODoyMyAwNzo1OTozNQAACZAAAAcAAAAEMDIyMZADAAIAAAAUAAAA+JEBAAcAAAAEAQIDAJKGAAcAAAASAAABDKAAAAcAAAAEMDEwMKABAAMAAAABAAEAAKACAAQAAAABAAAAeKADAAQAAAABAAAAeKQGAAMAAAABAAAAAAAAAAAyMDI2OjA4OjIzIDA3OjU5OjM1AEFTQ0lJAAAAU2NyZWVuc2hvdAAA/+EJ0Gh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgcGhvdG9zaG9wOkRhdGVDcmVhdGVkPSIyMDI2LTA4LTIzVDA3OjU5OjM1IiB4bXA6TW9kaWZ5RGF0ZT0iMjAyNi0wOC0yM1QwNzo1OTozNSIvPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg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";
    } else if ([path hasSuffix:@"SoftwareUpdateIcon.png"]) {
        dataString = @"/9j/4QEoRXhpZgAATU0AKgAAAAgABwESAAMAAAABAAEAAAEaAAUAAAABAAAAYgEbAAUAAAABAAAAagEoAAMAAAABAAIAAAEyAAIAAAAUAAAAcgITAAMAAAABAAEAAIdpAAQAAAABAAAAhgAAAAAAAACQAAAAAQAAAJAAAAABMjAyNjowODoyMyAwODowMDoxOAAACZAAAAcAAAAEMDIyMZADAAIAAAAUAAAA+JEBAAcAAAAEAQIDAJKGAAcAAAASAAABDKAAAAcAAAAEMDEwMKABAAMAAAABAAEAAKACAAQAAAABAAAAraADAAQAAAABAAAAeKQGAAMAAAABAAAAAAAAAAAyMDI2OjA4OjIzIDA4OjAwOjE4AEFTQ0lJAAAAU2NyZWVuc2hvdAAA/+EJ0Gh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8APD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgcGhvdG9zaG9wOkRhdGVDcmVhdGVkPSIyMDI2LTA4LTIzVDA4OjAwOjE4IiB4bXA6TW9kaWZ5RGF0ZT0iMjAyNi0wOC0yM1QwODowMDoxOCIvPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg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";
    }

    if (!dataString.length)
        return nil;

    NSData *data =
        [[NSData alloc]
            initWithBase64EncodedString:dataString
            options:NSDataBase64DecodingIgnoreUnknownCharacters];

    return data ? [UIImage imageWithData:data] : nil;
}

static UILabel *SGMakeLabel(NSString *text,
                            UIFont *font,
                            UIColor *color) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.backgroundColor = UIColor.clearColor;
    return label;
}

static UIView *SGGeneralBannerView(UIViewController *controller) {
    UIView *root = controller.view;

    UIView *banner = [root viewWithTag:kSGGeneralBannerTag];
    if (banner)
        return banner;

    /*
     * Banner deliberately lives above the UITableView so it can sit
     * immediately before the "About" cell without changing Apple's
     * table data source.
     */
    banner = [[UIView alloc] initWithFrame:CGRectZero];
    banner.tag = kSGGeneralBannerTag;
    banner.backgroundColor = UIColor.clearColor;
    banner.layer.cornerRadius = 24.0;
    banner.layer.cornerCurve = kCACornerCurveContinuous;
    banner.clipsToBounds = YES;
    banner.userInteractionEnabled = NO;

    UIVisualEffectView *material =
        [[UIVisualEffectView alloc]
            initWithEffect:
                [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];

    material.tag = kSGGeneralBannerTag + 1;
    material.alpha = 0.96;
    material.userInteractionEnabled = NO;
    [banner addSubview:material];

    UIImageView *icon =
        [[UIImageView alloc]
            initWithFrame:CGRectZero];

    UIImage *bannerImage =
        SGLoadGeneralAsset(kSGGeneralBannerPath);

    /*
     * Fallback to the Settings gear SF Symbol if the custom PNG
     * has not yet been installed in the package.
     */
    if (!bannerImage) {
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration
                configurationWithPointSize:46.0
                weight:UIImageSymbolWeightRegular];

        bannerImage =
            [UIImage systemImageNamed:@"gear"
                    withConfiguration:config];
    }

    icon.image =
        [bannerImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.clipsToBounds = NO;
    icon.tintColor = UIColor.clearColor;
    icon.layer.cornerRadius = 0.0;
    icon.userInteractionEnabled = NO;
    [banner addSubview:icon];

    UILabel *title =
        SGMakeLabel(@"General",
                    [UIFont systemFontOfSize:25.0
                                      weight:UIFontWeightBold],
                    UIColor.labelColor);
    title.tag = kSGGeneralBannerTag + 2;
    [banner addSubview:title];

    UILabel *subtitle =
        SGMakeLabel(
            @"Manage your overall setup and preferences for Device, such as software updates, device language, CarPlay, AirDrop, and more.",
            [UIFont systemFontOfSize:17.0
                              weight:UIFontWeightRegular],
            UIColor.secondaryLabelColor);
    subtitle.tag = kSGGeneralBannerTag + 3;
    [banner addSubview:subtitle];

    [root addSubview:banner];
    return banner;
}

static UITableView *SGFindSettingsTableView(UIView *view) {
    if (!view)
        return nil;

    if ([view isKindOfClass:[UITableView class]])
        return (UITableView *)view;

    for (UIView *subview in view.subviews) {
        UITableView *table = SGFindSettingsTableView(subview);
        if (table)
            return table;
    }

    return nil;
}

static UITableViewCell *SGFindGeneralCell(UITableView *table,
                                          NSString *text) {
    if (!table)
        return nil;

    for (UITableViewCell *cell in table.visibleCells) {
        NSString *label = cell.textLabel.text;

        if ([label isEqualToString:text])
            return cell;
    }

    /*
     * Also inspect all currently loaded table subviews. This catches
     * cells that are present during the initial layout transition.
     */
    for (UIView *subview in table.subviews) {
        if (![subview isKindOfClass:[UITableViewCell class]])
            continue;

        UITableViewCell *cell = (UITableViewCell *)subview;

        if ([cell.textLabel.text isEqualToString:text])
            return cell;
    }

    return nil;
}

static void SGApplyGeneralIcon(UITableViewCell *cell,
                               NSString *path,
                               NSString *fallbackSymbol) {
    if (!cell)
        return;

    UIImage *image = SGLoadGeneralAsset(path);

    if (!image) {
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration
                configurationWithPointSize:24.0
                weight:UIImageSymbolWeightRegular];

        image = [UIImage systemImageNamed:fallbackSymbol
                        withConfiguration:config];
    }

    if (!image)
        return;

    cell.imageView.image =
        [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.imageView.tintColor = UIColor.clearColor;
    cell.imageView.clipsToBounds = NO;

    /*
     * The supplied icons already contain their rounded-square
     * background. Do not mask them with a second corner radius.
     */
    cell.imageView.layer.cornerRadius = 0.0;
}

static void SGLayoutGeneralBanner(UIViewController *controller) {
    if (!SGIsGeneralController(controller))
        return;

    UITableView *table =
        SGFindSettingsTableView(controller.view);

    if (!table)
        return;

    UITableViewCell *about =
        SGFindGeneralCell(table, @"About");

    UITableViewCell *software =
        SGFindGeneralCell(table, @"Software Update");

    if (about) {
        SGApplyGeneralIcon(
            about,
            kSGAboutIconPath,
            @"iphone");

        /*
         * The Software Update icon is installed independently so
         * changing one cell never changes the other.
         */
        if (software) {
            SGApplyGeneralIcon(
                software,
                kSGSoftwareUpdateIconPath,
                @"gearshape");
        }
    }

    UIView *banner =
        SGGeneralBannerView(controller);

    if (!about || !banner)
        return;

    /*
     * Reserve real table space for the banner. Without this, the
     * native About and Software Update cells remain underneath it.
     */
    CGFloat side = 20.0;
    CGFloat bannerHeight = 154.0;
    CGFloat gap = 12.0;

    CGFloat width =
        CGRectGetWidth(controller.view.bounds) - side * 2.0;

    if (!objc_getAssociatedObject(table, &kSGGeneralOriginalContentInsetKey)) {
        UIEdgeInsets original = table.contentInset;
        UIEdgeInsets indicator = table.verticalScrollIndicatorInsets;

        objc_setAssociatedObject(
            table,
            &kSGGeneralOriginalContentInsetKey,
            [NSValue valueWithUIEdgeInsets:original],
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        objc_setAssociatedObject(
            table,
            &kSGGeneralOriginalIndicatorInsetKey,
            [NSValue valueWithUIEdgeInsets:indicator],
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!objc_getAssociatedObject(table, &kSGGeneralBannerInsetAppliedKey)) {
        UIEdgeInsets original =
            [objc_getAssociatedObject(
                table,
                &kSGGeneralOriginalContentInsetKey) UIEdgeInsetsValue];

        original.top += bannerHeight + gap;
        table.contentInset = original;

        UIEdgeInsets indicator =
            [objc_getAssociatedObject(
                table,
                &kSGGeneralOriginalIndicatorInsetKey) UIEdgeInsetsValue];

        indicator.top += bannerHeight + gap;
        table.verticalScrollIndicatorInsets = indicator;

        objc_setAssociatedObject(
            table,
            &kSGGeneralBannerInsetAppliedKey,
            @YES,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [table setNeedsLayout];
        [table layoutIfNeeded];
    }

    CGRect aboutFrame =
        [about convertRect:about.bounds toView:controller.view];

    CGFloat y =
        CGRectGetMinY(aboutFrame) -
        bannerHeight -
        gap;

    CGFloat minimumY =
        controller.view.safeAreaInsets.top + 8.0;

    if (y < minimumY)
        y = minimumY;

    banner.frame =
        CGRectMake(side, y, width, bannerHeight);

    UIView *material =
        [banner viewWithTag:kSGGeneralBannerTag + 1];

    UIImageView *icon = nil;
    UILabel *title = nil;
    UILabel *subtitle = nil;

    for (UIView *subview in banner.subviews) {
        if ([subview isKindOfClass:[UIImageView class]])
            icon = (UIImageView *)subview;
        else if (subview.tag == kSGGeneralBannerTag + 2)
            title = (UILabel *)subview;
        else if (subview.tag == kSGGeneralBannerTag + 3)
            subtitle = (UILabel *)subview;
    }

    material.frame = banner.bounds;

    /*
     * Compact card layout: the supplied banner icon is intentionally
     * smaller and rounded, while the text gets its own full-width
     * column so it cannot overflow the card.
     */
    icon.frame =
        CGRectMake(24.0, 22.0, 58.0, 58.0);

    icon.layer.cornerRadius = 15.0;
    icon.layer.cornerCurve = kCACornerCurveContinuous;
    icon.clipsToBounds = YES;

    title.frame =
        CGRectMake(94.0,
                   22.0,
                   width - 118.0,
                   31.0);

    subtitle.frame =
        CGRectMake(94.0,
                   54.0,
                   width - 118.0,
                   78.0);

    subtitle.numberOfLines = 3;
    subtitle.adjustsFontSizeToFitWidth = YES;
    subtitle.minimumScaleFactor = 0.85;

    /*
     * Banner must remain behind the table cells but above the
     * table's background. The table itself is still fully native.
     */
    [controller.view bringSubviewToFront:banner];
}

static void SGRemoveGeneralBanner(UIViewController *controller) {
    if (!controller)
        return;

    UIView *banner =
        [controller.view viewWithTag:kSGGeneralBannerTag];

    UITableView *table =
        SGFindSettingsTableView(controller.view);

    if (table) {
        NSValue *contentValue =
            objc_getAssociatedObject(
                table,
                &kSGGeneralOriginalContentInsetKey);

        NSValue *indicatorValue =
            objc_getAssociatedObject(
                table,
                &kSGGeneralOriginalIndicatorInsetKey);

        if (contentValue)
            table.contentInset = contentValue.UIEdgeInsetsValue;

        if (indicatorValue)
            table.verticalScrollIndicatorInsets =
                indicatorValue.UIEdgeInsetsValue;

        objc_setAssociatedObject(
            table,
            &kSGGeneralBannerInsetAppliedKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        objc_setAssociatedObject(
            table,
            &kSGGeneralOriginalContentInsetKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        objc_setAssociatedObject(
            table,
            &kSGGeneralOriginalIndicatorInsetKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (banner)
        [banner removeFromSuperview];
}

#pragma mark - Logos hooks

@interface PSListController : UIViewController
@end

%hook PSListController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (SGIsMainSettingsController(self)) {
        SGInstallSearchGlass(self);
    } else {
        SGRemoveSearchGlass(self);
    }

    if (SGIsGeneralController(self)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SGLayoutGeneralBanner(self);
        });
    } else {
        SGRemoveGeneralBanner(self);
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (SGIsGeneralController(self)) {
        SGLayoutGeneralBanner(self);
    } else {
        SGRemoveGeneralBanner(self);
    }
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

    UIViewController *top =
        self.topViewController;

    if (SGIsMainSettingsController(top)) {
        SGInstallSearchGlass(top);
    } else {
        /*
         * Remove it while any child Settings page is visible.
         * This guarantees the pill cannot remain visible on
         * sub-pages during navigation/interactive transitions.
         */
        for (UIViewController *controller in self.viewControllers) {
            SGRemoveSearchGlass(controller);
        }
    }
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
