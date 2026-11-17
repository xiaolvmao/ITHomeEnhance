#import "ITXSettingsViewController.h"
#import "ITXPrefs.h"
#import "ITXLog.h"
#import "ITXSignIn.h"

static NSString *const kITXVersion = @"1.0.0";

#pragma mark - 日志页

@interface ITXLogViewController : UITableViewController
@end

@implementation ITXLogViewController {
    NSArray<NSString *> *_lines;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"运行日志";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 40;
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"清空"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(clearAll)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(share)],
    ];
    [self reload];
}

- (void)reload {
    _lines = ITXLogLines();
    [self.tableView reloadData];
    if (_lines.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 120)];
        empty.text = @"暂无日志";
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = [UIColor secondaryLabelColor];
        self.tableView.tableFooterView = empty;
    } else {
        self.tableView.tableFooterView = nil;
    }
}

- (void)clearAll {
    ITXLogClear();
    [self reload];
}

- (void)share {
    NSString *text = [_lines componentsJoinedByString:@"\n"];
    if (!text.length) return;
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    vc.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:vc animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _lines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"log";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.text = _lines[indexPath.row];
    return cell;
}

@end

#pragma mark - 设置面板

@implementation ITXSettingsViewController {
    NSArray<NSDictionary *> *_sections;
}

+ (void)openFrom:(UIViewController *)host {
    if (!host) return;
    ITXSettingsViewController *vc;
    if (@available(iOS 13.0, *)) {
        vc = [[ITXSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    } else {
        vc = [[ITXSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    }

    UINavigationController *nav = host.navigationController;
    if (nav && !nav.isBeingDismissed) {
        [nav pushViewController:vc animated:YES];
        return;
    }

    UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:vc];
    vc.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                         style:UIBarButtonItemStyleDone
                                        target:vc
                                        action:@selector(closeSelf)];
    [host presentViewController:wrapper animated:YES completion:nil];
}

- (void)closeSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"增强设置";
    self.tableView.rowHeight = 62;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    _sections = @[
        @{@"title": @"广告净化",
          @"rows": @[@(ITXKeyLaunchAd), @(ITXKeyFeedAd), @(ITXKeyDetailAd), @(ITXKeyAdHost)]},
        @{@"title": @"功能增强",
          @"rows": @[@(ITXKeyAutoSign), @(ITXKeyBlockUpdate), @(ITXKeyBlockJump), @(ITXKeyBlockStats)]},
        @{@"title": @"其他",
          @"rows": @[@"log", @"reset"]},
    ];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPrefsChanged)
                                                 name:ITXPrefsChangedNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onPrefsChanged {
    // 只刷新开关状态，避免打断用户操作
}

#pragma mark - 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != (NSInteger)_sections.count - 1) return nil;
    return [NSString stringWithFormat:@"IT之家增强 %@ · 修改即时生效\n自动签到：%@", kITXVersion, ITXSignInStatusText()];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id row = _sections[indexPath.section][@"rows"][indexPath.row];

    if ([row isKindOfClass:[NSNumber class]]) {
        ITXKey key = (ITXKey)[row integerValue];
        static NSString *cid = @"switch";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *sw = [[UISwitch alloc] init];
            sw.onTintColor = [UIColor systemRedColor];
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
        cell.textLabel.text = ITXKeyTitle(key);
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.detailTextLabel.text = ITXKeyDetail(key);
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.tag = key;
        sw.on = ITXOn(key);
        return cell;
    }

    static NSString *did = @"link";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:did];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:did];
    }
    if ([row isEqual:@"log"]) {
        cell.textLabel.text = @"查看运行日志";
        cell.detailTextLabel.text = @"排查用";
    } else {
        cell.textLabel.text = @"恢复默认设置";
        cell.detailTextLabel.text = nil;
    }
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

#pragma mark - 交互

- (void)switchChanged:(UISwitch *)sw {
    ITXKey key = (ITXKey)sw.tag;
    ITXSetOn(key, sw.isOn);
    ITXLog(@"开关 %@ → %@", ITXKeyTitle(key), sw.isOn ? @"开" : @"关");

    if (key == ITXKeyAutoSign && sw.isOn) {
        ITXAutoSignInSchedule();
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id row = _sections[indexPath.section][@"rows"][indexPath.row];
    if (![row isKindOfClass:[NSString class]]) return;

    if ([row isEqual:@"log"]) {
        [self.navigationController pushViewController:[[ITXLogViewController alloc] initWithStyle:UITableViewStylePlain]
                                             animated:YES];
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"恢复默认设置"
                                            message:@"所有开关会回到安装时的状态。"
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        ITXPrefsResetToDefaults();
        [self.tableView reloadData];
        ITXLog(@"已恢复默认设置");
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:alert animated:YES completion:nil];
}

@end
