//
//  Shared custom UI base implementation.
//  tuya-aivoice-ios-sdk-sample-objc
//

#import "FamilyBaseViewController.h"

@interface FamilyBlockButton : UIButton
@property (nonatomic, copy, nullable) FamilyUIActionHandler tapHandler;
@end

@implementation FamilyBlockButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)didTap {
    if (self.tapHandler) {
        self.tapHandler();
    }
}

@end

/// The table view owns horizontal page margins; this cell owns only the
/// vertical breathing room around its white card. Keeping these concerns
/// separate prevents accessory views from escaping the card on narrow screens.
@interface FamilyCardTableViewCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@end

@implementation FamilyCardTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
        self.preservesSuperviewLayoutMargins = NO;

        _cardView = [UIView new];
        _cardView.backgroundColor = UIColor.whiteColor;
        _cardView.layer.cornerRadius = 20;
        _cardView.layer.masksToBounds = YES;
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView insertSubview:_cardView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
        ]];
    }
    return self;
}

@end

@interface FamilyUIAction ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, assign, readwrite, getter=isDestructive) BOOL destructive;
@property (nonatomic, copy, readwrite, nullable) FamilyUIActionHandler handler;
@end

@implementation FamilyUIAction

+ (instancetype)actionWithTitle:(NSString *)title handler:(FamilyUIActionHandler)handler {
    return [self actionWithTitle:title destructive:NO handler:handler];
}

+ (instancetype)destructiveActionWithTitle:(NSString *)title handler:(FamilyUIActionHandler)handler {
    return [self actionWithTitle:title destructive:YES handler:handler];
}

+ (instancetype)actionWithTitle:(NSString *)title destructive:(BOOL)destructive handler:(FamilyUIActionHandler)handler {
    FamilyUIAction *action = [FamilyUIAction new];
    action.title = title;
    action.destructive = destructive;
    action.handler = handler;
    return action;
}

@end

@interface FamilyBaseViewController ()
@property (nonatomic, strong, readwrite) UILayoutGuide *familyContentGuide;
@property (nonatomic, strong, readwrite) UIButton *familyNavigationRightButton;
@property (nonatomic, strong) UIView *familyNavigationBar;
@property (nonatomic, strong) UILabel *familyNavigationTitleLabel;
@property (nonatomic, strong) UIButton *familyNavigationLeftButton;
@property (nonatomic, copy, nullable) FamilyUIActionHandler leftNavigationAction;
@property (nonatomic, copy, nullable) FamilyUIActionHandler rightNavigationAction;
@property (nonatomic, strong, nullable) UIView *activeOverlay;
@property (nonatomic, strong, nullable) UIView *activeOverlayCard;
@end

@implementation FamilyBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self familyBackgroundColor];
    [self installFamilyNavigation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    UIViewController *next = self.navigationController.topViewController;
    if (![next isKindOfClass:FamilyBaseViewController.class]) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

- (void)installFamilyNavigation {
    self.familyNavigationBar = [UIView new];
    self.familyNavigationBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.familyNavigationBar.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.familyNavigationBar];

    self.familyNavigationLeftButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.familyNavigationLeftButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.familyNavigationLeftButton setTitleColor:[self familyPrimaryTextColor] forState:UIControlStateNormal];
    [self.familyNavigationLeftButton addTarget:self action:@selector(familyLeftButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.familyNavigationLeftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.familyNavigationLeftButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.familyNavigationBar addSubview:self.familyNavigationLeftButton];

    self.familyNavigationTitleLabel = [UILabel new];
    self.familyNavigationTitleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.familyNavigationTitleLabel.textColor = [self familyPrimaryTextColor];
    self.familyNavigationTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.familyNavigationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.familyNavigationBar addSubview:self.familyNavigationTitleLabel];

    self.familyNavigationRightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.familyNavigationRightButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.familyNavigationRightButton setTitleColor:[self familyAccentColor] forState:UIControlStateNormal];
    [self.familyNavigationRightButton addTarget:self action:@selector(familyRightButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.familyNavigationRightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    self.familyNavigationRightButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.familyNavigationBar addSubview:self.familyNavigationRightButton];

    self.familyContentGuide = [UILayoutGuide new];
    [self.view addLayoutGuide:self.familyContentGuide];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.familyNavigationBar.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.familyNavigationBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.familyNavigationBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.familyNavigationBar.heightAnchor constraintEqualToConstant:56],
        [self.familyNavigationLeftButton.leadingAnchor constraintEqualToAnchor:self.familyNavigationBar.leadingAnchor],
        [self.familyNavigationLeftButton.centerYAnchor constraintEqualToAnchor:self.familyNavigationBar.centerYAnchor],
        [self.familyNavigationLeftButton.widthAnchor constraintGreaterThanOrEqualToConstant:50],
        [self.familyNavigationLeftButton.heightAnchor constraintEqualToConstant:44],
        [self.familyNavigationRightButton.trailingAnchor constraintEqualToAnchor:self.familyNavigationBar.trailingAnchor],
        [self.familyNavigationRightButton.centerYAnchor constraintEqualToAnchor:self.familyNavigationBar.centerYAnchor],
        [self.familyNavigationRightButton.widthAnchor constraintGreaterThanOrEqualToConstant:50],
        [self.familyNavigationRightButton.heightAnchor constraintEqualToConstant:44],
        [self.familyNavigationTitleLabel.centerXAnchor constraintEqualToAnchor:self.familyNavigationBar.centerXAnchor],
        [self.familyNavigationTitleLabel.centerYAnchor constraintEqualToAnchor:self.familyNavigationBar.centerYAnchor],
        [self.familyNavigationTitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.familyNavigationLeftButton.trailingAnchor constant:8],
        [self.familyNavigationTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.familyNavigationRightButton.leadingAnchor constant:-8],
        [self.familyContentGuide.topAnchor constraintEqualToAnchor:self.familyNavigationBar.bottomAnchor constant:4],
        [self.familyContentGuide.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.familyContentGuide.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.familyContentGuide.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
    ]];
}

