//
//  MainTabBarController.m
//  AIVoiceDemo
//

#import "MainTabBarController.h"
#import "MainViewController.h"
#import "MineViewController.h"
#import "NativeSDKViewController.h"

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    // TabBar 纯白不透明背景，避免页面内容透出。
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = UIColor.whiteColor;
    appearance.shadowColor = [UIColor colorWithWhite:0 alpha:0.08];
    self.tabBar.standardAppearance = appearance;
    self.tabBar.scrollEdgeAppearance = appearance;

    MainViewController *homeVC = [[MainViewController alloc] init];
    homeVC.title = @"首页";
    UINavigationController *homeNav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"首页" image:[UIImage systemImageNamed:@"house"] tag:0];
    if (@available(iOS 13.0, *)) {
        homeNav.tabBarItem.selectedImage = [UIImage systemImageNamed:@"house.fill"];
    }

    NativeSDKViewController *sdkVC = [[NativeSDKViewController alloc] init];
    sdkVC.title = @"Native SDK";
    UINavigationController *sdkNav = [[UINavigationController alloc] initWithRootViewController:sdkVC];
    sdkNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"SDK" image:[UIImage systemImageNamed:@"waveform"] tag:1];

    MineViewController *mineVC = [[MineViewController alloc] init];
    mineVC.title = @"我的";
    UINavigationController *mineNav = [[UINavigationController alloc] initWithRootViewController:mineVC];
    mineNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"我的" image:[UIImage systemImageNamed:@"person"] tag:2];
    if (@available(iOS 13.0, *)) {
        mineNav.tabBarItem.selectedImage = [UIImage systemImageNamed:@"person.fill"];
    }

    self.viewControllers = @[ homeNav, sdkNav, mineNav ];
}

@end
