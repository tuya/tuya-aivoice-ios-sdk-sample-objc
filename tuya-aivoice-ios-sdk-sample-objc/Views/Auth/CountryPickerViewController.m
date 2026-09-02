//
//  CountryPickerViewController.m
//  AIVoiceDemo
//

#import "CountryPickerViewController.h"

static NSString * const kCountryCellIdentifier = @"CountryCell";

@interface CountryPickerViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
/** 当前展示的分组：无搜索词时为全部大区，有搜索词时为单个"搜索结果"分组 */
@property (nonatomic, copy) NSArray<CountryGroup *> *displayGroups;

@end

@implementation CountryPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"选择国家/地区";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.displayGroups = [CountryModel allGroups];

    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(cancelTapped:)];

    [self setupUI];
}

- (void)setupUI {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索国家名称或国家码";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],

        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:4],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)cancelTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 搜索

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *keyword = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (keyword.length == 0) {
        self.displayGroups = [CountryModel allGroups];
    } else {
        NSMutableArray<CountryModel *> *matched = [NSMutableArray array];
        for (CountryModel *country in [CountryModel allCountries]) {
            BOOL hit = [country.name localizedCaseInsensitiveContainsString:keyword]
                    || [country.englishName localizedCaseInsensitiveContainsString:keyword]
                    || [country.countryCode hasPrefix:keyword]
                    || [country.isoCode localizedCaseInsensitiveContainsString:keyword];
            if (hit) {
                [matched addObject:country];
            }
        }
        self.displayGroups = @[[CountryGroup groupWithTitle:@"搜索结果" countries:matched]];
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.displayGroups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayGroups[section].countries.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.displayGroups[section].title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCountryCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kCountryCellIdentifier];
    }
    CountryModel *country = self.displayGroups[indexPath.section].countries[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", country.flag, country.name];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"+%@", country.countryCode];

    BOOL isSelected = [country.countryCode isEqualToString:self.selectedCountry.countryCode]
                   && [country.isoCode isEqualToString:self.selectedCountry.isoCode];
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CountryModel *country = self.displayGroups[indexPath.section].countries[indexPath.row];
    self.selectedCountry = country;
    [CountryModel saveLastSelectedCountry:country];

    void (^callback)(CountryModel *) = self.didSelectCountry;
    [self dismissViewControllerAnimated:YES completion:^{
        if (callback) callback(country);
    }];
}

@end
