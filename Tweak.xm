#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <objc/runtime.h>

#pragma mark - SearchGlass

static NSInteger const kSearchGlassTag = 987654;

@interface SearchGlassButton : UIButton
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *pixelView;
@property (nonatomic, strong) CAGradientLayer *reflectionLayer;
@property (nonatomic, strong) CAShapeLayer *borderLayer;
@end

@implementation SearchGlassButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.tag = kSearchGlassTag;

        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 24.0;

        // --------------------------------------------------
        // GLASS BLUR
        // --------------------------------------------------

        UIBlurEffect *blurEffect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];

        self.blurView =
            [[UIVisualEffectView alloc] initWithEffect:blurEffect];

        self.blurView.userInteractionEnabled = NO;
        self.blurView.frame = self.bounds;
        self.blurView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [self addSubview:self.blurView];

        // --------------------------------------------------
        // PIXEL / DISTORTION LAYER
        // --------------------------------------------------

        self.pixelView = [[UIView alloc] initWithFrame:self.bounds];

        self.pixelView.backgroundColor =
            [UIColor colorWithWhite:1.0 alpha:0.025];

        self.pixelView.userInteractionEnabled = NO;

        self.pixelView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [self.blurView.contentView addSubview:self.pixelView];

        // --------------------------------------------------
        // REFLECTION
        // --------------------------------------------------

        self.reflectionLayer = [CAGradientLayer layer];

        self.reflectionLayer.frame = self.bounds;

        self.reflectionLayer.startPoint = CGPointMake(0.0, 0.0);
        self.reflectionLayer.endPoint   = CGPointMake(1.0, 1.0);

        self.reflectionLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor
        ];

        self.reflectionLayer.locations = @[
            @0.0,
            @0.18,
            @0.58,
            @1.0
        ];

        [self.layer addSublayer:self.reflectionLayer];

        // --------------------------------------------------
        // BORDER
        // --------------------------------------------------

        self.borderLayer = [CAShapeLayer layer];

        self.borderLayer.frame = self.bounds;

        self.borderLayer.fillColor = UIColor.clearColor.CGColor;

        self.borderLayer.strokeColor =
            [UIColor colorWithWhite:1.0 alpha:0.38].CGColor;

        self.borderLayer.lineWidth = 0.8;

        UIBezierPath *path =
            [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                      cornerRadius:24.0];

        self.borderLayer.path = path.CGPath;

        [self.layer addSublayer:self.borderLayer];

        // --------------------------------------------------
        // LUPA
        // --------------------------------------------------

        UIImage *magnifyingGlass =
            [UIImage systemImageNamed:@"magnifyingglass"];

        if (magnifyingGlass) {
            magnifyingGlass =
                [magnifyingGlass imageWithRenderingMode:
                    UIImageRenderingModeAlwaysTemplate];

            [self setImage:magnifyingGlass forState:UIControlStateNormal];

            self.imageView.tintColor =
                [UIColor labelColor];
        }

        // --------------------------------------------------
        // TEXTO
        // --------------------------------------------------

        [self setTitle:@"Search" forState:UIControlStateNormal];

        self.titleLabel.font =
            [UIFont systemFontOfSize:16.0
                              weight:UIFontWeightRegular];

        [self setTitleColor:
            [UIColor labelColor]
              forState:UIControlStateNormal];

        self.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        self.imageEdgeInsets =
            UIEdgeInsetsMake(0, 17, 0, 0);

        self.titleEdgeInsets =
            UIEdgeInsetsMake(0, 10, 0, 0);

        self.contentEdgeInsets =
            UIEdgeInsetsMake(0, 0, 0, 17);

        // --------------------------------------------------
        // SOMBRA
        // --------------------------------------------------

        self.layer.shadowColor =
            [UIColor blackColor].CGColor;

        self.layer.shadowOpacity = 0.12;
        self.layer.shadowRadius = 10.0;
        self.layer.shadowOffset = CGSizeMake(0, 4);
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.blurView.frame = self.bounds;
    self.pixelView.frame = self.bounds;
    self.reflectionLayer.frame = self.bounds;
    self.borderLayer.frame = self.bounds;

    UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                  cornerRadius:24.0];

    self.borderLayer.path = path.CGPath;
}

@end


#pragma mark - Search activation

static UIView *SGFindSearchView(UIView *view) {

    if ([view isKindOfClass:[UISearchBar class]]) {
        return view;
    }

    if ([view isKindOfClass:[UISearchTextField class]]) {
        return view;
    }

    for (UIView *subview in view.subviews) {

        UIView *result = SGFindSearchView(subview);

        if (result) {
            return result;
        }
    }

    return nil;
}


