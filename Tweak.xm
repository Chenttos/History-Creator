#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <objc/message.h>

#pragma mark -
#pragma mark SearchGlass Button
#pragma mark -

static NSInteger const SGButtonTag = 987654;

@interface SearchGlassButton : UIButton

@property (nonatomic, strong) UIVisualEffectView *sgBlurView;
@property (nonatomic, strong) UIView *sgHighlightView;
@property (nonatomic, strong) CAGradientLayer *sgReflectionLayer;
@property (nonatomic, strong) CAShapeLayer *sgBorderLayer;

@end


@implementation SearchGlassButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self)
    {
        self.tag = SGButtonTag;

        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 24.0;

        /*
         ====================================================
         GLASS BLUR
         ====================================================
        */

        UIBlurEffect *blur =
            [UIBlurEffect effectWithStyle:
                UIBlurEffectStyleSystemMaterial];

        self.sgBlurView =
            [[UIVisualEffectView alloc]
                initWithEffect:blur];

        self.sgBlurView.frame =
            self.bounds;

        self.sgBlurView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        self.sgBlurView.userInteractionEnabled = NO;

        [self addSubview:self.sgBlurView];


        /*
         ====================================================
         LEVE HIGHLIGHT
         ====================================================
        */

        self.sgHighlightView =
            [[UIView alloc]
                initWithFrame:self.bounds];

        self.sgHighlightView.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.035];

        self.sgHighlightView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        self.sgHighlightView.userInteractionEnabled = NO;

        self.sgHighlightView.layer.cornerRadius = 24.0;

        [self addSubview:self.sgHighlightView];


        /*
         ====================================================
         REFLECTION
         ====================================================
        */

        self.sgReflectionLayer =
            [CAGradientLayer layer];

        self.sgReflectionLayer.frame =
            self.bounds;

        self.sgReflectionLayer.startPoint =
            CGPointMake(0.0, 0.0);

        self.sgReflectionLayer.endPoint =
            CGPointMake(1.0, 1.0);

        self.sgReflectionLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.45].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.12].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.0].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.16].CGColor
        ];

        self.sgReflectionLayer.locations = @[
            @0.0,
            @0.15,
            @0.60,
            @1.0
        ];

        self.sgReflectionLayer.cornerRadius = 24.0;

        [self.layer addSublayer:
            self.sgReflectionLayer];


        /*
         ====================================================
         BORDER
         ====================================================
        */

        self.sgBorderLayer =
            [CAShapeLayer layer];

        self.sgBorderLayer.frame =
            self.bounds;

        self.sgBorderLayer.fillColor =
            UIColor.clearColor.CGColor;

        self.sgBorderLayer.strokeColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.42].CGColor;

        self.sgBorderLayer.lineWidth = 0.8;

        [self.layer addSublayer:
            self.sgBorderLayer];


        /*
         ====================================================
         LUPA
         ====================================================
        */

        UIImage *searchImage =
            [UIImage systemImageNamed:@"magnifyingglass"];

        if (searchImage)
        {
            searchImage =
                [searchImage imageWithRenderingMode:
                    UIImageRenderingModeAlwaysTemplate];

            [self setImage:
                searchImage
                 forState:UIControlStateNormal];

            self.imageView.tintColor =
                [UIColor labelColor];
        }


        /*
         ====================================================
         TEXTO
         ====================================================
        */

        [self setTitle:@"Search"
              forState:UIControlStateNormal];

        self.titleLabel.font =
            [UIFont systemFontOfSize:16.0
                              weight:UIFontWeightRegular];

        [self setTitleColor:
            [UIColor labelColor]
              forState:UIControlStateNormal];

        self.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;

        self.imageEdgeInsets =
            UIEdgeInsetsMake(
                0,
                16,
                0,
                0
            );

        self.titleEdgeInsets =
            UIEdgeInsetsMake(
                0,
                9,
                0,
                0
            );

        self.contentEdgeInsets =
            UIEdgeInsetsMake(
                0,
                0,
                0,
                16
            );


        /*
         ====================================================
         SOMBRA
         ====================================================
        */

        self.layer.shadowColor =
            [UIColor blackColor].CGColor;

        self.layer.shadowOpacity =
            0.10;

        self.layer.shadowRadius =
            8.0;

        self.layer.shadowOffset =
            CGSizeMake(0, 3);
    }

    return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];

    self.sgBlurView.frame =
        self.bounds;

    self.sgHighlightView.frame =
        self.bounds;

    self.sgReflectionLayer.frame =
        self.bounds;

    self.sgBorderLayer.frame =
        self.bounds;

    UIBezierPath *path =
        [UIBezierPath
            bezierPathWithRoundedRect:self.bounds
                         cornerRadius:24.0];

    self.sgBorderLayer.path =
        path.CGPath;
}


/*
 ============================================================
 BOTÃO PRESSIONADO
 ============================================================
*/

- (void)setHighlighted:(BOOL)highlighted
{
    [UIView animateWithDuration:0.08
                     animations:^
    {
        self.alpha =
            highlighted ? 0.72 : 1.0;

        self.transform =
            highlighted
                ? CGAffineTransformMakeScale(0.97, 0.97)
                : CGAffineTransformIdentity;
    }];
}

@end


#pragma mark -
#pragma mark SearchGlass Search Detection
#pragma mark -

static UIView *SGFindSearchView(UIView *view)
{
    if (!view)
        return nil;

    if ([view isKindOfClass:[UISearchBar class]])
        return view;

    if ([view isKindOfClass:[UISearchTextField class]])
        return view;

    for (UIView *subview in view.subviews)
    {
        UIView *found =
            SGFindSearchView(subview);

        if (found)
            return found;
    }

    return nil;
}


