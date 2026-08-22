#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*
 * SettingsGlassSearch
 * iOS 16 / Rootless
 *
 * Barra de pesquisa estilo Apple:
 *
 * ┌─────────────────────────────────────────────┐
 * │  🔍   Search                            🎙   │
 * └─────────────────────────────────────────────┘
 *
 * Ao tocar:
 * -> abre/ativa a pesquisa nativa do Ajustes.
 */

#pragma mark - Configuração

static NSString * const SGSPreferencesID =
    @"com.samuel.settingsglasssearch";

static UIView *sgsContainer = nil;
static UIVisualEffectView *sgsBlurView = nil;
static UILabel *sgsSearchLabel = nil;
static UIImageView *sgsSearchIcon = nil;
static UIImageView *sgsMicIcon = nil;

static CAGradientLayer *sgsTopReflection = nil;
static CAGradientLayer *sgsBorderGradient = nil;

static BOOL sgsEnabled = YES;
static CGFloat sgsOpacity = 0.72;
static CGFloat sgsBlur = 18.0;
static CGFloat sgsRadius = 28.0;


#pragma mark - Preferências

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

    /*
     * Segurança contra valores inválidos.
     */

    if (sgsOpacity < 0.1)
        sgsOpacity = 0.1;

    if (sgsOpacity > 1.0)
        sgsOpacity = 1.0;

    if (sgsBlur < 1.0)
        sgsBlur = 1.0;

    if (sgsBlur > 50.0)
        sgsBlur = 50.0;

    if (sgsRadius < 8.0)
        sgsRadius = 8.0;

    if (sgsRadius > 50.0)
        sgsRadius = 50.0;
}


#pragma mark - Procurar UIViewController

static UIViewController *SGSVisibleViewController(UIViewController *controller) {

    if (!controller)
        return nil;

    /*
     * View controller apresentado.
     */

    if (controller.presentedViewController)
        return SGSVisibleViewController(controller.presentedViewController);

    /*
     * Navigation Controller.
     */

    if ([controller isKindOfClass:[UINavigationController class]]) {

        UINavigationController *navigationController =
            (UINavigationController *)controller;

        return SGSVisibleViewController(
            navigationController.visibleViewController
        );
    }

    /*
     * Tab Bar Controller.
     */

    if ([controller isKindOfClass:[UITabBarController class]]) {

        UITabBarController *tabBarController =
            (UITabBarController *)controller;

        return SGSVisibleViewController(
            tabBarController.selectedViewController
        );
    }

    /*
     * Split View.
     */

    if ([controller isKindOfClass:[UISplitViewController class]]) {

        UISplitViewController *split =
            (UISplitViewController *)controller;

        UIViewController *last =
            split.viewControllers.lastObject;

        if (last)
            return SGSVisibleViewController(last);
    }

    /*
     * Child View Controllers.
     */

    for (UIViewController *child in controller.childViewControllers) {

        if (child.viewIfLoaded.window) {

            UIViewController *result =
                SGSVisibleViewController(child);

            if (result)
                return result;
        }
    }

    return controller;
}


static UIWindow *SGSGetSettingsWindow(void) {

    UIApplication *application =
        [UIApplication sharedApplication];

    UIWindow *result = nil;

    /*
     * iOS 13+
     */

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }

        for (UIWindow *window in windowScene.windows) {

            if (!window.hidden &&
                window.windowLevel == UIWindowLevelNormal &&
                window.rootViewController) {

                result = window;

                if (window.isKeyWindow)
                    return window;
            }
        }
    }

    return result;
}


#pragma mark - Procurar UISearchBar

