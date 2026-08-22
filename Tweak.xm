#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <objc/message.h>

#pragma mark -
#pragma mark SearchGlass
#pragma mark -

static NSInteger const SGButtonTag = 987654;

@interface SearchGlassButton : UIButton

@property (nonatomic, strong) UIVisualEffectView *glassView;
@property (nonatomic, strong) UIView *highlightView;
@property (nonatomic, strong) UIImageView *searchIcon;
@property (nonatomic, strong) UILabel *searchLabel;
@property (nonatomic, strong) CAGradientLayer *reflectionLayer;
@property (nonatomic, strong) CAShapeLayer *borderLayer;

@end


@implementation SearchGlassButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self)
    {
        self.tag = SGButtonTag;

        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;

        self.layer.cornerRadius = 24.0;
        self.layer.masksToBounds = YES;


        /*
         =====================================================
         GLASS / BLUR
         =====================================================
         */

        UIBlurEffect *effect =
            [UIBlurEffect effectWithStyle:
                UIBlurEffectStyleSystemMaterial];

        self.glassView =
            [[UIVisualEffectView alloc]
                initWithEffect:effect];

        self.glassView.userInteractionEnabled = NO;

        [self addSubview:self.glassView];


        /*
         =====================================================
         HIGHLIGHT
         =====================================================
         */

        self.highlightView =
            [[UIView alloc]
                initWithFrame:CGRectZero];

        self.highlightView.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.035];

        self.highlightView.userInteractionEnabled = NO;

        [self addSubview:self.highlightView];


        /*
         =====================================================
         LUPA
         =====================================================
         */

        UIImage *image =
            [UIImage systemImageNamed:
                @"magnifyingglass"];

        self.searchIcon =
            [[UIImageView alloc]
                initWithImage:image];

        self.searchIcon.tintColor =
            UIColor.labelColor;

        self.searchIcon.contentMode =
            UIViewContentModeScaleAspectFit;

        self.searchIcon.userInteractionEnabled = NO;

        [self addSubview:self.searchIcon];


        /*
         =====================================================
         TEXTO
         =====================================================
         */

        self.searchLabel =
            [[UILabel alloc]
                initWithFrame:CGRectZero];

        self.searchLabel.text =
            @"Search";

        self.searchLabel.textColor =
            UIColor.labelColor;

        self.searchLabel.font =
            [UIFont systemFontOfSize:
                16.0
                  weight:UIFontWeightRegular];

        self.searchLabel.textAlignment =
            NSTextAlignmentLeft;

        self.searchLabel.userInteractionEnabled = NO;

        [self addSubview:self.searchLabel];


        /*
         =====================================================
         REFLECTION
         =====================================================
         */

        self.reflectionLayer =
            [CAGradientLayer layer];

        self.reflectionLayer.startPoint =
            CGPointMake(0.0, 0.0);

        self.reflectionLayer.endPoint =
            CGPointMake(1.0, 1.0);

        self.reflectionLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.42].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.14].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.0].CGColor,

            (id)[UIColor colorWithWhite:1.0
                                  alpha:0.13].CGColor
        ];

        self.reflectionLayer.locations = @[
            @0.0,
            @0.16,
            @0.60,
            @1.0
        ];

        self.reflectionLayer.cornerRadius =
            24.0;

        [self.layer addSublayer:
            self.reflectionLayer];


        /*
         =====================================================
         BORDA REFLETIVA
         =====================================================
         */

        self.borderLayer =
            [CAShapeLayer layer];

        self.borderLayer.fillColor =
            UIColor.clearColor.CGColor;

        self.borderLayer.strokeColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.42].CGColor;

        self.borderLayer.lineWidth =
            0.8;

        [self.layer addSublayer:
            self.borderLayer];


        /*
         =====================================================
         SOMBRA
         =====================================================
         */

        self.layer.shadowColor =
            UIColor.blackColor.CGColor;

        self.layer.shadowOpacity =
            0.10;

        self.layer.shadowRadius =
            8.0;

        self.layer.shadowOffset =
            CGSizeMake(0.0, 3.0);
    }

    return self;
}


#pragma mark -
#pragma mark Layout
#pragma mark -

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds =
        self.bounds;


    /*
     =====================================================
     GLASS
     =====================================================
     */

    self.glassView.frame =
        bounds;

    self.highlightView.frame =
        bounds;


    /*
     =====================================================
     LUPA
     =====================================================
     */

    CGFloat iconSize =
        22.0;

    CGFloat left =
        16.0;

    CGFloat iconY =
        (CGRectGetHeight(bounds) -
         iconSize) / 2.0;

    self.searchIcon.frame =
        CGRectMake(
            left,
            iconY,
            iconSize,
            iconSize
        );


    /*
     =====================================================
     TEXTO
     =====================================================
     */

    CGFloat textX =
        left +
        iconSize +
        10.0;

    CGFloat textWidth =
        CGRectGetWidth(bounds) -
        textX -
        12.0;

    self.searchLabel.frame =
        CGRectMake(
            textX,
            0.0,
            textWidth,
            CGRectGetHeight(bounds)
        );


    /*
     =====================================================
     REFLECTION
     =====================================================
     */

    self.reflectionLayer.frame =
        bounds;


    /*
     =====================================================
     BORDA
     =====================================================
     */

    self.borderLayer.frame =
        bounds;

    UIBezierPath *path =
        [UIBezierPath
            bezierPathWithRoundedRect:
                bounds
                         cornerRadius:24.0];

    self.borderLayer.path =
        path.CGPath;
}


