#import "ITXEntryView.h"

@interface ITXEntryView ()
@property (nonatomic, copy) void (^handler)(void);
@end

@implementation ITXEntryView

+ (instancetype)entryWithHandler:(void (^)(void))handler {
    ITXEntryView *view = [[self alloc] initWithFrame:CGRectMake(0, 0, 0, 68)];
    view.handler = handler;
    [view build];
    return view;
}

- (void)build {
    self.backgroundColor = [UIColor clearColor];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 10;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:card];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"增强设置";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [UIColor labelColor];
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"去广告 · 自动签到 · 功能优化";
    subtitle.font = [UIFont systemFontOfSize:11.5];
    subtitle.textColor = [UIColor secondaryLabelColor];
    [card addSubview:subtitle];

    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.tintColor = [UIColor tertiaryLabelColor];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:arrow];

    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [card.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [card.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],

        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [title.centerYAnchor constraintEqualToAnchor:card.centerYAnchor constant:-8],

        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],

        [arrow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:12],
        [arrow.heightAnchor constraintEqualToConstant:16],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [card addGestureRecognizer:tap];
    card.userInteractionEnabled = YES;
}

- (void)onTap {
    if (self.handler) self.handler();
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // tableFooterView 的宽度由 table 决定，这里保证至少撑满
    CGFloat width = CGRectGetWidth(self.superview.bounds);
    if (width > 0 && fabs(CGRectGetWidth(self.frame) - width) > 0.5) {
        CGRect frame = self.frame;
        frame.size.width = width;
        frame.size.height = 68;
        self.frame = frame;
    }
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize {
    return CGSizeMake(targetSize.width, 68);
}

@end
