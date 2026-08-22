#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const SGSPreferencesID =
    @"com.samuel.settingsglasssearch";

static UIView *sgsContainer = nil;

static BOOL sgsEnabled = YES;
static CGFloat sgsOpacity = 1.0;
static CGFloat sgsBlur = 14.0;
static CGFloat sgsRadius = 22.0;


#pragma mark - Preferences

static void SGSLoadPreferences(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SGSPreferencesID];

    if (defaults)
    {
        if ([defaults objectForKey:@"enabled"])
            sgsEnabled = [defaults boolForKey:@"enabled"];

        if ([defaults objectForKey:@"blur"])
            sgsBlur = [defaults doubleForKey:@"blur"];

        if ([defaults objectForKey:@"radius"])
            sgsRadius = [defaults doubleForKey:@"radius"];
    }

    sgsBlur = MIN(MAX(sgsBlur, 1.0), 40.0);
    sgsRadius = MIN(MAX(sgsRadius, 10.0), 35.0);
}


#pragma mark - Settings Window

static UIWindow *SGSGetSettingsWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    UIWindow *bestWindow = nil;

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

            bestWindow = window;
        }
    }

    return bestWindow;
}


#pragma mark - Recursive Search

static UISearchBar *SGSFindSearchBar(UIView *view)
{
    if (!view)
        return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview in view.subviews)
    {
        UISearchBar *bar =
            SGSFindSearchBar(subview);

        if (bar)
            return bar;
    }

    return nil;
}


static UISearchController *
SGSFindSearchController(UIViewController *controller)
{
    if (!controller)
        return nil;

    if (controller.navigationItem.searchController)
        return controller.navigationItem.searchController;

    for (UIViewController *child
         in controller.childViewControllers)
    {
        UISearchController *result =
            SGSFindSearchController(child);

        if (result)
            return result;
    }

    if ([controller isKindOfClass:
        [UINavigationController class]])
    {
        UINavigationController *nav =
            (UINavigationController *)controller;

        return SGSFindSearchController(
            nav.visibleViewController
        );
    }

    if ([controller isKindOfClass:
        [UISplitViewController class]])
    {
        UISplitViewController *split =
            (UISplitViewController *)controller;

        for (UIViewController *vc
             in split.viewControllers)
        {
            UISearchController *result =
                SGSFindSearchController(vc);

            if (result)
                return result;
        }
    }

    return nil;
}


