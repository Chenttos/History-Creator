#import <UIKit/UIKit.h>

/*
 * SearchGlass
 * iOS 16 / Rootless
 *
 * Barra de pesquisa estilo glass na parte inferior
 * do aplicativo Ajustes.
 */

static NSString * const SGSPreferencesID =
    @"com.samuel.settingsglasssearch";

static UIView *sgsContainer = nil;

static BOOL sgsEnabled = YES;
static CGFloat sgsOpacity = 0.72;
static CGFloat sgsBlur = 18.0;
static CGFloat sgsRadius = 28.0;


#pragma mark - Preferences

static void SGSLoadPreferences(void) {

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SGSPreferencesID];

    if (defaults) {

        if ([defaults objectForKey:@"enabled"])
            sgsEnabled = [defaults boolForKey:@"enabled"];

        if ([defaults objectForKey:@"opacity"])
            sgsOpacity = [defaults doubleForKey:@"opacity"];

        if ([defaults objectForKey:@"blur"])
            sgsBlur = [defaults doubleForKey:@"blur"];

        if ([defaults objectForKey:@"radius"])
            sgsRadius = [defaults doubleForKey:@"radius"];
    }

    sgsOpacity = MIN(MAX(sgsOpacity, 0.1), 1.0);
    sgsBlur = MIN(MAX(sgsBlur, 1.0), 50.0);
    sgsRadius = MIN(MAX(sgsRadius, 8.0), 50.0);
}


#pragma mark - Settings Window

static UIWindow *SGSGetSettingsWindow(void) {

    UIApplication *application =
        [UIApplication sharedApplication];

    UIWindow *result = nil;

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive)
            continue;

        for (UIWindow *window in windowScene.windows) {

            if (!window.hidden &&
                window.rootViewController &&
                window.windowLevel == UIWindowLevelNormal) {

                result = window;

                if (window.isKeyWindow)
                    return window;
            }
        }
    }

    return result;
}


#pragma mark - Find Search Bar