- (void)configureFamilyNavigationWithTitle:(NSString *)title leftTitle:(NSString *)leftTitle leftAction:(FamilyUIActionHandler)leftAction rightTitle:(NSString *)rightTitle rightAction:(FamilyUIActionHandler)rightAction {
    self.familyNavigationTitleLabel.text = title;
    self.leftNavigationAction = leftAction;
    self.rightNavigationAction = rightAction;
    NSString *resolvedLeftTitle = leftTitle ?: @"‹";
    [self.familyNavigationLeftButton setTitle:resolvedLeftTitle forState:UIControlStateNormal];
    self.familyNavigationLeftButton.titleLabel.font = [UIFont systemFontOfSize:[resolvedLeftTitle isEqualToString:@"‹"] ? 42 : 17 weight:[resolvedLeftTitle isEqualToString:@"‹"] ? UIFontWeightRegular : UIFontWeightSemibold];
    [self.familyNavigationRightButton setTitle:rightTitle ?: @"" forState:UIControlStateNormal];
    self.familyNavigationRightButton.hidden = rightTitle.length == 0;
}

- (void)setFamilyNavigationRightEnabled:(BOOL)enabled {
    self.familyNavigationRightButton.enabled = enabled;
    self.familyNavigationRightButton.alpha = enabled ? 1.0 : 0.35;
}

- (void)familyLeftButtonTapped {
    if (self.leftNavigationAction) {
        self.leftNavigationAction();
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)familyRightButtonTapped {
    if (self.rightNavigationAction) {
        self.rightNavigationAction();
    }
}

- (void)styleFamilyTableView:(UITableView *)tableView {
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.contentInset = UIEdgeInsetsMake(10, 0, 28, 0);
    tableView.sectionHeaderHeight = 28;
    tableView.sectionFooterHeight = 14;
    tableView.rowHeight = 82;
    tableView.estimatedRowHeight = 82;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
}

- (void)styleFamilyCell:(UITableViewCell *)cell {
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = [self familyPrimaryTextColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [self familySecondaryTextColor];
    cell.tintColor = [self familyAccentColor];
}

- (UITableViewCell *)dequeueFamilyCardCellFromTableView:(UITableView *)tableView style:(UITableViewCellStyle)style identifier:(NSString *)identifier {
    FamilyCardTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[FamilyCardTableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
    }
    [self styleFamilyCell:cell];
    return cell;
}

- (void)styleFamilyPrimaryButton:(UIButton *)button {
    button.backgroundColor = [self familyAccentColor];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    button.layer.cornerRadius = 16;
    button.layer.masksToBounds = YES;
}

- (void)showFamilyMessageWithTitle:(NSString *)title message:(NSString *)message {
    [self showFamilyMessageWithTitle:title message:message completion:nil];
}

- (void)showFamilyMessageWithTitle:(NSString *)title message:(NSString *)message completion:(FamilyUIActionHandler)completion {
    UIView *card = [self dialogCardWithTitle:title message:message];
    UIButton *confirmButton = [self dialogButtonWithTitle:@"知道了" textColor:[self familyAccentColor]];
    __weak typeof(self) weakSelf = self;
    ((FamilyBlockButton *)confirmButton).tapHandler = ^{
        [weakSelf dismissFamilyOverlay];
        if (completion) { completion(); }
    };
    confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:confirmButton];
    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:(message.length > 0 ? 178 : 138)],
        [confirmButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [confirmButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [confirmButton.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [confirmButton.heightAnchor constraintEqualToConstant:56],
    ]];
    [self presentFamilyOverlayWithCard:card bottomSheet:NO];
}

- (void)showFamilyConfirmationWithTitle:(NSString *)title message:(NSString *)message confirmTitle:(NSString *)confirmTitle destructive:(BOOL)destructive confirm:(FamilyUIActionHandler)confirm {
    UIView *card = [self dialogCardWithTitle:title message:message];
    UIButton *cancel = [self dialogButtonWithTitle:@"取消" textColor:[self familySecondaryTextColor]];
    UIButton *confirmButton = [self dialogButtonWithTitle:confirmTitle textColor:(destructive ? [self familyDestructiveColor] : [self familyAccentColor])];
    [cancel addTarget:self action:@selector(dismissFamilyOverlay) forControlEvents:UIControlEventTouchUpInside];
    __weak typeof(self) weakSelf = self;
    ((FamilyBlockButton *)confirmButton).tapHandler = ^{
        [weakSelf dismissFamilyOverlay];
        if (confirm) { confirm(); }
    };
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, confirmButton]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 1;
    buttons.backgroundColor = [self familyHairlineColor];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:(message.length > 0 ? 178 : 138)],
        [buttons.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [buttons.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [buttons.heightAnchor constraintEqualToConstant:56],
    ]];
    [self presentFamilyOverlayWithCard:card bottomSheet:NO];
}

