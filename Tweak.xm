#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - SearchGlass

@interface SGGlassView : UIVisualEffectView
@property(nonatomic, strong) CAGradientLayer *borderGradient;
@property(nonatomic, strong) CAGradientLayer *highlightGradient;
@property(nonatomic, strong) CAShapeLayer *innerHighlight;
@property(nonatomic, strong) CAShapeLayer *innerShadow;
@end

@implementation SGGlassView

- (instancetype)initWithFrame:(CGRect)frame {
    UIBlurEffect *blur =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];

    self = [super initWithEffect:blur];

    if (self) {
        self.frame = frame;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 22.0;
        self.layer.masksToBounds = YES;

        [self setupGlass];
    }

    return self;
}

- (void)setupGlass {

    /*
     * ============================================================
     * BASE GLASS
     * ============================================================
     */

    UIView *glassTint = [[UIView alloc] initWithFrame:self.bounds];

    glassTint.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    /*
     * Muito pouca cor.
     * Não usamos tint forte para preservar o efeito do SVG.
     */
    glassTint.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.08];

    glassTint.userInteractionEnabled = NO;

    [self.contentView addSubview:glassTint];


    /*
     * ============================================================
     * REFLEXO INTERNO
     * ============================================================
     *
     * Cria a iluminação que percorre a parte superior/inferior
     * do vidro.
     */

    self.highlightGradient = [CAGradientLayer layer];

    self.highlightGradient.frame = self.bounds;

    self.highlightGradient.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.035].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.055].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.16].CGColor
    ];

    self.highlightGradient.locations = @[
        @0.0,
        @0.18,
        @0.50,
        @0.82,
        @1.0
    ];

    self.highlightGradient.startPoint = CGPointMake(0.5, 0.0);
    self.highlightGradient.endPoint = CGPointMake(0.5, 1.0);

    self.highlightGradient.cornerRadius = 22.0;

    [self.layer addSublayer:self.highlightGradient];


    /*
     * ============================================================
     * BORDA REFLETIVA
     * ============================================================
     *
     * Vários pontos de luz para imitar o efeito do SVG:
     *
     * - luz branca superior
     * - reflexão lateral
     * - parte inferior mais escura
     */

    self.borderGradient = [CAGradientLayer layer];

    self.borderGradient.frame = self.bounds;

    self.borderGradient.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.62].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.11].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor
    ];

    self.borderGradient.locations = @[
        @0.00,
        @0.18,
        @0.50,
        @0.80,
        @1.00
    ];

    self.borderGradient.startPoint = CGPointMake(0.05, 0.0);
    self.borderGradient.endPoint = CGPointMake(0.95, 1.0);

    self.borderGradient.cornerRadius = 22.0;

    /*
     * Máscara para deixar somente a borda.
     */
    CAShapeLayer *borderMask = [CAShapeLayer layer];

    CGRect borderRect =
        CGRectInset(self.bounds, 0.45, 0.45);

    UIBezierPath *outerPath =
        [UIBezierPath bezierPathWithRoundedRect:borderRect
                                    cornerRadius:21.55];

    UIBezierPath *innerPath =
        [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(borderRect, 0.95, 0.95)
                                    cornerRadius:20.60];

    [outerPath appendPath:innerPath];

    borderMask.path = outerPath.CGPath;
    borderMask.fillRule = kCAFillRuleEvenOdd;

    self.borderGradient.mask = borderMask;

    [self.layer addSublayer:self.borderGradient];


    /*
     * ============================================================
     * HIGHLIGHT SUPERIOR
     * ============================================================
     */

    self.innerHighlight = [CAShapeLayer layer];

    self.innerHighlight.frame = self.bounds;

    self.innerHighlight.path =
        [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(self.bounds, 0.8, 0.8)
            cornerRadius:21.2].CGPath;

    self.innerHighlight.fillColor =
        [UIColor clearColor].CGColor;

    self.innerHighlight.strokeColor =
        [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;

    self.innerHighlight.lineWidth = 0.55;

    [self.layer addSublayer:self.innerHighlight];


    /*
     * ============================================================
     * SOMBRA INTERNA
     * ============================================================
     */

    self.innerShadow = [CAShapeLayer layer];

    self.innerShadow.frame = self.bounds;

    self.innerShadow.path =
        [UIBezierPath bezierPathWithRoundedRect:
            CGRectInset(self.bounds, 1.2, 1.2)
            cornerRadius:20.8].CGPath;

    self.innerShadow.fillColor =
        [UIColor clearColor].CGColor;

    self.innerShadow.strokeColor =
        [UIColor colorWithWhite:0.0 alpha:0.10].CGColor;

    self.innerShadow.lineWidth = 0.65;

    [self.layer addSublayer:self.innerShadow];


    /*
     * ============================================================
     * SOMBRA EXTERNA MUITO SUAVE
     * ============================================================
     */

    self.layer.shadowColor =
        [UIColor blackColor].CGColor;

    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 8.0;
    self.layer.shadowOffset = CGSizeMake(0, 3);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.highlightGradient.frame = self.bounds;
    self.borderGradient.frame = self.bounds;

    self.innerHighlight.frame = self.bounds;
    self.innerShadow.frame = self.bounds;
}

