#import "ProfileSettingsViewController.h"
#import "ModsManagerViewController.h"
#import "ShadersManagerViewController.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "utils.h"

@interface ProfileSettingsViewController ()

@property (nonatomic, strong) NSArray<NSArray *> *sections;
@property (nonatomic, strong) NSString *selectedRenderer;
@property (nonatomic, strong) NSString *selectedJavaVersion;
@property (nonatomic, assign) NSInteger allocatedMemory;
@property (nonatomic, assign) NSInteger maxMemory;

@end

@implementation ProfileSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = [NSString stringWithFormat:@"%@ - Cài đặt", self.profileName ?: @"Phiên bản"];
    self.view.backgroundColor = [UIColor clearColor];
    
    // 设置表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.backgroundColor = [UIColor clearColor];
    
    // 计算最大内存
    [self calculateMaxMemory];
    
    // 加载设置
    [self loadSettings];
    
    // 设置分区
    [self setupSections];
}

- (void)calculateMaxMemory {
    // 获取设备总内存 (字节)
    long long totalMemory = [NSProcessInfo processInfo].physicalMemory;
    // 转换为 MB
    self.maxMemory = (NSInteger)(totalMemory / (1024 * 1024));
    // 留一些给系统，最大可用为总内存的 80%
    self.maxMemory = (NSInteger)(self.maxMemory * 0.8);
    // 确保最小值
    if (self.maxMemory < 1024) {
        self.maxMemory = 1024;
    }
}

- (void)loadSettings {
    // 加载当前版本的设置
    NSMutableDictionary *profile = PLProfiles.current.profiles[self.profileName];
    
    // 渲染器
    self.selectedRenderer = profile[@"renderer"] ?: @"auto";
    
    // Java版本
    self.selectedJavaVersion = profile[@"javaVersion"] ?: @"auto";
    
    // 内存分配 (MB)
    self.allocatedMemory = [profile[@"allocatedMemory"] integerValue];
    if (self.allocatedMemory == 0) {
        // 默认内存：最大内存的一半或 2048MB，取较小值
        self.allocatedMemory = MIN(self.maxMemory / 2, 2048);
    }
    // 确保不超过最大内存
    if (self.allocatedMemory > self.maxMemory) {
        self.allocatedMemory = self.maxMemory;
    }
}

- (void)setupSections {
    self.sections = @[
        @[@"Quản lý mod"],
        @[@"Quản lý shader"],
        @[@"Renderer", @"Phiên bản Java", @"Phân bổ RAM"]
    ];
}

- (void)saveSettings {
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    NSMutableDictionary *profile = [profiles[self.profileName] mutableCopy];
    if (!profile) {
        profile = [NSMutableDictionary dictionary];
    }
    
    profile[@"renderer"] = self.selectedRenderer;
    profile[@"javaVersion"] = self.selectedJavaVersion;
    profile[@"allocatedMemory"] = @(self.allocatedMemory);
    
    profiles[self.profileName] = profile;
    [PLProfiles.current save];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Mod";
        case 1: return @"Shader";
        case 2: return @"Nâng cao";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    }
    
    NSString *title = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = title;
    
    switch (indexPath.section) {
        case 0: // 模组管理
            cell.imageView.image = [UIImage systemImageNamed:@"puzzlepiece.fill"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = nil;
            break;
            
        case 1: // 光影管理
            cell.imageView.image = [UIImage systemImageNamed:@"paintbrush.fill"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = nil;
            break;
            
        case 2: // 高级设置
            if (indexPath.row == 0) {
                cell.imageView.image = [UIImage systemImageNamed:@"cpu"];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.detailTextLabel.text = [self rendererDisplayName:self.selectedRenderer];
            } else if (indexPath.row == 1) {
                cell.imageView.image = [UIImage systemImageNamed:@"j.square"];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.detailTextLabel.text = [self.selectedJavaVersion isEqualToString:@"auto"] ? @"Tự động" : self.selectedJavaVersion;
            } else if (indexPath.row == 2) {
                cell.imageView.image = [UIImage systemImageNamed:@"memorychip"];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld MB / %ld MB", (long)self.allocatedMemory, (long)self.maxMemory];
            }
            break;
    }
    
    return cell;
}

- (NSString *)rendererDisplayName:(NSString *)renderer {
    NSDictionary *names = @{
        @"auto": @"Tự động",
        @"zink": @"Zink (Vulkan)",
        @"gl4es": @"GL4ES (OpenGL ES)",
        @"angle": @"ANGLE (Metal)",
        @"mobileglues": @"MobileGlues"
    };
    return names[renderer] ?: renderer;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case 0: // 模组管理
            [self openModsManager];
            break;
            
        case 1: // 光影管理
            [self openShadersManager];
            break;
            
        case 2: // 高级设置
            if (indexPath.row == 0) {
                [self showRendererSelector];
            } else if (indexPath.row == 1) {
                [self showJavaVersionSelector];
            } else if (indexPath.row == 2) {
                [self showMemoryAllocator];
            }
            break;
    }
}

#pragma mark - Actions

- (void)openModsManager {
    ModsManagerViewController *vc = [[ModsManagerViewController alloc] init];
    vc.profileName = self.profileName;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openShadersManager {
    ShadersManagerViewController *vc = [[ShadersManagerViewController alloc] init];
    vc.profileName = self.profileName;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showRendererSelector {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn renderer"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *renderers = @[@"auto", @"zink", @"gl4es", @"angle", @"mobileglues"];
    NSArray *displayNames = @[@"Tự động", @"Zink (Vulkan)", @"GL4ES (OpenGL ES)", @"ANGLE (Metal)", @"MobileGlues"];
    
    for (NSInteger i = 0; i < renderers.count; i++) {
        NSString *renderer = renderers[i];
        NSString *name = displayNames[i];
        UIAlertActionStyle style = [self.selectedRenderer isEqualToString:renderer] ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
        
        [alert addAction:[UIAlertAction actionWithTitle:name
                                                  style:style
                                                handler:^(UIAlertAction * _Nonnull action) {
            self.selectedRenderer = renderer;
            [self saveSettings];
            [self.tableView reloadData];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // iPad支持
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showJavaVersionSelector {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn phiên bản Java"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Tự động chọn"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.selectedJavaVersion = @"auto";
        [self saveSettings];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Java 8"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.selectedJavaVersion = @"java8";
        [self saveSettings];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Java 17"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.selectedJavaVersion = @"java17";
        [self saveSettings];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Java 21"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.selectedJavaVersion = @"java21";
        [self saveSettings];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // iPad支持
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:2];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMemoryAllocator {
    // 计算建议内存值
    NSInteger minMemory = 512;
    NSInteger step = 512;
    NSMutableArray *options = [NSMutableArray array];
    
    for (NSInteger mem = minMemory; mem <= self.maxMemory; mem += step) {
        [options addObject:@(mem)];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Phân bổ RAM"
                                                                   message:[NSString stringWithFormat:@"Tổng RAM thiết bị: %ld MB\nTối đa có thể cấp: %ld MB", (long)(self.maxMemory / 0.8), (long)self.maxMemory]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSNumber *memNum in options) {
        NSInteger mem = [memNum integerValue];
        NSString *title = [NSString stringWithFormat:@"%ld MB", (long)mem];
        UIAlertActionStyle style = (self.allocatedMemory == mem) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                  style:style
                                                handler:^(UIAlertAction * _Nonnull action) {
            self.allocatedMemory = mem;
            [self saveSettings];
            [self.tableView reloadData];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // iPad支持
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:2 inSection:2];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Orientation

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end