static UISearchBar *SGSFindSearchBarInView(UIView *view) {

    if (!view)
        return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview in view.subviews) {

        UISearchBar *result =
            SGSFindSearchBarInView(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Find Search Controller

static UISearchController *
SGSFindSearchController(UIViewController *controller) {

    if (!controller)
        return nil;

    if (controller.navigationItem.searchController)
        return controller.navigationItem.searchController;

    if ([controller isKindOfClass:
        [UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)controller;

        UISearchController *result =
            SGSFindSearchController(
                navigation.visibleViewController
            );

        if (result)
            return result;
    }

    if ([controller isKindOfClass:
        [UISplitViewController class]]) {

        UISplitViewController *split =
            (UISplitViewController *)controller;

        for (UIViewController *child
             in split.viewControllers) {

            UISearchController *result =
                SGSFindSearchController(child);

            if (result)
                return result;
        }
    }

    for (UIViewController *child
         in controller.childViewControllers) {

        UISearchController *result =
            SGSFindSearchController(child);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Open Native Settings Search

static void SGSOpenNativeSearch(void) {

    dispatch_async(
        dispatch_get_main_queue(), ^{

        UIWindow *window =
            SGSGetSettingsWindow();

        if (!window)
            return;

        UIViewController *root =
            window.rootViewController;

        if (!root)
            return;

        /*
         * Primeiro tenta encontrar uma barra
         * de pesquisa que já esteja na tela.
         */

        UISearchBar *searchBar =
            SGSFindSearchBarInView(window);

        if (searchBar) {

            [searchBar becomeFirstResponder];

            [searchBar setShowsCancelButton:YES
                                    animated:YES];

            return;
        }

        /*
         * Depois procura UISearchController.
         */

        UISearchController *searchController =
            SGSFindSearchController(root);

        if (searchController) {

            searchController.active = YES;

            [searchController.searchBar
                becomeFirstResponder];

            return;
        }

        /*
         * Tenta encontrar a NavigationController.
         */

        UINavigationController *navigation = nil;

        if ([root isKindOfClass:
            [UINavigationController class]]) {

            navigation =
                (UINavigationController *)root;
        }

        /*
         * iPad / Split View.
         */

        if (!navigation &&
            [root isKindOfClass:
            [UISplitViewController class]]) {

            UISplitViewController *split =
                (UISplitViewController *)root;

            for (UIViewController *controller
                 in split.viewControllers) {

                if ([controller isKindOfClass:
                    [UINavigationController class]]) {

                    navigation =
                        (UINavigationController *)controller;

                    break;
                }
            }
        }

        if (!navigation)
            return;

        /*
         * Volta para a raiz do Ajustes.
         */

        [navigation
            popToRootViewControllerAnimated:NO];

        /*
         * Dá tempo para a interface
         * nativa do Ajustes aparecer.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                0.35 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(), ^{

            UISearchController *search =
                SGSFindSearchController(navigation);

            if (search) {

                search.active = YES;

                [search.searchBar
                    becomeFirstResponder];

                return;
            }

            UISearchBar *bar =
                SGSFindSearchBarInView(
                    navigation.view
                );

            if (bar)
                [bar becomeFirstResponder];
        });
    });
}


#pragma mark - Search Glass Control

@interface SGSSearchControl : UIControl

@property(nonatomic, strong)
UIVisualEffectView *blurView;

@property(nonatomic, strong)
UIView *glassTint;

@property(nonatomic, strong)
UIImageView *searchIcon;

@property(nonatomic, strong)
UILabel *searchLabel;

@property(nonatomic, strong)
UIImageView *micIcon;

@property(nonatomic, strong)
CAGradientLayer *reflectionLayer;

@end


@implementation SGSSearchControl

- (instancetype)initWithFrame:(CGRect)frame {

    self = [super initWithFrame:frame];

    if (self) {

        self.backgroundColor =
            UIColor.clearColor;

        self.clipsToBounds = YES;

        self.layer.cornerRadius =
            sgsRadius;

        self.layer.masksToBounds = YES;


        /*
         * Glass blur
         */

        UIBlurEffect *blurEffect =
            [UIBlurEffect
                effectWithStyle:
                UIBlurEffectStyleSystemMaterial];

        self.blurView =
            [[UIVisualEffectView alloc]
                initWithEffect:blurEffect];

        self.blurView.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.blurView.alpha =
            MIN(MAX(sgsBlur / 20.0, 0.2), 1.0);

        [self addSubview:self.blurView];


        /*
         * Glass tint
         */

        self.glassTint =
            [[UIView alloc] init];

        self.glassTint.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.glassTint.backgroundColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:
                sgsOpacity * 0.30];

        [self addSubview:self.glassTint];


        /*
         * Search icon
         */

        UIImageSymbolConfiguration *searchConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:31.0
                weight:UIImageSymbolWeightRegular];

        UIImage *searchImage =
            [UIImage
                systemImageNamed:@"magnifyingglass"
                withConfiguration:searchConfig];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:searchImage];

        self.searchIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchIcon.tintColor =
            UIColor.labelColor;

        self.searchIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        [self addSubview:self.searchIcon];


        /*
         * Search text
         */

        self.searchLabel =
            [[UILabel alloc] init];

        self.searchLabel.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchLabel.text =
            @"Search";

        self.searchLabel.textColor =
            [[UIColor labelColor]
                colorWithAlphaComponent:0.60];

        self.searchLabel.font =
            [UIFont
                systemFontOfSize:29.0
                weight:UIFontWeightRegular];

        [self addSubview:self.searchLabel];


        /*
         * Microphone
         *
         * CORREÇÃO:
         * UIImageSymbolWeightMedium
         */

        UIImageSymbolConfiguration *micConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:29.0
                weight:UIImageSymbolWeightMedium];

        UIImage *micImage =
            [UIImage
                systemImageNamed:@"mic"
                withConfiguration:micConfig];

        self.micIcon =
            [[UIImageView alloc]
                initWithImage:micImage];

        self.micIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.micIcon.tintColor =
            UIColor.labelColor;

        self.micIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        [self addSubview:self.micIcon];


        /*
         * Constraints
         */

        [NSLayoutConstraint activateConstraints:@[

            /*
             * Blur
             */

            [self.blurView.leadingAnchor
                constraintEqualToAnchor:
                self.leadingAnchor],

            [self.blurView.trailingAnchor
                constraintEqualToAnchor:
                self.trailingAnchor],

            [self.blurView.topAnchor
                constraintEqualToAnchor:
                self.topAnchor],

            [self.blurView.bottomAnchor
                constraintEqualToAnchor:
                self.bottomAnchor],


            /*
             * Tint
             */

            [self.glassTint.leadingAnchor
                constraintEqualToAnchor:
                self.leadingAnchor],

            [self.glassTint.trailingAnchor
                constraintEqualToAnchor:
                self.trailingAnchor],

            [self.glassTint.topAnchor
                constraintEqualToAnchor:
                self.topAnchor],

            [self.glassTint.bottomAnchor
                constraintEqualToAnchor:
                self.bottomAnchor],


            /*
             * Search icon
             */

            [self.searchIcon.leadingAnchor
                constraintEqualToAnchor:
                self.leadingAnchor
                constant:26.0],

            [self.searchIcon.centerYAnchor
                constraintEqualToAnchor:
                self.centerYAnchor],

            [self.searchIcon.widthAnchor
                constraintEqualToConstant:34.0],

            [self.searchIcon.heightAnchor
                constraintEqualToConstant:34.0],


            /*
             * Search text
             */

            [self.searchLabel.leadingAnchor
                constraintEqualToAnchor:
                self.searchIcon.trailingAnchor
                constant:20.0],

            [self.searchLabel.centerYAnchor
                constraintEqualToAnchor:
                self.centerYAnchor],

            [self.searchLabel.trailingAnchor
                constraintLessThanOrEqualToAnchor:
                self.micIcon.leadingAnchor
                constant:-15.0],


            /*
             * Microphone
             */

            [self.micIcon.trailingAnchor
                constraintEqualToAnchor:
                self.trailingAnchor
                constant:-26.0],

            [self.micIcon.centerYAnchor
                constraintEqualToAnchor:
                self.centerYAnchor],

            [self.micIcon.widthAnchor
                constraintEqualToConstant:34.0],

            [self.micIcon.heightAnchor
                constraintEqualToConstant:34.0]

        ]];


        /*
         * Reflection
         */

        self.reflectionLayer =
            [CAGradientLayer layer];

        self.reflectionLayer.colors = @[

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.38].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.10].CGColor,

            (id)[[UIColor clearColor]
                colorWithAlphaComponent:0.0].CGColor
        ];

        self.reflectionLayer.startPoint =
            CGPointMake(0.5, 0.0);

        self.reflectionLayer.endPoint =
            CGPointMake(0.5, 0.65);

        [self.layer addSublayer:
            self.reflectionLayer];


        /*
         * Border
         */

        self.layer.borderWidth =
            0.7;

        self.layer.borderColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:0.65].CGColor;
    }

    return self;
}