@end


#pragma mark - Search Button

@interface SGSearchButton : UIControl

@property(nonatomic, strong) SGGlassView *glassView;
@property(nonatomic, strong) UIImageView *searchIcon;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIImageView *micIcon;

@end

@implementation SGSearchButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = UIColor.clearColor;

        [self buildUI];

        [self addTarget:self
                 action:@selector(searchPressed:)
       forControlEvents:UIControlEventTouchUpInside];
    }

    return self;
}

- (void)buildUI {

    /*
     * ============================================================
     * GLASS
     * ============================================================
     */

    self.glassView =
        [[SGGlassView alloc] initWithFrame:self.bounds];

    self.glassView.userInteractionEnabled = NO;

    [self addSubview:self.glassView];


    /*
     * ============================================================
     * LUPA
     * ============================================================
     */

    UIImageSymbolConfiguration *searchConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                        weight:UIImageSymbolWeightRegular];

    UIImage *searchImage =
        [UIImage systemImageNamed:@"magnifyingglass"
                withConfiguration:searchConfig];

    self.searchIcon =
        [[UIImageView alloc] initWithImage:searchImage];

    self.searchIcon.tintColor =
        [UIColor colorWithWhite:0.04 alpha:0.95];

    self.searchIcon.contentMode =
        UIViewContentModeScaleAspectFit;

    self.searchIcon.frame =
        CGRectMake(14.0, 11.0, 22.0, 22.0);

    self.searchIcon.userInteractionEnabled = NO;

    [self addSubview:self.searchIcon];


    /*
     * ============================================================
     * SEARCH
     * ============================================================
     */

    self.titleLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(48.0,
                                                   0.0,
                                                   190.0,
                                                   44.0)];

    self.titleLabel.text = @"Search";

    self.titleLabel.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightRegular];

    self.titleLabel.textColor =
        [UIColor colorWithWhite:0.25 alpha:0.90];

    self.titleLabel.textAlignment =
        NSTextAlignmentLeft;

    self.titleLabel.backgroundColor =
        UIColor.clearColor;

    self.titleLabel.userInteractionEnabled = NO;

    [self addSubview:self.titleLabel];


    /*
     * ============================================================
     * MICROFONE
     * ============================================================
     */

    UIImageSymbolConfiguration *micConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                        weight:UIImageSymbolWeightRegular];

    UIImage *micImage =
        [UIImage systemImageNamed:@"mic"
                withConfiguration:micConfig];

    self.micIcon =
        [[UIImageView alloc] initWithImage:micImage];

    self.micIcon.tintColor =
        [UIColor colorWithWhite:0.04 alpha:0.95];

    self.micIcon.contentMode =
        UIViewContentModeScaleAspectFit;

    self.micIcon.frame =
        CGRectMake(self.bounds.size.width - 38.0,
                   11.0,
                   22.0,
                   22.0);

    self.micIcon.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin;

    self.micIcon.userInteractionEnabled = NO;

    [self addSubview:self.micIcon];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.glassView.frame = self.bounds;

    self.searchIcon.frame =
        CGRectMake(14.0,
                   11.0,
                   22.0,
                   22.0);

    self.titleLabel.frame =
        CGRectMake(48.0,
                   0.0,
                   self.bounds.size.width - 96.0,
                   self.bounds.size.height);

    self.micIcon.frame =
        CGRectMake(self.bounds.size.width - 38.0,
                   11.0,
                   22.0,
                   22.0);
}


