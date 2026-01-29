//
//  CreateHomeViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "CreateHomeViewController.h"
#import "HomeService.h"
#import "HomeManager.h"
#import "UIHelper.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CreateHomeViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) UITextField *nameTextField;
@property (nonatomic, strong) UITextField *cityTextField;
@property (nonatomic, strong) UIButton *createButton;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;

@end

@implementation CreateHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"创建家庭";
    
    // 默认坐标（可以后续通过定位获取）
    self.latitude = 0.0;
    self.longitude = 0.0;
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                                  target:self
                                                                                  action:@selector(closeButtonTapped:)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    [self setupUI];
    [self requestLocationPermission];
}

- (void)setupUI {
    // 家庭名称输入框
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = @"家庭名称";
    nameLabel.font = [UIFont systemFontOfSize:16];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:nameLabel];
    
    self.nameTextField = [[UITextField alloc] init];
    self.nameTextField.placeholder = @"请输入家庭名称";
    self.nameTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.nameTextField];
    
    // 城市输入框
    UILabel *cityLabel = [[UILabel alloc] init];
    cityLabel.text = @"城市";
    cityLabel.font = [UIFont systemFontOfSize:16];
    cityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:cityLabel];
    
    self.cityTextField = [[UITextField alloc] init];
    self.cityTextField.placeholder = @"请输入城市名称";
    self.cityTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.cityTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.cityTextField];
    
    // 创建按钮
    self.createButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.createButton setTitle:@"创建" forState:UIControlStateNormal];
    self.createButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.createButton.backgroundColor = [UIColor systemBlueColor];
    [self.createButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.createButton.layer.cornerRadius = 8;
    self.createButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.createButton addTarget:self action:@selector(createButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.createButton];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 家庭名称标签
        [nameLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [nameLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [nameLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        
        // 家庭名称输入框
        [self.nameTextField.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:10],
        [self.nameTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.nameTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.nameTextField.heightAnchor constraintEqualToConstant:50],
        
        // 城市标签
        [cityLabel.topAnchor constraintEqualToAnchor:self.nameTextField.bottomAnchor constant:30],
        [cityLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [cityLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        
        // 城市输入框
        [self.cityTextField.topAnchor constraintEqualToAnchor:cityLabel.bottomAnchor constant:10],
        [self.cityTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.cityTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.cityTextField.heightAnchor constraintEqualToConstant:50],
        
        // 创建按钮
        [self.createButton.topAnchor constraintEqualToAnchor:self.cityTextField.bottomAnchor constant:40],
        [self.createButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.createButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.createButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (void)requestLocationPermission {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    } else if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)createButtonTapped:(UIButton *)sender {
    NSString *name = [self.nameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *city = [self.cityTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 输入验证
    if (name.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入家庭名称"];
        return;
    }
    
    if (city.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入城市名称"];
        return;
    }
    
    // 禁用按钮，防止重复点击
    self.createButton.enabled = NO;
    [self.createButton setTitle:@"创建中..." forState:UIControlStateNormal];
    
    // 调用创建家庭服务
    [[HomeService sharedInstance] addHomeWithName:name
                                           geoName:city
                                             rooms:@[@""]  // 先创建空房间列表，后续可以添加
                                          latitude:self.latitude
                                         longitude:self.longitude
                                           success:^(id result) {
        // 创建成功
        dispatch_async(dispatch_get_main_queue(), ^{
            self.createButton.enabled = YES;
            [self.createButton setTitle:@"创建" forState:UIControlStateNormal];
            
            long long homeId = [result longLongValue];
            // 获取创建的家庭并设置为当前家庭
            ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
            if (home && home.homeModel) {
                [HomeManager setCurrentHome:home.homeModel];
            }
            
            [UIHelper showAlertInViewController:self title:@"成功" message:@"家庭创建成功" completion:^{
                if ([self.delegate respondsToSelector:@selector(createHomeViewController:didCreateHomeSuccess:)]) {
                    [self.delegate createHomeViewController:self didCreateHomeSuccess:YES];
                }
                [self dismissViewControllerAnimated:YES completion:nil];
            }];
        });
    } failure:^(NSError *error) {
        // 创建失败
        dispatch_async(dispatch_get_main_queue(), ^{
            self.createButton.enabled = YES;
            [self.createButton setTitle:@"创建" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"创建家庭失败，请重试";
            [UIHelper showAlertInViewController:self title:@"创建失败" message:errorMessage];
        });
    }];
}

- (void)closeButtonTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    self.latitude = location.coordinate.latitude;
    self.longitude = location.coordinate.longitude;
    [self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // 定位失败，使用默认坐标
    NSLog(@"定位失败: %@", error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)dealloc {
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
    }
}

@end