static UISearchBar *SGSFindSearchBar(UIView *view) {

    if (!view)
        return nil;

    /*
     * Achou diretamente.
     */

    if ([view isKindOfClass:[UISearchBar class]])
        return (UISearchBar *)view;

    /*
     * Procura nos filhos.
     */

    for (UIView *subview in view.subviews) {

        UISearchBar *result =
            SGSFindSearchBar(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Procurar Search Controller

static UISearchController *
SGSFindSearchController(UIViewController *controller) {

    if (!controller)
        return nil;

    /*
     * UINavigationController
     */

    if ([controller isKindOfClass:[UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)controller;

        UIViewController *visible =
            navigation.visibleViewController;

        UISearchController *result =
            SGSFindSearchController(visible);

        if (result)
            return result;

        /*
         * Procura no navigationItem.
         */

        if (visible.navigationItem.searchController)
            return visible.navigationItem.searchController;
    }

    /*
     * Procura no próprio navigationItem.
     */

    if (controller.navigationItem.searchController)
        return controller.navigationItem.searchController;

    /*
     * Procura nos filhos.
     */

    for (UIViewController *child in controller.childViewControllers) {

        UISearchController *result =
            SGSFindSearchController(child);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Abrir pesquisa nativa

static void SGSOpenNativeSearch(void) {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window =
            SGSGetSettingsWindow();

        if (!window)
            return;

        UIViewController *root =
            window.rootViewController;

        if (!root)
            return;

        /*
         * Primeiro procura uma UISearchBar que já esteja
         * na tela.
         */

        UISearchBar *existingSearchBar =
            SGSFindSearchBar(window);

        if (existingSearchBar) {

            [existingSearchBar becomeFirstResponder];

            [existingSearchBar setShowsCancelButton:YES
                                            animated:YES];

            return;
        }

        /*
         * Procura UISearchController.
         */

        UISearchController *searchController =
            SGSFindSearchController(root);

        if (searchController) {

            searchController.active = YES;

            [searchController.searchBar becomeFirstResponder];

            return;
        }

        /*
         * Caso o Settings esteja em uma NavigationController,
         * volta para a primeira página.
         */

        UINavigationController *navigation = nil;

        if ([root isKindOfClass:
             [UINavigationController class]]) {

            navigation =
                (UINavigationController *)root;
        }

        /*
         * iPad / SplitView.
         */

        if (!navigation &&
            [root isKindOfClass:
             [UISplitViewController class]]) {

            UISplitViewController *split =
                (UISplitViewController *)root;

            for (UIViewController *vc
                 in split.viewControllers) {

                if ([vc isKindOfClass:
                    [UINavigationController class]]) {

                    navigation =
                        (UINavigationController *)vc;

                    break;
                }
            }
        }

        if (navigation) {

            [navigation popToRootViewControllerAnimated:NO];

            /*
             * Espera a tela principal do Ajustes aparecer.
             */

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    0.25 * NSEC_PER_SEC
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
                        SGSFindSearchBar(navigation.view);

                    if (bar) {

                        [bar becomeFirstResponder];

                        return;
                    }
                }
            );
        }
    });
}


#pragma mark - Classe da barra

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
            [UIColor clearColor];

        self.clipsToBounds = YES;

        /*
         * Formato de cápsula.
         */

        self.layer.cornerRadius =
            sgsRadius;

        self.layer.masksToBounds = YES;


        #pragma mark Blur

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
            sgsBlur / 20.0;

        [self addSubview:self.blurView];


        #pragma mark Glass Tint

        self.glassTint =
            [[UIView alloc] init];

        self.glassTint.translatesAutoresizingMaskIntoConstraints =
            NO;

        /*
         * O branco extremamente suave dá o aspecto
         * de vidro da imagem.
         */

        self.glassTint.backgroundColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:
                sgsOpacity * 0.35];

        [self addSubview:self.glassTint];


        #pragma mark Ícone da lupa

        UIImageSymbolConfiguration *searchConfiguration =
            [UIImageSymbolConfiguration
                configurationWithPointSize:31.0
                weight:UIImageSymbolWeightRegular];

        UIImage *searchImage =
            [UIImage
                systemImageNamed:@"magnifyingglass"
                withConfiguration:
                searchConfiguration];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:searchImage];

        self.searchIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchIcon.tintColor =
            [UIColor labelColor];

        self.searchIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        [self addSubview:self.searchIcon];


        #pragma mark Texto Search

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
            [UIFont systemFontOfSize:29.0
                              weight:UIFontWeightRegular];

        self.searchLabel.adjustsFontSizeToFitWidth =
            YES;

        [self addSubview:self.searchLabel];


        #pragma mark Microfone

        UIImageSymbolConfiguration *micConfiguration =
            [UIImageSymbolConfiguration
                configurationWithPointSize:29.0
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
            [UIColor labelColor];

        self.micIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        [self addSubview:self.micIcon];


        #pragma mark Constraints

        [NSLayoutConstraint activateConstraints:@[

            /*
             * Blur
             */

            [self.blurView.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor],

            [self.blurView.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],

            [self.blurView.topAnchor
                constraintEqualToAnchor:self.topAnchor],

            [self.blurView.bottomAnchor
                constraintEqualToAnchor:self.bottomAnchor],


            /*
             * Tint
             */

            [self.glassTint.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor],

            [self.glassTint.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],

            [self.glassTint.topAnchor
                constraintEqualToAnchor:self.topAnchor],

            [self.glassTint.bottomAnchor
                constraintEqualToAnchor:self.bottomAnchor],


            /*
             * Lupa
             */

            [self.searchIcon.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor
                constant:26.0],

            [self.searchIcon.centerYAnchor
                constraintEqualToAnchor:self.centerYAnchor],

            [self.searchIcon.widthAnchor
                constraintEqualToConstant:34.0],

            [self.searchIcon.heightAnchor
                constraintEqualToConstant:34.0],


            /*
             * Search
             */

            [self.searchLabel.leadingAnchor
                constraintEqualToAnchor:
                self.searchIcon.trailingAnchor
                constant:20.0],

            [self.searchLabel.centerYAnchor
                constraintEqualToAnchor:self.centerYAnchor],

            [self.searchLabel.trailingAnchor
                constraintLessThanOrEqualToAnchor:
                self.micIcon.leadingAnchor
                constant:-15.0],


            /*
             * Microfone
             */

            [self.micIcon.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor
                constant:-26.0],

            [self.micIcon.centerYAnchor
                constraintEqualToAnchor:self.centerYAnchor],

            [self.micIcon.widthAnchor
                constraintEqualToConstant:34.0],

            [self.micIcon.heightAnchor
                constraintEqualToConstant:34.0]
        ]];


        #pragma mark Reflexo superior

        self.reflectionLayer =
            [CAGradientLayer layer];

        self.reflectionLayer.colors = @[

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.38].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.08].CGColor,

            (id)[[UIColor clearColor]
                colorWithAlphaComponent:0.0].CGColor
        ];

        self.reflectionLayer.startPoint =
            CGPointMake(0.5, 0.0);

        self.reflectionLayer.endPoint =
            CGPointMake(0.5, 0.65);

        [self.layer addSublayer:self.reflectionLayer];


        #pragma mark Borda

        self.layer.borderWidth = 0.7;

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