#pragma mark - Find "Search" UI

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
     * UILabel contendo "Search"
     */

    if ([view isKindOfClass:[UILabel class]])
    {
        UILabel *label = (UILabel *)view;

        NSString *text = label.text;

        if (text.length &&
            [text localizedCaseInsensitiveCompare:@"Search"] == NSOrderedSame)
        {
            return view.superview;
        }
    }


    /*
     * UIButton contendo "Search"
     */

    if ([view isKindOfClass:[UIButton class]])
    {
        UIButton *button = (UIButton *)view;

        NSString *title =
            [button titleForState:UIControlStateNormal];

        if (title.length &&
            [title localizedCaseInsensitiveCompare:@"Search"] == NSOrderedSame)
        {
            return button;
        }
    }


    for (UIView *subview in view.subviews)
    {
        UIView *result =
            SGSFindSearchElement(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Open Settings Search

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
         * 1. Se já existe uma UISearchBar,
         *    simplesmente ativa.
         */

        UISearchBar *bar =
            SGSFindSearchBar(window);

        if (bar)
        {
            [bar setHidden:NO];
            [bar becomeFirstResponder];
            return;
        }


        /*
         * 2. Procura UISearchController.
         */

        UISearchController *controller =
            SGSFindSearchController(root);

        if (controller)
        {
            controller.active = YES;

            [controller.searchBar
                becomeFirstResponder];

            return;
        }


        /*
         * 3. Procura o botão/célula "Search"
         *    existente no Ajustes.
         */

        UIView *searchElement =
            SGSFindSearchElement(window);

        if (searchElement)
        {
            if ([searchElement
                 isKindOfClass:[UIButton class]])
            {
                UIButton *button =
                    (UIButton *)searchElement;

                [button sendActionsForControlEvents:
                    UIControlEventPrimaryActionTriggered];

                return;
            }

            /*
             * Tenta encontrar um UIButton
             * dentro do elemento.
             */

            for (UIView *subview
                 in searchElement.subviews)
            {
                if ([subview
                     isKindOfClass:[UIButton class]])
                {
                    UIButton *button =
                        (UIButton *)subview;

                    [button sendActionsForControlEvents:
                        UIControlEventPrimaryActionTriggered];

                    return;
                }
            }
        }


        /*
         * 4. Dá tempo para o Ajustes
         *    terminar de montar sua interface.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                0.25 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{

            UISearchBar *lateBar =
                SGSFindSearchBar(window);

            if (lateBar)
            {
                [lateBar becomeFirstResponder];
                return;
            }

            UISearchController *lateController =
                SGSFindSearchController(
                    window.rootViewController
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


#pragma mark - Pixel Glass Search Control

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
CAGradientLayer *edgeGradient;

@property(nonatomic,strong)
CAGradientLayer *topReflection;

@property(nonatomic,strong)
CAReplicatorLayer *pixelLayer;

@end


@implementation SGSSearchControl


- (instancetype)initWithFrame:(CGRect)frame
{
    self =
        [super initWithFrame:frame];

    if (self)
    {
        self.backgroundColor =
            UIColor.clearColor;

        self.clipsToBounds = YES;

        self.layer.cornerRadius =
            sgsRadius;

        self.layer.masksToBounds = YES;


        #pragma mark Backdrop

        UIBlurEffect *blurEffect =
            [UIBlurEffect
                effectWithStyle:
                UIBlurEffectStyleSystemChromeMaterial];

        self.backdropView =
            [[UIVisualEffectView alloc]
                initWithEffect:blurEffect];

        self.backdropView.translatesAutoresizingMaskIntoConstraints =
            NO;

        /*
         * O conteúdo atrás continua sendo
         * atualizado pelo sistema.
         */

        self.backdropView.alpha = 1.0;

        [self addSubview:
            self.backdropView];


        #pragma mark Reflection

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


        /*
         * Reflexo superior
         */

        self.topReflection =
            [CAGradientLayer layer];

        self.topReflection.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.34].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.08].CGColor,

            (id)[UIColor clearColor].CGColor
        ];

        self.topReflection.locations = @[
            @0.0,
            @0.28,
            @0.75
        ];

        self.topReflection.startPoint =
            CGPointMake(0.5, 0.0);

        self.topReflection.endPoint =
            CGPointMake(0.5, 1.0);

        [self.reflectionView.layer
            addSublayer:self.topReflection];


        #pragma mark Pixel Grid

        /*
         * Pequenos pixels transparentes.
         * Eles dão o aspecto pixel-glass sem
         * substituir o backdrop vivo.
         */

        self.pixelLayer =
            [CAReplicatorLayer layer];

        CALayer *pixel =
            [CALayer layer];

        pixel.frame =
            CGRectMake(0, 0, 2.0, 2.0);

        pixel.backgroundColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:0.045].CGColor;

        pixel.cornerRadius = 0.5;

        self.pixelLayer.instanceCount = 60;

        self.pixelLayer.instanceTransform =
            CATransform3DMakeTranslation(
                4.0,
                0,
                0
            );

        self.pixelLayer.instanceDelay = 0.0;

        [self.pixelLayer addSublayer:pixel];

        [self.layer addSublayer:
            self.pixelLayer];


        #pragma mark Search Icon

        UIImageSymbolConfiguration *searchConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:24.0
                weight:UIImageSymbolWeightRegular];

        UIImage *searchImage =
            [UIImage
                systemImageNamed:
                    @"magnifyingglass"
                withConfiguration:
                    searchConfig];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:searchImage];

        self.searchIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchIcon.tintColor =
            UIColor.labelColor;

        self.searchIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        [self addSubview:
            self.searchIcon];


        #pragma mark Search Label

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
                systemFontOfSize:21.0
                weight:UIFontWeightRegular];

        [self addSubview:
            self.searchLabel];


        #pragma mark Microphone

        UIImageSymbolConfiguration *micConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:22.0
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

        [self addSubview:
            self.micIcon];


        #pragma mark Constraints

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
                    constant:17.0],

            [self.searchIcon.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.searchIcon.widthAnchor
                constraintEqualToConstant:27.0],

            [self.searchIcon.heightAnchor
                constraintEqualToConstant:27.0],


            /*
             * Label
             */

            [self.searchLabel.leadingAnchor
                constraintEqualToAnchor:
                    self.searchIcon.trailingAnchor
                    constant:13.0],

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
                    constant:-17.0],

            [self.micIcon.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.micIcon.widthAnchor
                constraintEqualToConstant:27.0],

            [self.micIcon.heightAnchor
                constraintEqualToConstant:27.0]

        ]];


        #pragma mark Border

        /*
         * Borda muito fina, tipo vidro.
         */

        self.layer.borderWidth =
            0.75;

        self.layer.borderColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:0.52].CGColor;


        #pragma mark Edge Reflection

        self.edgeGradient =
            [CAGradientLayer layer];

        self.edgeGradient.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.60].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.04].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.45].CGColor
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

        self.edgeGradient.mask =
            [CAShapeLayer layer];

        [self.layer addSublayer:
            self.edgeGradient];
    }

    return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layer.cornerRadius =
        sgsRadius;

    self.topReflection.frame =
        self.bounds;

    self.edgeGradient.frame =
        self.bounds;

    CAShapeLayer *mask =
        (CAShapeLayer *)self.edgeGradient.mask;

    UIBezierPath *outer =
        [UIBezierPath
            bezierPathWithRoundedRect:
                self.bounds
            cornerRadius:
                sgsRadius];

    UIBezierPath *inner =
        [UIBezierPath
            bezierPathWithRoundedRect:
                CGRectInset(self.bounds, 0.8, 0.8)
            cornerRadius:
                MAX(sgsRadius - 0.8, 0)];

    [outer appendPath:
        [inner
            bezierPathByReversingPath]];

    mask.path =
        outer.CGPath;

    /*
     * Pixel pattern cobre toda a barra.
     */

    self.pixelLayer.frame =
        self.bounds;
}


