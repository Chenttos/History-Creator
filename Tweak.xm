#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Constants

static NSString * const SGSPreferencesID =
    @"com.samuel.settingsglasssearch";

static NSString * const SGSPreferencesNotification =
    @"com.samuel.settingsglasssearch/preferencesChanged";


#pragma mark - Global

static UIView *sgsContainer = nil;

static BOOL sgsEnabled = YES;
static CGFloat sgsBlur = 14.0;
static CGFloat sgsRadius = 22.0;


#pragma mark - Preferences

static void SGSLoadPreferences(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SGSPreferencesID];

    if (!defaults)
        return;

    if ([defaults objectForKey:@"enabled"])
        sgsEnabled = [defaults boolForKey:@"enabled"];

    if ([defaults objectForKey:@"blur"])
        sgsBlur = [defaults doubleForKey:@"blur"];

    if ([defaults objectForKey:@"radius"])
        sgsRadius = [defaults doubleForKey:@"radius"];

    /*
     * Segurança
     */

    sgsBlur =
        MIN(MAX(sgsBlur, 1.0), 40.0);

    sgsRadius =
        MIN(MAX(sgsRadius, 10.0), 35.0);
}


#pragma mark - Settings Window

static UIWindow *SGSGetSettingsWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    UIWindow *fallbackWindow = nil;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
            continue;

        for (UIWindow *window in windowScene.windows)
        {
            if (window.hidden)
                continue;

            if (!window.rootViewController)
                continue;

            if (window.isKeyWindow)
                return window;

            fallbackWindow = window;
        }
    }

    return fallbackWindow;
}


#pragma mark - Recursive Search Bar Finder

