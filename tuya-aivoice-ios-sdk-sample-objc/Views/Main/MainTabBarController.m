//
//  MainTabBarController.m
//  AIVoiceDemo
//

#import "MainTabBarController.h"
#import "MainViewController.h"
#import "MineViewController.h"

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    MainViewController *homeVC = [[MainViewController alloc] init];
    homeVC.title = @"首页";
    UINavigationController *homeNav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"首页" image:[UIImage systemImageNamed:@"house"] tag:0];
    if (@available(iOS 13.0, *)) {
        homeNav.tabBarItem.selectedImage = [UIImage systemImageNamed:@"house.fill"];
    }

    MineViewController *mineVC = [[MineViewController alloc] init];
    mineVC.title = @"我的";
    UINavigationController *mineNav = [[UINavigationController alloc] initWithRootViewController:mineVC];
    mineNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"我的" image:[UIImage systemImageNamed:@"person"] tag:1];
    if (@available(iOS 13.0, *)) {
        mineNav.tabBarItem.selectedImage = [UIImage systemImageNamed:@"person.fill"];
    }

    self.viewControllers = @[ homeNav, mineNav ];
}

@end