#pragma mark -
#pragma mark Touch feedback
#pragma mark -

- (void)setHighlighted:(BOOL)highlighted
{
    [UIView animateWithDuration:0.08
                     animations:^
    {
        self.alpha =
            highlighted ? 0.72 : 1.0;

        self.transform =
            highlighted
                ? CGAffineTransformMakeScale(
                    0.965,
                    0.965
                  )
                : CGAffineTransformIdentity;
    }];
}

@end


#pragma mark -
#pragma mark Search Finder
#pragma mark -

static UIView *SGFindSearchView(UIView *view)
{
    if (!view)
        return nil;


    if ([view isKindOfClass:
            [UISearchBar class]])
    {
        return view;
    }


    if ([view isKindOfClass:
            [UISearchTextField class]])
    {
        return view;
    }


    for (UIView *subview in view.subviews)
    {
        UIView *result =
            SGFindSearchView(subview);

        if (result)
            return result;
    }


    return nil;
}


#pragma mark -
#pragma mark Activate Settings Search
#pragma mark -

static void SGActivateSearch(
    UIViewController *controller
)
{
    if (!controller)
        return;


    /*
     =====================================================
     PROCURA SEARCHBAR
     =====================================================
     */

    UIView *search =
        SGFindSearchView(
            controller.view
        );


    if ([search isKindOfClass:
            [UISearchBar class]])
    {
        UISearchBar *bar =
            (UISearchBar *)search;

        [bar becomeFirstResponder];

        return;
    }


    if ([search isKindOfClass:
            [UISearchTextField class]])
    {
        UISearchTextField *field =
            (UISearchTextField *)search;

        [field becomeFirstResponder];

        return;
    }


    /*
     =====================================================
     PROCURA NOS PARENTS
     =====================================================
     */

    UIViewController *parent =
        controller.parentViewController;


    while (parent)
    {
        UIView *found =
            SGFindSearchView(
                parent.view
            );


        if ([found isKindOfClass:
                [UISearchBar class]])
        {
            [(UISearchBar *)found
                becomeFirstResponder];

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
     =====================================================
     TENTA SELETORES EM RUNTIME
     =====================================================
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
        if ([current
             respondsToSelector:selectors[i]])
        {
            typedef void (*MessageSend)(
                id,
                SEL
            );


            MessageSend send =
                (MessageSend)objc_msgSend;


            send(
                current,
                selectors[i]
            );


            return;
        }


        current =
            current.parentViewController;


        if (!current)
            break;
    }


    /*
     =====================================================
     TENTA NOVAMENTE DEPOIS DO LAYOUT
     =====================================================
     */

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(
                0.20 *
                NSEC_PER_SEC
            )
        ),
        dispatch_get_main_queue(),
        ^
        {
            UIView *found =
                SGFindSearchView(
                    controller.view
                );


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
#pragma mark Preferences
#pragma mark -

%hook PSListController


- (void)viewDidAppear:(BOOL)animated
{
    %orig;


    dispatch_async(
        dispatch_get_main_queue(),
        ^
        {
            UIView *view =
                self.view;


            if (!view)
                return;


            /*
             =================================================
             NÃO DUPLICAR
             =================================================
             */

            UIView *existing =
                [view
                    viewWithTag:SGButtonTag];


            if (existing)
                return;


            /*
             =================================================
             TAMANHO
             =================================================
             */

            CGFloat width =
                185.0;

            CGFloat height =
                48.0;


            /*
             =================================================
             POSIÇÃO
             =================================================
             */

            CGFloat bottom =
                view.safeAreaInsets.bottom;


            CGFloat x =
                (view.bounds.size.width -
                 width) / 2.0;


            CGFloat y =
                view.bounds.size.height -
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
             AÇÃO DO BOTÃO
             =================================================
             */

            [button addTarget:self
                       action:@selector(
                           sg_searchGlassPressed:
                       )
             forControlEvents:
                 UIControlEventTouchUpInside];


            [view addSubview:button];


            [view
                bringSubviewToFront:button];
        }
    );
}


%new

- (void)sg_searchGlassPressed:(id)sender
{
    /*
     =====================================================
     ANIMAÇÃO
     =====================================================
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
     =====================================================
     ABRIR PESQUISA
     =====================================================
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


    CGFloat width =
        185.0;

    CGFloat height =
        48.0;


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