#pragma mark - Search Action

- (void)searchPressed:(id)sender {

    /*
     * Primeiro encontra o UIViewController da tela atual.
     */

    UIViewController *vc = [self nearestViewController];

    if (!vc)
        return;


    /*
     * Se estivermos dentro de uma navegação dos Ajustes,
     * voltamos para a página principal.
     */

    UINavigationController *navigationController =
        vc.navigationController;

    if (navigationController) {

        [navigationController
            popToRootViewControllerAnimated:YES];
    }


    /*
     * Espera a transição terminar antes de procurar
     * a UISearchBar nativa dos Ajustes.
     */

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.30 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{

            UIViewController *root =
                navigationController ?
                navigationController.viewControllers.firstObject :
                vc;

            if (!root)
                return;

            UISearchBar *searchBar =
                [self findSearchBarInView:root.view];

            /*
             * Se encontrou a pesquisa nativa:
             *
             * 1. tenta tornar visível
             * 2. coloca foco
             * 3. abre teclado
             */

            if (searchBar) {

                UIScrollView *scroll =
                    [self findScrollViewContainingView:searchBar];

                if (scroll) {

                    CGRect rect =
                        [searchBar convertRect:searchBar.bounds
                                        toView:scroll];

                    [scroll
                        scrollRectToVisible:rect
                        animated:YES];
                }

                [searchBar becomeFirstResponder];

                return;
            }


            /*
             * Segunda tentativa:
             * procura novamente depois de um pequeno intervalo,
             * pois o Settings.app pode ainda estar montando
             * a interface.
             */

            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(0.25 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{

                    UISearchBar *retry =
                        [self findSearchBarInView:root.view];

                    if (retry) {
                        [retry becomeFirstResponder];
                    }
                });
        });
}


#pragma mark - View Controller Finder

- (UIViewController *)nearestViewController {

    UIResponder *responder = self;

    while (responder) {

        responder =
            [responder nextResponder];

        if ([responder isKindOfClass:
             [UIViewController class]]) {

            return (UIViewController *)responder;
        }
    }

    return nil;
}


#pragma mark - SearchBar Finder

- (UISearchBar *)findSearchBarInView:(UIView *)view {

    if (!view)
        return nil;

    if ([view isKindOfClass:
         [UISearchBar class]]) {

        return (UISearchBar *)view;
    }


    for (UIView *subview in view.subviews) {

        UISearchBar *result =
            [self findSearchBarInView:subview];

        if (result)
            return result;
    }

    return nil;
}


#pragma mark - ScrollView Finder

- (UIScrollView *)findScrollViewContainingView:(UIView *)target {

    UIView *view = target.superview;

    while (view) {

        if ([view isKindOfClass:
             [UIScrollView class]]) {

            return (UIScrollView *)view;
        }

        view = view.superview;
    }

    return nil;
}


#pragma mark - Touch Feedback

- (void)setHighlighted:(BOOL)highlighted {

    [UIView animateWithDuration:0.10
                     animations:^{

        self.transform =
            highlighted ?
            CGAffineTransformMakeScale(0.985, 0.985) :
            CGAffineTransformIdentity;

        self.alpha =
            highlighted ? 0.86 : 1.0;
    }];
}

