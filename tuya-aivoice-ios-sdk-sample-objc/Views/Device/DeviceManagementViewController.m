#import "DeviceManagementViewController.h"
#import "DeviceService.h"

@interface DeviceManagementViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<ThingSmartDeviceModel *> *devices;
@end

@implementation DeviceManagementViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureFamilyNavigationWithTitle:@"设备管理" leftTitle:nil leftAction:nil rightTitle:@"刷新" rightAction:^{ [self loadDevices]; }];
    self.devices = @[];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [self styleFamilyTableView:self.tableView];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.familyContentGuide.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self loadDevices]; }

- (void)loadDevices {
    [[DeviceService sharedInstance] getDeviceListWithSuccess:^(NSArray<ThingSmartDeviceModel *> *devices) {
        self.devices = devices ?: @[];
        [self.tableView reloadData];
    } failure:^(NSError *error) {
        [self showFamilyMessageWithTitle:@"加载设备失败" message:error.localizedDescription ?: @"请稍后重试"];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.devices.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.devices.count > 0 ? [NSString stringWithFormat:@"%lu 台设备", (unsigned long)self.devices.count] : @"暂无设备"; }
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [UILabel new];
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    label.textColor = [self familySecondaryTextColor];
    label.frame = CGRectMake(0, 0, tableView.bounds.size.width, 28);
    return label;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self dequeueFamilyCardCellFromTableView:tableView style:UITableViewCellStyleValue1 identifier:@"ManagedDeviceCell"];
    ThingSmartDeviceModel *device = self.devices[indexPath.row];
    cell.textLabel.text = device.name.length > 0 ? device.name : @"未命名设备";
    cell.detailTextLabel.text = device.isOnline ? @"在线" : @"离线";
    cell.detailTextLabel.textColor = device.isOnline ? [UIColor colorWithRed:0.12 green:0.62 blue:0.34 alpha:1.0] : [self familySecondaryTextColor];
    UILabel *chevron = [UILabel new]; chevron.text = @"›"; chevron.font = [UIFont systemFontOfSize:30]; chevron.textColor = [self familySecondaryTextColor]; chevron.frame = CGRectMake(0, 0, 18, 32);
    cell.accessoryView = chevron;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ThingSmartDeviceModel *device = self.devices[indexPath.row];
    __weak typeof(self) weakSelf = self;
    FamilyUIAction *rename = [FamilyUIAction actionWithTitle:@"修改设备名称" handler:^{ [weakSelf renameDevice:device]; }];
    FamilyUIAction *remove = [FamilyUIAction destructiveActionWithTitle:@"删除设备" handler:^{ [weakSelf confirmRemoveDevice:device]; }];
    [self showFamilyActionSheetWithTitle:device.name.length > 0 ? device.name : @"设备" message:device.devId ?: @"" actions:@[rename, remove]];
}

- (void)renameDevice:(ThingSmartDeviceModel *)device {
    __weak typeof(self) weakSelf = self;
    [self showFamilyInputDialogWithTitle:@"设备名称" message:nil placeholders:@[@"请输入设备名称"] initialValues:@[device.name ?: @""] keyboardTypes:nil confirmTitle:@"保存" confirm:^(NSArray<NSString *> *values) {
        [[DeviceService sharedInstance] renameDevice:device toName:values.firstObject success:^{ [weakSelf loadDevices]; } failure:^(NSError *error) { [weakSelf showFamilyMessageWithTitle:@"保存失败" message:error.localizedDescription ?: @""]; }];
    }];
}

- (void)confirmRemoveDevice:(ThingSmartDeviceModel *)device {
    __weak typeof(self) weakSelf = self;
    [self showFamilyConfirmationWithTitle:@"删除设备？" message:@"设备将从当前家庭解除绑定。" confirmTitle:@"删除" destructive:YES confirm:^{
        [[DeviceService sharedInstance] removeDevice:device success:^{ [weakSelf loadDevices]; } failure:^(NSError *error) { [weakSelf showFamilyMessageWithTitle:@"删除失败" message:error.localizedDescription ?: @""]; }];
    }];
}

@end
