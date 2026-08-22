#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>

#pragma mark - SearchGlass

static NSString * const SGSPreferencesID =
    @"com.samuel.settingsglasssearch";

static NSString * const SGSPreferencesNotification =
    @"com.samuel.settingsglasssearch/preferencesChanged";

static UIView *sgsContainer = nil;
static NSTimer *sgsGlassTimer = nil;

static BOOL sgsEnabled = YES;
static CGFloat sgsRadius = 22.0;

static CIContext *sgsCIContext = nil;


#pragma mark - Preferences

static void SGSLoadPreferences(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SGSPreferencesID];

    if (!defaults)
        return;

    if ([defaults objectForKey:@"enabled"])
        sgsEnabled = [defaults boolForKey:@"enabled"];

    if ([defaults objectForKey:@"radius"])
        sgsRadius = [defaults doubleForKey:@"radius"];

    sgsRadius =
        MIN(MAX(sgsRadius, 12.0), 30.0);
}


#pragma mark - Settings Window

static UIWindow *SGSGetSettingsWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    UIWindow *fallback = nil;

    for (UIScene *scene
         in application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
              [UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
            continue;

        for (UIWindow *window
             in windowScene.windows)
        {
            if (window.hidden)
                continue;

            if (!window.rootViewController)
                continue;

            if (window.isKeyWindow)
                return window;

            fallback = window;
        }
    }

    return fallback;
}


#pragma mark - Find Search Bar