- (void)layoutSubviews {

    [super layoutSubviews];

    self.layer.cornerRadius =
        sgsRadius;

    self.reflectionLayer.frame =
        self.bounds;

    self.reflectionLayer.cornerRadius =
        sgsRadius;
}


#pragma mark - Touch

- (BOOL)beginTrackingWithTouch:(UITouch *)touch
                      withEvent:(UIEvent *)event {

    BOOL result =
        [super beginTrackingWithTouch:touch
                            withEvent:event];

    [UIView animateWithDuration:0.10
                     animations:^{

        self.transform =
            CGAffineTransformMakeScale(
                0.985,
                0.985
            );

        self.alpha = 0.72;
    }];

    return result;
}


- (void)endTrackingWithTouch:(UITouch *)touch
                    withEvent:(UIEvent *)event {

    [super endTrackingWithTouch:touch
                       withEvent:event];

    [UIView animateWithDuration:0.15
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];

    SGSOpenNativeSearch();
}


- (void)cancelTrackingWithEvent:(UIEvent *)event {

    [super cancelTrackingWithEvent:event];

    [UIView animateWithDuration:0.15
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];
}

@end


#pragma mark - Create Search Glass

static void SGSRemoveSearchBar(void) {

    if (sgsContainer) {

        [sgsContainer removeFromSuperview];

        sgsContainer = nil;
    }
}