#pragma mark -
#pragma mark SearchGlass Activation
#pragma mark -

static void SGActivateSearch(UIViewController *controller)
{
    if (!controller)
        return;

    /*
     ========================================================
     PRIMEIRA TENTATIVA
     Procura uma UISearchBar existente
     ========================================================
    */

    UIView *searchView =
        SGFindSearchView(controller.view);

    if ([searchView isKindOfClass:[UISearchBar class]])
    {
        UISearchBar *searchBar =
            (UISearchBar *)searchView;

        [searchBar becomeFirstResponder];

        return;
    }


    if ([searchView isKindOfClass:
            [UISearchTextField class]])
    {
        UISearchTextField *field =
            (UISearchTextField *)searchView;

        [field becomeFirstResponder];

        return;
    }


    /*
     ========================================================
     SEGUNDA TENTATIVA
     Procura controllers de navegação
     ========================================================
    */

    UIViewController *parent =
        controller.parentViewController;

    while (parent)
    {
        UIView *found =
            SGFindSearchView(parent.view);

        if ([found isKindOfClass:[UISearchBar class]])
        {
            [(UISearchBar *)found becomeFirstResponder];

            return;
        }

        if ([found isKindOfClass:
                [UISearchTextField class]])
        {
            [(UISearchTextField *)found
                becomeFirstResponder];

            return;
        }

        parent =
            parent.parentViewController;
    }


    /*
     ========================================================
     TERCEIRA TENTATIVA
     Seleciona controlador de busca usando
     selector privado somente em runtime.
     
     Isso evita erro do compilador.
     ========================================================
    */

    SEL selectors[] =
    {
        sel_registerName("showSearch"),
        sel_registerName("presentSearch"),
        sel_registerName("activateSearch"),
        sel_registerName("beginSearch")
    };

    UIViewController *current =
        controller;

    for (int i = 0; i < 4; i++)
    {
        if ([current respondsToSelector:selectors[i]])
        {
            typedef void (*SGMsgSend)(id, SEL);

            SGMsgSend send =
                (SGMsgSend)objc_msgSend;

            send(current, selectors[i]);

            return;
        }

        current =
            current.parentViewController;

        if (!current)
            break;
    }


    /*
     ========================================================
     ÚLTIMA TENTATIVA
     Depois do layout da Settings
     ========================================================
    */

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.20 *
                     NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^
        {
            UIView *found =
                SGFindSearchView(controller.view);

            if ([found isKindOfClass:
                    [UISearchBar class]])
            {
                [(UISearchBar *)found
                    becomeFirstResponder];
            }
            else if ([found isKindOfClass:
                        [UISearchTextField class]])
            {
                [(UISearchTextField *)found
                    becomeFirstResponder];
            }
        }
    );
}


#pragma mark -
#pragma mark Settings
#pragma mark -

%hook PSListController


- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    dispatch_async(
        dispatch_get_main_queue(),
        ^
        {
            UIView *settingsView =
                self.view;

            if (!settingsView)
                return;


            /*
             =================================================
             EVITA DUPLICAÇÃO
             =================================================
            */

            UIView *existing =
                [settingsView
                    viewWithTag:SGButtonTag];

            if (existing)
                return;


            /*
             =================================================
             TAMANHO DO BOTÃO
             =================================================
            */

            CGFloat width = 185.0;
            CGFloat height = 48.0;


            /*
             =================================================
             POSIÇÃO
             =================================================
            */

            CGFloat bottom =
                settingsView.safeAreaInsets.bottom;

            CGFloat x =
                (settingsView.bounds.size.width -
                 width) / 2.0;

            CGFloat y =
                settingsView.bounds.size.height -
                bottom -
                height -
                14.0;


            SearchGlassButton *button =
                [[SearchGlassButton alloc]
                    initWithFrame:
                        CGRectMake(
                            x,
                            y,
                            width,
                            height
                        )];


            button.autoresizingMask =
                UIViewAutoresizingFlexibleLeftMargin |
                UIViewAutoresizingFlexibleRightMargin |
                UIViewAutoresizingFlexibleTopMargin;


            /*
             =================================================
             AÇÃO
             =================================================
            */

            [button addTarget:self
                       action:@selector(
                           sg_searchGlassPressed:
                       )
             forControlEvents:
                 UIControlEventTouchUpInside];


            [settingsView addSubview:button];

            [settingsView
                bringSubviewToFront:button];
        }
    );
}


%new

- (void)sg_searchGlassPressed:(id)sender
{
    /*
     ========================================================
     ANIMAÇÃO
     ========================================================
    */

    if ([sender isKindOfClass:
            [UIView class]])
    {
        UIView *button =
            (UIView *)sender;

        [UIView animateWithDuration:0.08
                         animations:^
        {
            button.transform =
                CGAffineTransformMakeScale(
                    0.96,
                    0.96
                );
        }
        completion:^(BOOL finished)
        {
            [UIView animateWithDuration:0.12
                             animations:^
            {
                button.transform =
                    CGAffineTransformIdentity;
            }];
        }];
    }


    /*
     ========================================================
     ABRIR BUSCA
     ========================================================
    */

    SGActivateSearch(self);
}


- (void)viewDidLayoutSubviews
{
    %orig;

    UIView *button =
        [self.view
            viewWithTag:SGButtonTag];

    if (!button)
        return;


    CGFloat width = 185.0;
    CGFloat height = 48.0;

    CGFloat bottom =
        self.view.safeAreaInsets.bottom;

    CGFloat x =
        (self.view.bounds.size.width -
         width) / 2.0;

    CGFloat y =
        self.view.bounds.size.height -
        bottom -
        height -
        14.0;


    button.frame =
        CGRectMake(
            x,
            y,
            width,
            height
        );
}

%end
