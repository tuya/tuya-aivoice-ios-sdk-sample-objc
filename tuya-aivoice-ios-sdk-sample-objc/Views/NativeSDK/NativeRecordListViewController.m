//
//  NativeRecordListViewController.m
//  AIVoiceDemo
//

#import "NativeRecordListViewController.h"
#import "NativeAudioService.h"
#import "NativeRecordListCell.h"
#import "NativeRecordDetailViewController.h"
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

@interface NativeRecordListViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

/// 全量列表（非搜索模式）。
@property (nonatomic, copy) NSArray<ThingAudioRecordFile *> *records;
/// 搜索结果。
@property (nonatomic, copy) NSArray<ThingAudioRecordSearchMixResultItem *> *searchResults;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, strong) NSTimer *searchDebounceTimer;

@end

@implementation NativeRecordListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureFamilyNavigationWithTitle:@"录音列表"
                                   leftTitle:@"‹"
                                  leftAction:^{
        [self.navigationController popViewControllerAnimated:YES];
    }
                                  rightTitle:nil
                                 rightAction:nil];

    self.records = @[];
    self.searchResults = @[];
    self.isSearching = NO;

    [self setupUI];
    [self loadAllRecords];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.searchBar resignFirstResponder];
}

#pragma mark - UI

- (void)setupUI {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索录音名称、内容";
    self.searchBar.delegate = self;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleFamilyTableView:self.tableView];
    [self.tableView registerClass:[NativeRecordListCell class] forCellReuseIdentifier:[NativeRecordListCell reuseIdentifier]];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadAllRecords) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无录音\n去录音页录制吧";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = self.familySecondaryTextColor;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.hidden = YES;

    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.familyContentGuide.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.familyContentGuide.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.familyContentGuide.bottomAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-40],
    ]];
}

#pragma mark - Data

- (void)loadAllRecords {
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] fetchAllRecordsWithSuccess:^(NSArray<ThingAudioRecordFile *> *list) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.refreshControl endRefreshing];
        self.records = list ?: @[];
        self.isSearching = NO;
        [self.searchBar setText:nil];
        [self.tableView reloadData];
        [self updateEmptyState];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.refreshControl endRefreshing];
        [self showFamilyMessageWithTitle:@"加载失败" message:error.localizedDescription];
    }];
}

- (void)performSearch {
    NSString *keyword = self.searchBar.text;
    if (keyword.length == 0 || [keyword stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0) {
        // 关键词为空，退出搜索模式，展示全量列表。
        self.isSearching = NO;
        self.searchResults = @[];
        [self.tableView reloadData];
        [self updateEmptyState];
        return;
    }

    self.isSearching = YES;
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] searchRecordsWithKeyword:keyword success:^(NSArray<ThingAudioRecordSearchMixResultItem *> *list) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        // 搜索过程中用户可能已清空搜索框，二次确认。
        if (!self.isSearching) return;
        self.searchResults = list ?: @[];
        [self.tableView reloadData];
        [self updateEmptyState];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self showFamilyMessageWithTitle:@"搜索失败" message:error.localizedDescription];
    }];
}

- (void)updateEmptyState {
    NSInteger count = self.isSearching ? self.searchResults.count : self.records.count;
    self.emptyLabel.text = self.isSearching ? @"未找到匹配的录音" : @"暂无录音\n去录音页录制吧";
    self.emptyLabel.hidden = count > 0;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.4
                                                                 target:self
                                                               selector:@selector(performSearch)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self.searchDebounceTimer invalidate];
    [self performSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    searchBar.text = nil;
    self.isSearching = NO;
    self.searchResults = @[];
    [self.tableView reloadData];
    [self updateEmptyState];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isSearching ? self.searchResults.count : self.records.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NativeRecordListCell *cell = [tableView dequeueReusableCellWithIdentifier:[NativeRecordListCell reuseIdentifier]
                                                                forIndexPath:indexPath];
    if (self.isSearching) {
        if (indexPath.row < (NSInteger)self.searchResults.count) {
            [cell configureWithSearchItem:self.searchResults[indexPath.row]];
        }
    } else {
        if (indexPath.row < (NSInteger)self.records.count) {
            [cell configureWithRecordFile:self.records[indexPath.row]];
        }
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchBar resignFirstResponder];

    NSString *recordId = nil;
    if (self.isSearching) {
        if (indexPath.row < (NSInteger)self.searchResults.count) {
            recordId = self.searchResults[indexPath.row].recordId;
        }
    } else {
        if (indexPath.row < (NSInteger)self.records.count) {
            recordId = self.records[indexPath.row].recordId;
        }
    }
    if (recordId.length == 0) return;

    NativeRecordDetailViewController *detail = [[NativeRecordDetailViewController alloc] initWithRecordId:recordId];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