static UISearchBar *
SGSFindSearchBar(UIView *view)
{
    if (!view)
        return nil;

    if ([view
         isKindOfClass:
         [UISearchBar class]])
        return (UISearchBar *)view;

    for (UIView *subview
         in view.subviews)
    {
        UISearchBar *result =
            SGSFindSearchBar(subview);

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - Find Search Controller

static UISearchController *
SGSFindSearchController(
    UIViewController *controller)
{
    if (!controller)
        return nil;

    if (controller.navigationItem.searchController)
        return controller.navigationItem.searchController;

    if ([controller
         isKindOfClass:
         [UINavigationController class]])
    {
        UINavigationController *nav =
            (UINavigationController *)controller;

        UISearchController *result =
            SGSFindSearchController(
                nav.visibleViewController
            );

        if (result)
            return result;
    }

    if ([controller
         isKindOfClass:
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


#pragma mark - Find Search Element

static UIView *
SGSFindSearchElement(UIView *view)
{
    if (!view)
        return nil;

    if ([view
         isKindOfClass:
         [UISearchBar class]])
        return view;

    if ([view
         isKindOfClass:
         [UILabel class]])
    {
        UILabel *label =
            (UILabel *)view;

        if (label.text.length &&
            [label.text
             localizedCaseInsensitiveCompare:@"Search"]
             == NSOrderedSame)
        {
            return label.superview;
        }
    }

    if ([view
         isKindOfClass:
         [UIButton class]])
    {
        UIButton *button =
            (UIButton *)view;

        NSString *title =
            [button
             titleForState:
             UIControlStateNormal];

        if (title.length &&
            [title
             localizedCaseInsensitiveCompare:@"Search"]
             == NSOrderedSame)
        {
            return button;
        }
    }

    for (UIView *subview
         in view.subviews)
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
             * 1. Search bar já existente.
             */

            UISearchBar *bar =
                SGSFindSearchBar(window);

            if (bar)
            {
                bar.hidden = NO;
                [bar becomeFirstResponder];
                return;
            }


            /*
             * 2. Search controller.
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
             * 3. Elemento Search existente.
             */

            UIView *element =
                SGSFindSearchElement(window);

            if (element)
            {
                if ([element
                     isKindOfClass:
                     [UIButton class]])
                {
                    [(UIButton *)element
                        sendActionsForControlEvents:
                        UIControlEventTouchUpInside];

                    return;
                }

                for (UIView *subview
                     in element.subviews)
                {
                    if ([subview
                         isKindOfClass:
                         [UIButton class]])
                    {
                        [(UIButton *)subview
                            sendActionsForControlEvents:
                            UIControlEventTouchUpInside];

                        return;
                    }
                }
            }


            /*
             * 4. Dá tempo para o Settings
             * terminar de montar a interface.
             */

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)
                    (0.35 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    UIWindow *lateWindow =
                        SGSGetSettingsWindow();

                    if (!lateWindow)
                        return;

                    UISearchBar *lateBar =
                        SGSFindSearchBar(
                            lateWindow
                        );

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
                }
            );
        }
    );
}


#pragma mark - Live Glass View

@interface SGSGlassView : UIView

@property(nonatomic,strong)
UIImageView *liveImageView;

@property(nonatomic,strong)
UIView *innerHighlight;

@property(nonatomic,strong)
CAGradientLayer *topHighlight;

@property(nonatomic,strong)
CAGradientLayer *edgeHighlight;

@property(nonatomic,strong)
CAGradientLayer *bottomHighlight;

@property(nonatomic,strong)
CADisplayLink *displayLink;

@end


@implementation SGSGlassView


#pragma mark Init

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


        /*
         * Live image.
         */

        self.liveImageView =
            [[UIImageView alloc]
                initWithFrame:CGRectZero];

        self.liveImageView.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.liveImageView.contentMode =
            UIViewContentModeScaleToFill;

        self.liveImageView.clipsToBounds =
            YES;

        self.liveImageView.alpha =
            0.72;

        [self addSubview:
            self.liveImageView];


        /*
         * Pequeno blur por cima da imagem.
         */

        UIBlurEffect *blur =
            [UIBlurEffect
                effectWithStyle:
                UIBlurEffectStyleSystemChromeMaterial];

        UIVisualEffectView *blurView =
            [[UIVisualEffectView alloc]
                initWithEffect:blur];

        blurView.translatesAutoresizingMaskIntoConstraints =
            NO;

        blurView.alpha =
            0.30;

        blurView.userInteractionEnabled =
            NO;

        [self addSubview:
            blurView];


        /*
         * Highlight interno.
         */

        self.innerHighlight =
            [[UIView alloc]
                initWithFrame:CGRectZero];

        self.innerHighlight.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.innerHighlight.backgroundColor =
            UIColor.clearColor;

        self.innerHighlight.userInteractionEnabled =
            NO;

        [self addSubview:
            self.innerHighlight];


        /*
         * Reflexo superior.
         */

        self.topHighlight =
            [CAGradientLayer layer];

        self.topHighlight.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.42].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.12].CGColor,

            (id)[UIColor clearColor].CGColor
        ];

        self.topHighlight.locations = @[
            @0.0,
            @0.18,
            @0.55
        ];

        self.topHighlight.startPoint =
            CGPointMake(0.5, 0.0);

        self.topHighlight.endPoint =
            CGPointMake(0.5, 1.0);

        [self.innerHighlight.layer
            addSublayer:self.topHighlight];


        /*
         * Reflexo inferior.
         */

        self.bottomHighlight =
            [CAGradientLayer layer];

        self.bottomHighlight.colors = @[
            (id)[UIColor clearColor].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.05].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.20].CGColor
        ];

        self.bottomHighlight.startPoint =
            CGPointMake(0.5, 0.0);

        self.bottomHighlight.endPoint =
            CGPointMake(0.5, 1.0);

        [self.innerHighlight.layer
            addSublayer:self.bottomHighlight];


        /*
         * Reflexo das bordas.
         */

        self.edgeHighlight =
            [CAGradientLayer layer];

        self.edgeHighlight.colors = @[
            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.58].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.08].CGColor,

            (id)[[UIColor whiteColor]
                colorWithAlphaComponent:0.38].CGColor
        ];

        self.edgeHighlight.startPoint =
            CGPointMake(0.0, 0.0);

        self.edgeHighlight.endPoint =
            CGPointMake(1.0, 0.0);

        CAShapeLayer *edgeMask =
            [CAShapeLayer layer];

        self.edgeHighlight.mask =
            edgeMask;

        [self.layer
            addSublayer:self.edgeHighlight];


        /*
         * Borda fina.
         */

        self.layer.borderWidth =
            0.65;

        self.layer.borderColor =
            [[UIColor whiteColor]
                colorWithAlphaComponent:0.42].CGColor;


        /*
         * Constraints.
         */

        [NSLayoutConstraint activateConstraints:@[

            [self.liveImageView.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [self.liveImageView.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [self.liveImageView.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [self.liveImageView.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor],

            [blurView.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [blurView.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [blurView.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [blurView.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor],

            [self.innerHighlight.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [self.innerHighlight.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [self.innerHighlight.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [self.innerHighlight.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor]
        ]];


        /*
         * Display link:
         * atualiza o conteúdo em tempo real.
         */

        self.displayLink =
            [CADisplayLink
                displayLinkWithTarget:self
                selector:@selector(updateGlass)];

        [self.displayLink
            addToRunLoop:
            [NSRunLoop mainRunLoop]
            forMode:NSRunLoopCommonModes];

        /*
         * Aproximadamente 15 FPS.
         */

        self.displayLink.preferredFramesPerSecond =
            15;
    }

    return self;
}


#pragma mark - Live Snapshot

- (void)updateGlass
{
    UIWindow *window =
        SGSGetSettingsWindow();

    if (!window)
        return;

    if (!self.window)
        return;

    /*
     * Evita capturar o próprio vidro.
     */

    UIView *container =
        sgsContainer;

    BOOL wasHidden =
        container.hidden;

    container.hidden =
        YES;


    CGSize size =
        window.bounds.size;

    UIGraphicsImageRendererFormat *format =
        [UIGraphicsImageRendererFormat
            defaultFormat];

    format.scale =
        UIScreen.mainScreen.scale;

    format.opaque =
        YES;


    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc]
            initWithSize:size
            format:format];


    UIImage *snapshot =
        [renderer imageWithActions:
            ^(UIGraphicsImageRendererContext *context)
        {
            [window drawViewHierarchyInRect:
                window.bounds
                afterScreenUpdates:NO];
        }];


    container.hidden =
        wasHidden;


    if (!snapshot)
        return;


    /*
     * Core Image.
     */

    if (!sgsCIContext)
    {
        sgsCIContext =
            [CIContext contextWithOptions:nil];
    }


    CIImage *image =
        [[CIImage alloc]
            initWithImage:snapshot];

    if (!image)
        return;


    /*
     * Pixelização muito fina.
     *
     * O objetivo não é transformar em
     * mosaico; é criar a textura de vidro.
     */

    CIFilter *pixelFilter =
        [CIFilter filterWithName:@"CIPixellate"];

    [pixelFilter
        setValue:image
        forKey:kCIInputImageKey];

    [pixelFilter
        setValue:@(3.0)
        forKey:kCIInputScaleKey];

    CIVector *center =
        [CIVector vectorWithX:size.width / 2.0
                             Y:size.height / 2.0];

    [pixelFilter
        setValue:center
        forKey:kCIInputCenterKey];

    CIImage *pixelImage =
        pixelFilter.outputImage;


    /*
     * Blur muito leve.
     */

    CIFilter *blurFilter =
        [CIFilter filterWithName:
            @"CIGaussianBlur"];

    [blurFilter
        setValue:pixelImage
        forKey:kCIInputImageKey];

    [blurFilter
        setValue:@(1.2)
        forKey:kCIInputRadiusKey];

    CIImage *finalImage =
        blurFilter.outputImage;


    /*
     * Crop.
     */

    finalImage =
        [finalImage
            imageByCroppingToRect:
                CGRectMake(
                    0,
                    0,
                    size.width,
                    size.height
                )];


    CGImageRef cgImage =
        [sgsCIContext
            createCGImage:finalImage
            fromRect:
                CGRectMake(
                    0,
                    0,
                    size.width,
                    size.height
                )];

    if (!cgImage)
        return;


    UIImage *processed =
        [UIImage
            imageWithCGImage:
                cgImage
            scale:
                UIScreen.mainScreen.scale
            orientation:
                UIImageOrientationUp];

    CGImageRelease(cgImage);


    /*
     * Mostra o resultado.
     */

    self.liveImageView.image =
        processed;
}


#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layer.cornerRadius =
        sgsRadius;

    self.topHighlight.frame =
        self.bounds;

    self.bottomHighlight.frame =
        self.bounds;

    self.edgeHighlight.frame =
        self.bounds;


    /*
     * Máscara da borda.
     */

    CAShapeLayer *mask =
        (CAShapeLayer *)
        self.edgeHighlight.mask;

    UIBezierPath *outer =
        [UIBezierPath
            bezierPathWithRoundedRect:
                self.bounds
            cornerRadius:
                sgsRadius];

    UIBezierPath *inner =
        [UIBezierPath
            bezierPathWithRoundedRect:
                CGRectInset(
                    self.bounds,
                    0.9,
                    0.9
                )
            cornerRadius:
                MAX(
                    sgsRadius - 0.9,
                    0
                )];

    [outer appendPath:
        [inner
            bezierPathByReversingPath]];

    mask.path =
        outer.CGPath;
}


#pragma mark - Dealloc

- (void)dealloc
{
    [self.displayLink invalidate];

    self.displayLink = nil;
}

@end


#pragma mark - Search Control

@interface SGSSearchControl : UIControl

@property(nonatomic,strong)
SGSGlassView *glassView;

@property(nonatomic,strong)
UIImageView *searchIcon;

@property(nonatomic,strong)
UILabel *searchLabel;

@property(nonatomic,strong)
UIImageView *micIcon;

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

        self.clipsToBounds =
            YES;

        self.layer.cornerRadius =
            sgsRadius;


        /*
         * Glass.
         */

        self.glassView =
            [[SGSGlassView alloc]
                initWithFrame:CGRectZero];

        self.glassView.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.glassView.userInteractionEnabled =
            NO;

        [self addSubview:
            self.glassView];


        /*
         * Search icon.
         */

        UIImageSymbolConfiguration *searchConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:21.0
                weight:UIFontWeightRegular];

        UIImage *searchImage =
            [UIImage
                systemImageNamed:
                    @"magnifyingglass"
                withConfiguration:
                    searchConfig];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:
                    searchImage];

        self.searchIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchIcon.tintColor =
            UIColor.labelColor;

        self.searchIcon.userInteractionEnabled =
            NO;

        [self addSubview:
            self.searchIcon];


        /*
         * Search.
         */

        self.searchLabel =
            [[UILabel alloc] init];

        self.searchLabel.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.searchLabel.text =
            @"Search";

        self.searchLabel.textColor =
            [[UIColor labelColor]
                colorWithAlphaComponent:0.62];

        self.searchLabel.font =
            [UIFont
                systemFontOfSize:20.0
                weight:UIFontWeightRegular];

        self.searchLabel.userInteractionEnabled =
            NO;

        [self addSubview:
            self.searchLabel];


        /*
         * Microphone.
         */

        UIImageSymbolConfiguration *micConfig =
            [UIImageSymbolConfiguration
                configurationWithPointSize:20.0
                weight:UIImageSymbolWeightMedium];

        UIImage *micImage =
            [UIImage
                systemImageNamed:@"mic"
                withConfiguration:
                    micConfig];

        self.micIcon =
            [[UIImageView alloc]
                initWithImage:
                    micImage];

        self.micIcon.translatesAutoresizingMaskIntoConstraints =
            NO;

        self.micIcon.tintColor =
            UIColor.labelColor;

        self.micIcon.userInteractionEnabled =
            NO;

        [self addSubview:
            self.micIcon];


        /*
         * Constraints.
         */

        [NSLayoutConstraint activateConstraints:@[

            /*
             * Glass.
             */

            [self.glassView.leadingAnchor
                constraintEqualToAnchor:
                    self.leadingAnchor],

            [self.glassView.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor],

            [self.glassView.topAnchor
                constraintEqualToAnchor:
                    self.topAnchor],

            [self.glassView.bottomAnchor
                constraintEqualToAnchor:
                    self.bottomAnchor],


            /*
             * Search icon.
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
             * Search label.
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
             * Microphone.
             */

            [self.micIcon.trailingAnchor
                constraintEqualToAnchor:
                    self.trailingAnchor
                    constant:-16.0],

            [self.micIcon.centerYAnchor
                constraintEqualToAnchor:
                    self.centerYAnchor],

            [self.micIcon.widthAnchor
                constraintEqualToConstant:24.0],

            [self.micIcon.heightAnchor
                constraintEqualToConstant:24.0]
        ]];
    }

    return self;
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

    [UIView animateWithDuration:0.16
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;
    }];


    /*
     * Abre Search.
     */

    SGSOpenNativeSearch();
}