#pragma mark Touch

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
                0.97,
                0.97
            );

        self.alpha = 0.72;
    }];

    return result;
}


- (void)endTrackingWithTouch:(UITouch *)touch
                    withEvent:(UIEvent *)event
{
    [super endTrackingWithTouch:
        touch
        withEvent:event];

    [UIView animateWithDuration:0.16
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];

    SGSOpenNativeSearch();
}


- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];

    [UIView animateWithDuration:0.16
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];
}

@end


#pragma mark - Create

static void SGSRemoveSearchBar(void)
{
    if (sgsContainer)
    {
        [sgsContainer removeFromSuperview];
        sgsContainer = nil;
    }
}


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
     * Barra
     */

    SGSSearchControl *control =
        [[SGSSearchControl alloc] init];

    control.translatesAutoresizingMaskIntoConstraints =
        NO;

    [sgsContainer addSubview:
        control];

    [window addSubview:
        sgsContainer];


    /*
     * Tamanho reduzido
     */

    [NSLayoutConstraint activateConstraints:@[

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


#pragma mark - UIViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:
            @"com.apple.Preferences"])
        return;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.25 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{

        SGSCreateSearchBar();
    });
}

%end


#pragma mark - UIApplication

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application
{
    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:
            @"com.apple.Preferences"])
        return;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.30 * NSEC_PER_SEC
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

    if (![bundleIdentifier
          isEqualToString:
            @"com.apple.Preferences"])
        return;

    SGSLoadPreferences();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)^(CFNotificationCenterRef center,
                                  void *observer,
                                  CFStringRef name,
                                  const void *object,
                                  CFDictionaryRef userInfo)
        {
            SGSRefresh();
        },
        CFSTR(
            "com.samuel.settingsglasssearch/preferencesChanged"
        ),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                0.50 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{

            SGSCreateSearchBar();
        });
    });
}