- (void)showFamilyActionSheetWithTitle:(NSString *)title message:(NSString *)message actions:(NSArray<FamilyUIAction *> *)actions {
    UIView *card = [UIView new];
    card.backgroundColor = [self familyCardColor];
    card.layer.cornerRadius = 28;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    if (title.length > 0) {
        UILabel *titleLabel = [UILabel new];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        titleLabel.textColor = [self familyPrimaryTextColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.numberOfLines = 0;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:titleLabel];
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    }
    if (message.length > 0) {
        UILabel *messageLabel = [UILabel new];
        messageLabel.text = message;
        messageLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        messageLabel.textColor = [self familySecondaryTextColor];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.numberOfLines = 0;
        messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:messageLabel];
        [messageLabel.heightAnchor constraintGreaterThanOrEqualToConstant:30].active = YES;
    }
    for (FamilyUIAction *action in actions) {
        FamilyBlockButton *button = [FamilyBlockButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:action.title forState:UIControlStateNormal];
        [button setTitleColor:(action.isDestructive ? [self familyDestructiveColor] : [self familyPrimaryTextColor]) forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        __weak typeof(self) weakSelf = self;
        button.tapHandler = ^{
            [weakSelf dismissFamilyOverlay];
            if (action.handler) { action.handler(); }
        };
        [stack addArrangedSubview:button];
        [button.heightAnchor constraintEqualToConstant:56].active = YES;
    }
    UIView *divider = [UIView new];
    divider.backgroundColor = [self familyBackgroundColor];
    [stack addArrangedSubview:divider];
    [divider.heightAnchor constraintEqualToConstant:8].active = YES;
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancel setTitle:@"取消" forState:UIControlStateNormal];
    [cancel setTitleColor:[self familySecondaryTextColor] forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [cancel addTarget:self action:@selector(dismissFamilyOverlay) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:cancel];
    [cancel.heightAnchor constraintEqualToConstant:62].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10],
    ]];
    [self presentFamilyOverlayWithCard:card bottomSheet:YES];
}