#pragma mark Toque

- (void)beginTrackingWithTouch:(UITouch *)touch
                     withEvent:(UIEvent *)event {

    [super beginTracking:touch
               withEvent:event];

    [UIView animateWithDuration:0.10
                     animations:^{

        self.transform =
            CGAffineTransformMakeScale(0.985, 0.985);

        self.alpha = 0.72;
    }];
}


- (void)endTrackingWithTouch:(UITouch *)touch
                   withEvent:(UIEvent *)event {

    [super endTracking:touch
             withEvent:event];

    [UIView animateWithDuration:0.15
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;

        self.alpha = 1.0;
    }];

    /*
     * Abre a pesquisa.
     */

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


#pragma mark - Criar barra

static void SGSRemoveSearchBar(void) {

    if (sgsContainer) {

        [sgsContainer removeFromSuperview];

        sgsContainer = nil;
    }
}


static void SGSCreateSearchBar(void) {

    /*
     * Preferências.
     */

    SGSLoadPreferences();

    if (!sgsEnabled)
        return;

    /*
     * Não criar duplicada.
     */

    if (sgsContainer &&
        sgsContainer.superview) {

        return;
    }

    UIWindow *window =
        SGSGetSettingsWindow();

    if (!window)
        return;


    /*
     * Container.
     */

    sgsContainer =
        [[UIView alloc] init];

    sgsContainer.translatesAutoresizingMaskIntoConstraints =
        NO;

    sgsContainer.backgroundColor =
        [UIColor clearColor];

    sgsContainer.layer.cornerRadius =
        sgsRadius;

    sgsContainer.layer.masksToBounds =
        YES;


    /*
     * Barra.
     */

    SGSSearchControl *searchControl =
        [[SGSSearchControl alloc] init];

    searchControl.translatesAutoresizingMaskIntoConstraints =
        NO;


    /*
     * Guarda referência.
     */

    [sgsContainer addSubview:searchControl];

    [window addSubview:sgsContainer];


    /*
     * Posicionamento.
     *
     * 16 px dos lados
     * 12 px acima do Safe Area inferior
     * 56 px de altura
     */

    [NSLayoutConstraint activateConstraints:@[

        /*
         * Container
         */

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
         * Search Control
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


#pragma mark - Atualização

static void SGSRefresh(void) {

    dispatch_async(dispatch_get_main_queue(), ^{

        SGSRemoveSearchBar();

        SGSLoadPreferences();

        if (sgsEnabled)
            SGSCreateSearchBar();
    });
}


#pragma mark - Settings ViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {

    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    /*
     * Só funciona dentro do Ajustes.
     */

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"]) {

        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.30 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(), ^{

            SGSCreateSearchBar();
        }
    );
}

%end


#pragma mark - UIApplication

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application {

    %orig;

    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"]) {

        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            0.35 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(), ^{

            SGSCreateSearchBar();
        }
    );
}

%end


#pragma mark - Preference Notification

static void SGSPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo) {

    dispatch_async(
        dispatch_get_main_queue(), ^{

            SGSRefresh();
        }
    );
}


#pragma mark - Constructor

%ctor {

    /*
     * Só injeta no Settings.
     */

    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    if (![bundleIdentifier
          isEqualToString:@"com.apple.Preferences"]) {

        return;
    }


    /*
     * Carrega configurações.
     */

    SGSLoadPreferences();


    /*
     * Observa mudanças no PreferenceLoader.
     */

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SGSPreferencesChanged,
        CFSTR("com.samuel.settingsglasssearch/preferencesChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );


    /*
     * Cria a barra quando o Settings estiver pronto.
     */

    dispatch_async(
        dispatch_get_main_queue(), ^{

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    0.5 * NSEC_PER_SEC
                ),
                dispatch_get_main_queue(), ^{

                    SGSCreateSearchBar();
                }
            );
        }
    );
}  