static UISearchBar *SGSFindSearchBar(UIView *view)
{
    if (!view)
        return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview in view.subviews)
    {
        UISearchBar *result =
            SGSFindSearchBar(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Search Controller Finder

static UISearchController *
SGSFindSearchController(UIViewController *controller)
{
    if (!controller)
        return nil;

    if (controller.navigationItem.searchController)
        return controller.navigationItem.searchController;

    /*
     * UINavigationController
     */

    if ([controller
         isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *navigationController =
            (UINavigationController *)controller;

        UISearchController *result =
            SGSFindSearchController(
                navigationController.visibleViewController
            );

        if (result)
            return result;
    }

    /*
     * UISplitViewController
     */

    if ([controller
         isKindOfClass:[UISplitViewController class]])
    {
        UISplitViewController *split =
            (UISplitViewController *)controller;

        for (UIViewController *child
             in split.viewControllers)
        {
            UISearchController *result =
                SGSFindSearchController(child);

            if (result)
                return result;
        }
    }

    /*
     * Child controllers
     */

    for (UIViewController *child
         in controller.childViewControllers)
    {
        UISearchController *result =
            SGSFindSearchController(child);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Find Search Button

static UIView *SGSFindSearchElement(UIView *view)
{
    if (!view)
        return nil;

    /*
     * UISearchBar
     */

    if ([view isKindOfClass:[UISearchBar class]])
        return view;

    /*
     * UILabel "Search"
     */

    if ([view isKindOfClass:[UILabel class]])
    {
        UILabel *label = (UILabel *)view;

        NSString *text = label.text;

        if (text.length &&
            [text localizedCaseInsensitiveCompare:@"Search"] ==
            NSOrderedSame)
        {
            return label.superview;
        }
    }

    /*
     * UIButton "Search"
     */

    if ([view isKindOfClass:[UIButton class]])
    {
        UIButton *button =
            (UIButton *)view;

        NSString *title =
            [button titleForState:UIControlStateNormal];

        if (title.length &&
            [title localizedCaseInsensitiveCompare:@"Search"] ==
            NSOrderedSame)
        {
            return button;
        }
    }

    /*
     * Recursive
     */

    for (UIView *subview in view.subviews)
    {
        UIView *result =
            SGSFindSearchElement(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Open Native Settings Search

static void SGSOpenNativeSearch(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        UIWindow *window =
            SGSGetSettingsWindow();

        if (!window)
            return;

        UIViewController *root =
            window.rootViewController;

        if (!root)
            return;


        /*
         * PRIMEIRO:
         * procura UISearchBar existente.
         */

        UISearchBar *searchBar =
            SGSFindSearchBar(window);

        if (searchBar)
        {
            searchBar.hidden = NO;

            [searchBar becomeFirstResponder];

            return;
        }


        /*
         * SEGUNDO:
         * procura UISearchController.
         */

        UISearchController *searchController =
            SGSFindSearchController(root);

        if (searchController)
        {
            searchController.active = YES;

            [searchController.searchBar
                becomeFirstResponder];

            return;
        }


        /*
         * TERCEIRO:
         * procura elemento "Search".
         */

        UIView *searchElement =
            SGSFindSearchElement(window);

        if (searchElement)
        {
            /*
             * Se for botão.
             */

            if ([searchElement
                 isKindOfClass:[UIButton class]])
            {
                UIButton *button =
                    (UIButton *)searchElement;

                [button
                    sendActionsForControlEvents:
                    UIControlEventTouchUpInside];

                return;
            }


            /*
             * Procura botão dentro da célula.
             */

            for (UIView *subview
                 in searchElement.subviews)
            {
                if ([subview
                     isKindOfClass:[UIButton class]])
                {
                    UIButton *button =
                        (UIButton *)subview;

                    [button
                        sendActionsForControlEvents:
                        UIControlEventTouchUpInside];

                    return;
                }
            }
        }


        /*
         * QUARTO:
         * o Settings pode ainda estar montando
         * a interface.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.30 *
                          NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

            UIWindow *lateWindow =
                SGSGetSettingsWindow();

            if (!lateWindow)
                return;

            UISearchBar *lateBar =
                SGSFindSearchBar(lateWindow);

            if (lateBar)
            {
                lateBar.hidden = NO;

                [lateBar becomeFirstResponder];

                return;
            }

            UISearchController *lateController =
                SGSFindSearchController(
                    lateWindow.rootViewController
                );

            if (lateController)
            {
                lateController.active = YES;

                [lateController.searchBar
                    becomeFirstResponder];
            }
        });
    });
}


#pragma mark - Search Glass Control

@interface SGSSearchControl : UIControl

@property(nonatomic,strong)
UIVisualEffectView *backdropView;

@property(nonatomic,strong)
UIView *reflectionView;

@property(nonatomic,strong)
UIImageView *searchIcon;

@property(nonatomic,strong)
UILabel *searchLabel;

@property(nonatomic,strong)
UIImageView *micIcon;

@property(nonatomic,strong)
CAGradientLayer *topReflection;

@property(nonatomic,strong)
CAGradientLayer *edgeGradient;

@end


@implementation SGSSearchControl


#pragma mark Initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    self =
        [super initWithFrame:frame];

    if (self)
    {
        self.backgroundColor =
            UIColor.clearColor;

        self.clipsToBounds =
            YES;

        self.layer.masksToBounds =
            YES;

        self.layer.cornerRadius =
            sgsRadius;


        #pragma mark - Glass Backdrop

        UIBlurEffect *blurEffect =
            [UIBlurEffect
                effectWithStyle:
                UIBlurEffectStyleSystemChromeMaterial];

        self.backdropView =
            [[UIVisualEffectView alloc]
                initWithEffect:blurEffect];

        self.backdropView.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.backdropView.alpha =
            1.0;

        [self addSubview:
            self.backdropView];


        #pragma mark - Reflection View

        self.reflectionView =
            [[UIView alloc] init];

        self.reflectionView.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.reflectionView.backgroundColor =
            UIColor.clearColor;

        self.reflectionView.userInteractionEnabled =
            NO;

        [self addSubview:
            self.reflectionView];


        #pragma mark - Top Reflection

        self.topReflection =
            [CAGradientLayer layer];

        self.topReflection.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.30].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.08].CGColor,

            (id)[UIColor clearColor].CGColor
        ];

        self.topReflection.locations = @[
            @0.0,
            @0.25,
            @0.75
        ];

        self.topReflection.startPoint =
            CGPointMake(0.5, 0.0);

        self.topReflection.endPoint =
            CGPointMake(0.5, 1.0);

        [self.reflectionView.layer
            addSublayer:self.topReflection];


        #pragma mark - Search Icon

        UIImageSymbolConfiguration *searchConfiguration =
            [UIImageSymbolConfiguration
                configurationWithPointSize:22.0
                weight:UIImageSymbolWeightRegular];

        UIImage *searchImage =
            [UIImage
                systemImageNamed:
                    @"magnifyingglass"
                withConfiguration:
                    searchConfiguration];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:searchImage];

        self.searchIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchIcon.tintColor =
            UIColor.labelColor;

        self.searchIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        self.searchIcon.userInteractionEnabled =
            NO;

        [self addSubview:
            self.searchIcon];


        #pragma mark - Search Label

        self.searchLabel =
            [[UILabel alloc] init];

        self.searchLabel.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchLabel.text =
            @"Search";

        self.searchLabel.textColor =
            [[UIColor labelColor]
                colorWithAlphaComponent:0.58];

        /*
         * Fonte menor.
         */

        self.searchLabel.font =
            [UIFont
                systemFontOfSize:20.0
                weight:UIFontWeightRegular];

        self.searchLabel.userInteractionEnabled =
            NO;

        [self addSubview:
            self.searchLabel];


        #pragma mark - Microphone

        UIImageSymbolConfiguration *micConfiguration =
            [UIImageSymbolConfiguration
                configurationWithPointSize:21.0
                weight:UIImageSymbolWeightMedium];

        UIImage *micImage =
            [UIImage
                systemImageNamed:@"mic"
                withConfiguration:
                    micConfiguration];

        self.micIcon =
            [[UIImageView alloc]
                initWithImage:micImage];

        self.micIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.micIcon.tintColor =
            UIColor.labelColor;

        self.micIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        self.micIcon.userInteractionEnabled =
            NO;

        [self addSubview:
            self.micIcon];


        #pragma mark - Constraints

        [NSLayoutConstraint activateConstraints:@[

            /*
             * Backdrop
             */

            [self.backdropView.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [self.backdropView.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [self.backdropView.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [self.backdropView.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor],


            /*
             * Reflection
             */

            [self.reflectionView.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [self.reflectionView.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [self.reflectionView.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [self.reflectionView.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor],


            /*
             * Search icon
             */

            [self.searchIcon.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor
                    constant:16.0],

            [self.searchIcon.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.searchIcon.widthAnchor
                constraintEqualToConstant:25.0],

            [self.searchIcon.heightAnchor
                constraintEqualToConstant:25.0],


            /*
             * Search label
             */

            [self.searchLabel.leadingAnchor
                constraintEqualToAnchor:
                    self.searchIcon.trailingAnchor
                    constant:12.0],

            [self.searchLabel.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.searchLabel.trailingAnchor
                constraintLessThanOrEqualToAnchor:
                    self.micIcon.leadingAnchor
                    constant:-10.0],


            /*
             * Microphone
             */

            [self.micIcon.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor
                    constant:-16.0],

            [self.micIcon.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.micIcon.widthAnchor
                constraintEqualToConstant:25.0],

            [self.micIcon.heightAnchor
                constraintEqualToConstant:25.0]
        ]];


        #pragma mark - Glass Border

        self.layer.borderWidth =
            0.7;

        self.layer.borderColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:0.48].CGColor;


        #pragma mark - Edge Reflection

        self.edgeGradient =
            [CAGradientLayer layer];

        self.edgeGradient.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.62].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.10].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.42].CGColor
        ];

        self.edgeGradient.locations = @[
            @0.0,
            @0.50,
            @1.0
        ];

        self.edgeGradient.startPoint =
            CGPointMake(0.0, 0.0);

        self.edgeGradient.endPoint =
            CGPointMake(1.0, 0.0);

        /*
         * Máscara para deixar o brilho
         * somente na borda.
         */

        CAShapeLayer *borderMask =
            [CAShapeLayer layer];

        self.edgeGradient.mask =
            borderMask;

        [self.layer
            addSublayer:self.edgeGradient];
    }

    return self;
}


#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layer.cornerRadius =
        sgsRadius;

    self.topReflection.frame =
        self.bounds;

    self.edgeGradient.frame =
        self.bounds;


    /*
     * Máscara da borda.
     */

    CAShapeLayer *mask =
        (CAShapeLayer *)self.edgeGradient.mask;

    CGRect outerRect =
        self.bounds;

    CGRect innerRect =
        CGRectInset(
            self.bounds,
            0.8,
            0.8
        );

    UIBezierPath *outerPath =
        [UIBezierPath
            bezierPathWithRoundedRect:
                outerRect
            cornerRadius:
                sgsRadius];

    UIBezierPath *innerPath =
        [UIBezierPath
            bezierPathWithRoundedRect:
                innerRect
            cornerRadius:
                MAX(sgsRadius - 0.8, 0)];

    [outerPath appendPath:
        [innerPath
            bezierPathByReversingPath]];

    mask.path =
        outerPath.CGPath;
}


#pragma mark - Touch Down

- (BOOL)beginTrackingWithTouch:(UITouch *)touch
                      withEvent:(UIEvent *)event
{
    BOOL result =
        [super beginTrackingWithTouch:
            touch
            withEvent:event];

    [UIView animateWithDuration:0.08
                     animations:^{

        self.transform =
            CGAffineTransformMakeScale(
                0.975,
                0.975
            );

        self.alpha =
            0.72;
    }];

    return result;
}


#pragma mark - Touch Up

- (void)endTrackingWithTouch:(UITouch *)touch
                    withEvent:(UIEvent *)event
{
    [super endTrackingWithTouch:
        touch
        withEvent:event];

    [UIView animateWithDuration:0.15
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha =
            1.0;
    }];


    /*
     * Abre a pesquisa nativa.
     */

    SGSOpenNativeSearch();
}


#pragma mark - Touch Cancel

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];

    [UIView animateWithDuration:0.15
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha =
            1.0;
    }];
}

@end


#pragma mark - Remove

static void SGSRemoveSearchBar(void)
{
    if (sgsContainer)
    {
        [sgsContainer removeFromSuperview];

        sgsContainer = nil;
    }
}


#pragma mark - Create Search Bar

static void SGSCreateSearchBar(void)
{
    SGSLoadPreferences();

    if (!sgsEnabled)
        return;

    if (sgsContainer &&
        sgsContainer.superview)
        return;


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
     * Controle
     */

    SGSSearchControl *control =
        [[SGSSearchControl alloc]
            initWithFrame:CGRectZero];

    control.translatesAutoresizingMaskIntoConstraints =
        NO;

    [sgsContainer addSubview:
        control];

    [window addSubview:
        sgsContainer];


    #pragma mark - Position

    /*
     * Barra menor.
     */

    [NSLayoutConstraint activateConstraints:@[

        /*
         * Container
         */

        [sgsContainer.leadingAnchor
            constraintEqualToAnchor:
                window.leadingAnchor
                constant:24.0],

        [sgsContainer.trailingAnchor
            constraintEqualToAnchor:
                window.trailingAnchor
                constant:-24.0],

        [sgsContainer.bottomAnchor
            constraintEqualToAnchor:
                window.safeAreaLayoutGuide.bottomAnchor
                constant:-8.0],

        [sgsContainer.heightAnchor
            constraintEqualToConstant:48.0],


        /*
         * Controle
         */

        [control.leadingAnchor
            constraintEqualToAnchor:
                sgsContainer.leadingAnchor],

        [control.trailingAnchor
            constraintEqualToAnchor:
                sgsContainer.trailingAnchor],

        [control.topAnchor
            constraintEqualToAnchor:
                sgsContainer.topAnchor],

        [control.bottomAnchor
            constraintEqualToAnchor:
                sgsContainer.bottomAnchor]
    ]];
}


#pragma mark - Refresh

static void SGSRefresh(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        SGSRemoveSearchBar();

        SGSLoadPreferences();

        if (sgsEnabled)
            SGSCreateSearchBar();
    });
}


#pragma mark - Preferences Notification

static void SGSPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo)
{
    SGSRefresh();
}


#pragma mark - UIViewController Hook

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"])
        return;


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.25 *
                      NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        SGSCreateSearchBar();
    });
}

%end


#pragma mark - UIApplication Hook

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application
{
    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"])
        return;


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.30 *
                      NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        SGSCreateSearchBar();
    });
}

%end


#pragma mark - Constructor

%ctor
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    /*
     * Carrega somente no Ajustes.
     */

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"])
        return;


    /*
     * Preferences
     */

    SGSLoadPreferences();


    /*
     * Notification do Preference Bundle.
     */

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


    /*
     * Criação inicial.
     */

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.50 *
                          NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

            SGSCreateSearchBar();
        });
    });
}