@end


#pragma mark - Settings Hook

@interface PSListController : UIViewController
@end


%hook PSListController

- (void)viewDidAppear:(BOOL)animated {

    %orig;

    /*
     * Só adiciona o botão na tela principal dos Ajustes.
     */

    if (![self isMainSettingsController])
        return;

    [self installSearchGlassIfNeeded];
}

%new
- (BOOL)isMainSettingsController {

    /*
     * Evita adicionar o botão em subpáginas.
     */

    NSString *className =
        NSStringFromClass([self class]);

    /*
     * O nome exato pode variar entre versões do iOS.
     * PSListController é comum nas páginas de preferências.
     */

    if ([className containsString:@"Search"])
        return NO;

    return YES;
}

%new
- (void)installSearchGlassIfNeeded {

    UIView *view = self.view;

    if (!view)
        return;


    /*
     * Evita duplicação.
     */

    if ([view viewWithTag:0x53474153])
        return;


    /*
     * ============================================================
     * TAMANHO DO BOTÃO
     * ============================================================
     *
     * Baseado no SVG:
     *
     * 316 × 44
     */

    CGFloat width = 316.0;
    CGFloat height = 44.0;


    /*
     * Centralizado horizontalmente.
     */

    CGFloat x =
        (view.bounds.size.width - width) / 2.0;


    /*
     * Fica próximo à parte inferior da tela,
     * respeitando Safe Area.
     */

    CGFloat bottomInset =
        view.safeAreaInsets.bottom;

    CGFloat y =
        view.bounds.size.height -
        bottomInset -
        height -
        18.0;


    SGSearchButton *button =
        [[SGSearchButton alloc]
            initWithFrame:CGRectMake(x,
                                     y,
                                     width,
                                     height)];

    button.tag = 0x53474153;


    /*
     * Auto Layout não é necessário aqui.
     */

    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin;


    /*
     * Mantém acima da interface dos Ajustes.
     */

    [view addSubview:button];

    [view bringSubviewToFront:button];


    /*
     * Reposiciona caso a tela seja redimensionada.
     */

    __weak SGSearchButton *weakButton = button;

    /*
     * Não utilizamos block de layout permanente.
     * O autoresizing resolve rotação/redimensionamento.
     */

    (void)weakButton;
}

%end


#pragma mark - Additional UIViewController Protection

%hook UINavigationController

- (void)viewDidLayoutSubviews {

    %orig;

    /*
     * Procura o botão caso a navegação do Settings
     * tenha reconstruído a view.
     */

    if (![self.view.window isKeyWindow])
        return;

    NSString *bundleID =
        [NSBundle.mainBundle bundleIdentifier];

    if (![bundleID isEqualToString:@"com.apple.Preferences"])
        return;

    for (UIViewController *controller
         in self.viewControllers) {

        if (![controller isKindOfClass:
              NSClassFromString(@"PSListController")]) {

            continue;
        }

        UIView *view = controller.view;

        if (!view)
            continue;

        UIView *existing =
            [view viewWithTag:0x53474153];

        if (existing)
            continue;

        /*
         * Só adiciona quando estiver na tela visível.
         */

        if (controller == self.topViewController) {

            SGSearchButton *button =
                [[SGSearchButton alloc]
                    initWithFrame:CGRectZero];

            CGFloat width = 316.0;
            CGFloat height = 44.0;

            CGFloat x =
                (view.bounds.size.width - width) / 2.0;

            CGFloat y =
                view.bounds.size.height -
                view.safeAreaInsets.bottom -
                height -
                18.0;

            button.frame =
                CGRectMake(x,
                           y,
                           width,
                           height);

            button.tag = 0x53474153;

            button.autoresizingMask =
                UIViewAutoresizingFlexibleLeftMargin |
                UIViewAutoresizingFlexibleRightMargin |
                UIViewAutoresizingFlexibleTopMargin;

            [view addSubview:button];

            [view bringSubviewToFront:button];
        }
    }
}

%end
