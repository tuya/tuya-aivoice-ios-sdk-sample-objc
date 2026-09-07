//
//  ThingPerfusionReportListViewController.m
//  ThingPerfusionKit
//

#import "ThingPerfusionReportListViewController.h"
#import "ThingPerfusionReportBuilder.h"
#import <WebKit/WebKit.h>

#pragma mark - 报告预览

/// 内嵌 WebView 预览单份报告，右上角可分享。
@interface ThingPerfusionReportPreviewViewController : ThingPerfusionBaseViewController
@property (nonatomic, strong) NSURL *fileURL;
@end

@implementation ThingPerfusionReportPreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.fileURL.lastPathComponent;

    WKWebView *webView = [[WKWebView alloc] init];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:webView];
    [NSLayoutConstraint activateConstraints:@[
        [webView.topAnchor constraintEqualToAnchor:self.contentGuide.topAnchor],
        [webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // 报告是本地单文件，允许读取其所在目录即可
    [webView loadFileURL:self.fileURL allowingReadAccessToURL:self.fileURL.URLByDeletingLastPathComponent];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(shareTapped:)];
}

- (void)shareTapped:(UIBarButtonItem *)sender {
    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[self.fileURL] applicationActivities:nil];
    activity.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:activity animated:YES completion:nil];
}

@end

#pragma mark - 历史列表

@interface ThingPerfusionReportListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
/// 报告文件，按修改时间倒序。
@property (nonatomic, copy) NSArray<NSURL *> *reports;

@end

@implementation ThingPerfusionReportListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"历史报告";
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadReports];
}

#pragma mark - UI

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = UIColor.secondaryLabelColor;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.contentGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"清空"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(clearAllTapped:)];
}

#pragma mark - 数据

- (void)reloadReports {
    NSString *directory = [ThingPerfusionReportBuilder reportsDirectory];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSArray<NSString *> *names = [manager contentsOfDirectoryAtPath:directory error:nil];

    NSMutableArray<NSURL *> *files = [NSMutableArray array];
    for (NSString *name in names) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"html"]) continue;
        [files addObject:[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name]]];
    }
    // 最新的排在最前
    [files sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *da = nil, *db = nil;
        [a getResourceValue:&da forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&db forKey:NSURLContentModificationDateKey error:nil];
        return [db ?: NSDate.distantPast compare:da ?: NSDate.distantPast];
    }];

    self.reports = files;
    if (files.count == 0) {
        // 空态直接给出目录与实际文件情况，省去猜「为什么没有数据」
        BOOL exists = [manager fileExistsAtPath:directory];
        self.emptyLabel.text = [NSString stringWithFormat:
            @"暂无历史报告。\n\n生成方式：灌流结束后点「导出测试报告」；\n多轮灌流结束会自动保存一份。\n\n"
            "目录：%@\n目录%@，其中共 %lu 个文件",
            directory, exists ? @"已存在" : @"尚未创建", (unsigned long)names.count];
    }
    self.tableView.hidden = (files.count == 0);
    self.emptyLabel.hidden = (files.count > 0);
    self.navigationItem.rightBarButtonItem.enabled = (files.count > 0);
    [self.tableView reloadData];
}

- (NSString *)detailForReportAtURL:(NSURL *)url {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
    NSDate *date = attributes.fileModificationDate;
    unsigned long long size = attributes.fileSize;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [NSString stringWithFormat:@"%@ ｜ %.1f KB",
            date ? [formatter stringFromDate:date] : @"-", size / 1024.0];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.reports.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"ThingPerfusionReportCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    NSURL *url = self.reports[indexPath.row];
    cell.textLabel.text = url.lastPathComponent;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [self detailForReportAtURL:url];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ThingPerfusionReportPreviewViewController *preview = [[ThingPerfusionReportPreviewViewController alloc] init];
    preview.fileURL = self.reports[indexPath.row];
    [self.navigationController pushViewController:preview animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    NSURL *url = self.reports[indexPath.row];

    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                       title:@"分享"
                                                                     handler:^(UIContextualAction *action, UIView *sourceView, void (^completion)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { completion(NO); return; }
        UIActivityViewController *activity =
            [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        activity.popoverPresentationController.sourceView = sourceView;
        activity.popoverPresentationController.sourceRect = sourceView.bounds;
        [self presentViewController:activity animated:YES completion:nil];
        completion(YES);
    }];
    share.backgroundColor = UIColor.systemBlueColor;

    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                        title:@"删除"
                                                                      handler:^(UIContextualAction *action, UIView *sourceView, void (^completion)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { completion(NO); return; }
        NSError *error = nil;
        if ([NSFileManager.defaultManager removeItemAtURL:url error:&error]) {
            [self reloadReports];
            completion(YES);
        } else {
            [self showMessageWithTitle:@"删除失败" message:error.localizedDescription ?: @""];
            completion(NO);
        }
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[delete, share]];
}

#pragma mark - 操作

- (void)clearAllTapped:(UIBarButtonItem *)sender {
    __weak typeof(self) weakSelf = self;
    [self showConfirmationWithTitle:@"清空历史报告"
                           message:[NSString stringWithFormat:@"将删除全部 %lu 份报告，且不可恢复。",
                                    (unsigned long)self.reports.count]
                      confirmTitle:@"全部删除"
                       destructive:YES
                           confirm:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        for (NSURL *url in self.reports) {
            [NSFileManager.defaultManager removeItemAtURL:url error:nil];
        }
        [self reloadReports];
    }];
}

@end
