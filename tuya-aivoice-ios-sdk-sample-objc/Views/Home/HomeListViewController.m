//
//  HomeListViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "HomeListViewController.h"
#import "HomeService.h"
#import "HomeManager.h"
#import "CreateHomeViewController.h"
#import "UIHelper.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

@interface HomeListViewController () <UITableViewDataSource, UITableViewDelegate, CreateHomeViewControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<ThingSmartHomeModel *> *homeList;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@end

@implementation HomeListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"我的家庭";
    
    [self setupUI];
    [self loadHomeList];
}

- (void)setupUI {
    // 创建家庭按钮
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                target:self
                                                                                action:@selector(addHomeButtonTapped:)];
    self.navigationItem.rightBarButtonItem = addButton;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // 下拉刷新
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshHomeList) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)loadHomeList {
    [[HomeService sharedInstance] getHomeListWithSuccess:^(id result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.homeList = (NSArray<ThingSmartHomeModel *> *)result;
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
            
            // 如果列表为空，显示提示
            if (self.homeList.count == 0) {
                [self showEmptyState];
            } else {
                [self hideEmptyState];
                // 自动选择第一个家庭作为当前家庭
                if ([HomeManager getCurrentHome] == nil) {
                    [HomeManager setCurrentHome:self.homeList.firstObject];
                }
            }
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            NSString *errorMessage = error.localizedDescription ?: @"获取家庭列表失败";
            [UIHelper showAlertInViewController:self title:@"提示" message:errorMessage];
        });
    }];
}

- (void)refreshHomeList {
    [self loadHomeList];
}

- (void)addHomeButtonTapped:(UIBarButtonItem *)sender {
    CreateHomeViewController *createHomeVC = [[CreateHomeViewController alloc] init];
    createHomeVC.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:createHomeVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)showEmptyState {
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.text = @"暂无家庭\n点击右上角 + 号创建家庭";
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.numberOfLines = 0;
    emptyLabel.textColor = [UIColor secondaryLabelColor];
    emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    emptyLabel.tag = 999;
    [self.view addSubview:emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)hideEmptyState {
    UIView *emptyView = [self.view viewWithTag:999];
    [emptyView removeFromSuperview];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.homeList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"HomeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    ThingSmartHomeModel *home = self.homeList[indexPath.row];
    cell.textLabel.text = home.name;
    cell.detailTextLabel.text = home.geoName ?: @"未设置位置";
    
    // 标记当前家庭
    ThingSmartHomeModel *currentHome = [HomeManager getCurrentHome];
    if (currentHome && currentHome.homeId == home.homeId) {
        cell.textLabel.textColor = [UIColor systemBlueColor];
    } else {
        cell.textLabel.textColor = [UIColor labelColor];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    ThingSmartHomeModel *home = self.homeList[indexPath.row];
    [HomeManager setCurrentHome:home];
    
    [self.tableView reloadData];
    
    // TODO: 跳转到家庭详情页面
    [UIHelper showAlertInViewController:self title:@"提示" message:[NSString stringWithFormat:@"已切换到家庭: %@", home.name]];
}

#pragma mark - CreateHomeViewControllerDelegate

- (void)createHomeViewController:(CreateHomeViewController *)controller didCreateHomeSuccess:(BOOL)success {
    if (success) {
        // 刷新家庭列表
        [self loadHomeList];
    }
}

@end