static void SGSCreateSearchBar(void) {

    SGSLoadPreferences();

    if (!sgsEnabled)
        return;

    if (sgsContainer &&
        sgsContainer.superview) {

        return;
    }

    UIWindow *window =
        SGSGetSettingsWindow();

    if (!window)
        return;


    /*
     * Container
     */

    sgsContainer =
        [[UIView alloc] init];

    sgsContainer.translatesAutoresizingMaskIntoConstraints =
        NO;

    sgsContainer.backgroundColor =
        UIColor.clearColor;

    sgsContainer.userInteractionEnabled =
        YES;


    /*
     * Search control
     */

    SGSSearchControl *searchControl =
        [[SGSSearchControl alloc] init];

    searchControl.translatesAutoresizingMaskIntoConstraints =
        NO;

    [sgsContainer addSubview:
        searchControl];

    [window addSubview:
        sgsContainer];


    /*
     * Position
     */

    [NSLayoutConstraint activateConstraints:@[

        [sgsContainer.leadingAnchor
            constraintEqualToAnchor:
            window.leadingAnchor
            constant:16.0],

        [sgsContainer.trailingAnchor
            constraintEqualToAnchor:
            window.trailingAnchor
            constant:-16.0],

        [sgsContainer.bottomAnchor
            constraintEqualToAnchor:
            window.safeAreaLayoutGuide.bottomAnchor
            constant:-12.0],

        [sgsContainer.heightAnchor
            constraintEqualToConstant:56.0],


        /*
         * Search control
         */

        [searchControl.leadingAnchor
            constraintEqualToAnchor:
            sgsContainer.leadingAnchor],

        [searchControl.trailingAnchor
            constraintEqualToAnchor:
            sgsContainer.trailingAnchor],

        [searchControl.topAnchor
            constraintEqualToAnchor:
            sgsContainer.topAnchor],

        [searchControl.bottomAnchor
            constraintEqualToAnchor:
            sgsContainer.bottomAnchor]

    ]];
}


#pragma mark - Refresh

static void SGSRefresh(void) {

    dispatch_async(
        dispatch_get_main_queue(), ^{

        SGSRemoveSearchBar();

        SGSLoadPreferences();

        if (sgsEnabled)
            SGSCreateSearchBar();
    });
}


#pragma mark - View Controller Hook

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {

    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:
          @"com.apple.Preferences"]) {

        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.30 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(), ^{

        SGSCreateSearchBar();
    });
}

%end


#pragma mark - Application Hook

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application {

    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:
          @"com.apple.Preferences"]) {

        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.35 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(), ^{

        SGSCreateSearchBar();
    });
}

%end


#pragma mark - Preferences Notification

static void SGSPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo) {

    dispatch_async(
        dispatch_get_main_queue(), ^{

        SGSRefresh();
    });
}


#pragma mark - Constructor

%ctor {

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:
          @"com.apple.Preferences"]) {

        return;
    }

    SGSLoadPreferences();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SGSPreferencesChanged,
        CFSTR(
            "com.samuel.settingsglasssearch/preferencesChanged"
        ),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    dispatch_async(
        dispatch_get_main_queue(), ^{

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                0.50 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(), ^{

            SGSCreateSearchBar();
        });
    });
}