#pragma mark - Cancel

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];

    [UIView animateWithDuration:0.16
                     animations:^{

        self.transform =
            CGAffineTransformIdentity;
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
     * Container.
     */

    sgsContainer =
        [[UIView alloc]
            initWithFrame:CGRectZero];

    sgsContainer.translatesAutoresizingMaskIntoConstraints =
        NO;

    sgsContainer.backgroundColor =
        UIColor.clearColor;

    sgsContainer.userInteractionEnabled =
        YES;


    /*
     * Search control.
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


    /*
     * Barra.
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


#pragma mark - Preferences Callback

static void SGSPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo)
{
    SGSRefresh();
}


#pragma mark - UIViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    NSString *bundle =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundle
          isEqualToString:
          @"com.apple.Preferences"])
        return;


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)
            (0.25 * NSEC_PER_SEC)
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

    NSString *bundle =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundle
          isEqualToString:
          @"com.apple.Preferences"])
        return;


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)
            (0.30 * NSEC_PER_SEC)
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
    NSString *bundle =
        [[NSBundle mainBundle]
            bundleIdentifier];

    /*
     * Carrega somente dentro do Ajustes.
     */

    if (![bundle
          isEqualToString:
          @"com.apple.Preferences"])
        return;


    SGSLoadPreferences();


    /*
     * Preferences.
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
                (int64_t)
                (0.50 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

            SGSCreateSearchBar();
        });
    });
}