static UISearchController *SGFindSearchController(UIView *view) {

    for (UIView *subview in view.subviews) {

        if ([subview isKindOfClass:[UISearchController class]]) {
            return (UISearchController *)subview;
        }

        UISearchController *result =
            SGFindSearchController(subview);

        if (result) {
            return result;
        }
    }

    return nil;
}


static void SGActivateSearch(UIViewController *controller) {

    if (!controller) {
        return;
    }

    // --------------------------------------------------
    // 1. TENTA UISearchController
    // --------------------------------------------------

    UISearchController *searchController =
        SGFindSearchController(controller.view);

    if (searchController) {

        if (@available(iOS 8.0, *)) {
            [searchController setActive:YES];
        }

        UISearchBar *searchBar =
            searchController.searchBar;

        if (searchBar) {
            [searchBar becomeFirstResponder];
        }

        return;
    }

    // --------------------------------------------------
    // 2. PROCURA UISearchBar
    // --------------------------------------------------

    UIView *searchView =
        SGFindSearchView(controller.view);

    if (searchView) {

        if ([searchView isKindOfClass:[UISearchBar class]]) {

            UISearchBar *searchBar =
                (UISearchBar *)searchView;

            [searchBar becomeFirstResponder];

            return;
        }

        if ([searchView isKindOfClass:[UISearchTextField class]]) {

            UISearchTextField *textField =
                (UISearchTextField *)searchView;

            [textField becomeFirstResponder];

            return;
        }
    }

    // --------------------------------------------------
    // 3. PROCURA NOVAMENTE APÓS O LAYOUT
    // --------------------------------------------------

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{

            UIView *search =
                SGFindSearchView(controller.view);

            if ([search isKindOfClass:[UISearchBar class]]) {

                [(UISearchBar *)search becomeFirstResponder];
            }

            else if ([search isKindOfClass:
                      [UISearchTextField class]]) {

                [(UISearchTextField *)search
                    becomeFirstResponder];
            }
        }
    );
}


#pragma mark - Settings Controller

%hook PSListController

- (void)viewDidAppear:(BOOL)animated {

    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{

        UIView *view = self.view;

        if (!view) {
            return;
        }

        // Evita criar dois botões
        UIView *oldButton =
            [view viewWithTag:kSearchGlassTag];

        if (oldButton) {
            return;
        }

        // --------------------------------------------------
        // TAMANHO
        // --------------------------------------------------

        CGFloat width = 185.0;
        CGFloat height = 48.0;

        // --------------------------------------------------
        // POSIÇÃO
        // --------------------------------------------------

        CGFloat safeBottom =
            view.safeAreaInsets.bottom;

        CGFloat x =
            (view.bounds.size.width - width) / 2.0;

        CGFloat y =
            view.bounds.size.height -
            safeBottom -
            height -
            14.0;

        SearchGlassButton *button =
            [[SearchGlassButton alloc]
                initWithFrame:CGRectMake(
                    x,
                    y,
                    width,
                    height
                )];

        button.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin;

        [button addTarget:self
                   action:@selector(sg_searchButtonPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [view addSubview:button];

        // Mantém o botão acima das células
        [view bringSubviewToFront:button];

    });
}


%new

- (void)sg_searchButtonPressed:(id)sender {

    // Pequena animação de pressionamento
    if ([sender isKindOfClass:[UIView class]]) {

        UIView *button = (UIView *)sender;

        [UIView animateWithDuration:0.08
                         animations:^{
            button.transform =
                CGAffineTransformMakeScale(0.96, 0.96);
        }
                         completion:^(BOOL finished) {

            [UIView animateWithDuration:0.12
                             animations:^{
                button.transform =
                    CGAffineTransformIdentity;
            }];
        }];
    }

    // Ativa a pesquisa
    SGActivateSearch(self);
}

%end


#pragma mark - Reposicionamento após rotação

%hook PSListController

- (void)viewDidLayoutSubviews {

    %orig;

    UIView *button =
        [self.view viewWithTag:kSearchGlassTag];

    if (!button) {
        return;
    }

    CGFloat width = 185.0;
    CGFloat height = 48.0;

    CGFloat safeBottom =
        self.view.safeAreaInsets.bottom;

    CGFloat x =
        (self.view.bounds.size.width - width) / 2.0;

    CGFloat y =
        self.view.bounds.size.height -
        safeBottom -
        height -
        14.0;

    button.frame =
        CGRectMake(x, y, width, height);
}

%end


#pragma mark - Touch feedback

%hook SearchGlassButton

- (void)setHighlighted:(BOOL)highlighted {

    [super setHighlighted:highlighted];

    [UIView animateWithDuration:0.08
                     animations:^{

        if (highlighted) {

            self.alpha = 0.72;

        } else {

            self.alpha = 1.0;
        }
    }];
}

%end