- (void)showFamilyInputDialogWithTitle:(NSString *)title message:(NSString *)message placeholders:(NSArray<NSString *> *)placeholders initialValues:(NSArray<NSString *> *)initialValues keyboardTypes:(NSArray<NSNumber *> *)keyboardTypes confirmTitle:(NSString *)confirmTitle confirm:(FamilyUIInputHandler)confirm {
    UIView *card = [self dialogCardWithTitle:title message:message];
    UIStackView *fieldsStack = [UIStackView new];
    fieldsStack.axis = UILayoutConstraintAxisVertical;
    fieldsStack.spacing = 10;
    fieldsStack.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableArray<UITextField *> *fields = [NSMutableArray array];
    for (NSUInteger index = 0; index < placeholders.count; index++) {
        UITextField *field = [UITextField new];
        field.placeholder = placeholders[index];
        field.text = index < initialValues.count ? initialValues[index] : @"";
        field.font = [UIFont systemFontOfSize:16];
        field.textColor = [self familyPrimaryTextColor];
        field.backgroundColor = [self familyBackgroundColor];
        field.layer.cornerRadius = 12;
        field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
        field.leftViewMode = UITextFieldViewModeAlways;
        field.keyboardType = index < keyboardTypes.count ? keyboardTypes[index].integerValue : UIKeyboardTypeDefault;
        [fieldsStack addArrangedSubview:field];
        [field.heightAnchor constraintEqualToConstant:48].active = YES;
        [fields addObject:field];
    }
    [card addSubview:fieldsStack];
    UIButton *cancel = [self dialogButtonWithTitle:@"取消" textColor:[self familySecondaryTextColor]];
    UIButton *confirmButton = [self dialogButtonWithTitle:confirmTitle textColor:[self familyAccentColor]];
    [cancel addTarget:self action:@selector(dismissFamilyOverlay) forControlEvents:UIControlEventTouchUpInside];
    __weak typeof(self) weakSelf = self;
    ((FamilyBlockButton *)confirmButton).tapHandler = ^{
        NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:fields.count];
        for (UITextField *field in fields) {
            NSString *value = [field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            [values addObject:value ?: @""];
        }
        [weakSelf dismissFamilyOverlay];
        if (confirm) { confirm(values); }
    };
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, confirmButton]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 1;
    buttons.backgroundColor = [self familyHairlineColor];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [fieldsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [fieldsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [fieldsStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:(message.length > 0 ? 96 : 62)],
        [buttons.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [buttons.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [buttons.topAnchor constraintEqualToAnchor:fieldsStack.bottomAnchor constant:20],
        [buttons.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [buttons.heightAnchor constraintEqualToConstant:56],
    ]];
    [self presentFamilyOverlayWithCard:card bottomSheet:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(familyKeyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (UIView *)dialogCardWithTitle:(NSString *)title message:(NSString *)message {
    UIView *card = [UIView new];
    card.backgroundColor = [self familyCardColor];
    card.layer.cornerRadius = 24;
    card.layer.masksToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.textColor = [self familyPrimaryTextColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
    ]];
    if (message.length > 0) {
        UILabel *messageLabel = [UILabel new];
        messageLabel.text = message;
        messageLabel.font = [UIFont systemFontOfSize:14];
        messageLabel.textColor = [self familySecondaryTextColor];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.numberOfLines = 0;
        messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:messageLabel];
        [NSLayoutConstraint activateConstraints:@[
            [messageLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
            [messageLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
            [messageLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        ]];
    }
    return card;
}

- (UIButton *)dialogButtonWithTitle:(NSString *)title textColor:(UIColor *)color {
    FamilyBlockButton *button = [FamilyBlockButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [self familyCardColor];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    return button;
}

- (void)presentFamilyOverlayWithCard:(UIView *)card bottomSheet:(BOOL)bottomSheet {
    [self dismissFamilyOverlay];
    UIView *overlay = [UIView new];
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    overlay.alpha = 0;
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:overlay];
    [overlay addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [card.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:(bottomSheet ? 0 : 30)],
        [card.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:(bottomSheet ? 0 : -30)],
    ]];
    NSLayoutConstraint *verticalConstraint;
    if (bottomSheet) {
        verticalConstraint = [card.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor];
    } else {
        verticalConstraint = [card.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor];
    }
    verticalConstraint.active = YES;
    self.activeOverlay = overlay;
    self.activeOverlayCard = card;
    card.transform = bottomSheet ? CGAffineTransformMakeTranslation(0, 360) : CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.24 animations:^{
        overlay.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismissFamilyOverlay {
    UIView *overlay = self.activeOverlay;
    if (!overlay) {
        return;
    }
    self.activeOverlay = nil;
    self.activeOverlayCard = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [UIView animateWithDuration:0.18 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (void)familyKeyboardWillChange:(NSNotification *)notification {
    UIView *card = self.activeOverlayCard;
    if (!card) {
        return;
    }
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(card.frame) - CGRectGetMinY(keyboardInView) + 18;
    CGFloat offset = MAX(0, overlap);
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        card.transform = offset > 0 ? CGAffineTransformMakeTranslation(0, -offset) : CGAffineTransformIdentity;
    } completion:nil];
}

- (UIColor *)familyBackgroundColor { return [UIColor colorWithRed:0.965 green:0.972 blue:0.988 alpha:1.0]; }
- (UIColor *)familyCardColor { return UIColor.whiteColor; }
- (UIColor *)familyPrimaryTextColor { return [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0]; }
- (UIColor *)familySecondaryTextColor { return [UIColor colorWithRed:0.53 green:0.55 blue:0.60 alpha:1.0]; }
- (UIColor *)familyAccentColor { return [UIColor colorWithRed:1.0 green:0.33 blue:0.17 alpha:1.0]; }
- (UIColor *)familyDestructiveColor { return [UIColor colorWithRed:0.95 green:0.22 blue:0.22 alpha:1.0]; }
- (UIColor *)familyHairlineColor { return [UIColor colorWithRed:0.92 green:0.93 blue:0.95 alpha:1.0]; }

@end
