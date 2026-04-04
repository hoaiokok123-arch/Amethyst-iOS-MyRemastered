#import "ModsManagerViewController.h"
#import "ModTableViewCell.h"
#import "ModService.h"
#import "ModItem.h"
#import "installer/modpack/ModrinthAPI.h"
#import "utils.h"

@interface ModsManagerViewController () <UITableViewDataSource, UITableViewDelegate, ModTableViewCellDelegate, UISearchBarDelegate, ModVersionViewControllerDelegate>

@property (nonatomic, strong) UISegmentedControl *modeSwitcher;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIBarButtonItem *refreshButton;
@property (nonatomic, strong) NSMutableArray<ModItem *> *localMods;
@property (nonatomic, strong) NSMutableArray<ModItem *> *filteredLocalMods;

@end

@implementation ModsManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"mods.title", nil);
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.currentMode = self.initialMode; // Use initialMode if set
    self.localMods = [NSMutableArray array];
    self.filteredLocalMods = [NSMutableArray array];
    self.onlineSearchResults = [NSMutableArray array];
    [self setupUI];
    [self updateUIForCurrentMode]; // Update UI based on current mode
    if (self.currentMode == ModsManagerModeLocal) {
        [self refreshLocalModsList];
    }
}

- (void)setupUI {
    self.modeSwitcher = [[UISegmentedControl alloc] initWithItems:@[
        localize(@"mods.mode.local", nil),
        localize(@"mods.mode.online", nil)
    ]];
    self.modeSwitcher.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSwitcher.selectedSegmentIndex = self.currentMode; // Set based on initial mode
    [self.modeSwitcher addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeSwitcher];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = localize(@"mods.search.local.placeholder", nil);
    [self.view addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[ModTableViewCell class] forCellReuseIdentifier:@"ModCell"];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 50;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];

    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = rc;

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(handleRefresh:)];
    [self updateNavigationButtons];

    [NSLayoutConstraint activateConstraints:@[
        [self.modeSwitcher.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.modeSwitcher.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.modeSwitcher.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.searchBar.topAnchor constraintEqualToAnchor:self.modeSwitcher.bottomAnchor constant:8],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor]
    ]];
}

- (void)modeChanged:(UISegmentedControl *)sender {
    self.currentMode = (ModsManagerMode)sender.selectedSegmentIndex;
    [self.searchBar resignFirstResponder];
    self.searchBar.text = @"";
    [self.onlineSearchResults removeAllObjects];
    [self filterLocalMods];
    [self.tableView reloadData];
    [self updateUIForCurrentMode];
}

- (void)updateUIForCurrentMode {
    if (self.currentMode == ModsManagerModeLocal) {
        self.searchBar.placeholder = localize(@"mods.search.local.placeholder", nil);
        self.emptyLabel.text = localize(@"mods.empty.local", nil);
        self.emptyLabel.hidden = self.localMods.count > 0;
    } else {
        self.searchBar.placeholder = localize(@"mods.search.online.placeholder", nil);
        self.emptyLabel.text = localize(@"mods.empty.online.prompt", nil);
        self.emptyLabel.hidden = self.onlineSearchResults.count > 0;
    }
    // Re-enable pull-to-refresh for all modes
    self.tableView.refreshControl.enabled = YES;
    [self updateNavigationButtons];
    [self.tableView reloadData];
}

- (void)updateNavigationButtons {
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeTapped)];
    
    if (self.currentMode == ModsManagerModeLocal) {
        self.navigationItem.rightBarButtonItems = @[self.refreshButton];
        self.navigationItem.leftBarButtonItem = closeButton;
    } else {
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.leftBarButtonItem = closeButton;
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Data Loading

- (void)handleRefresh:(id)sender {
    if (self.currentMode == ModsManagerModeLocal) {
        [self refreshLocalModsList];
    } else {
        // For online mode, only refresh if there's text, otherwise it's pointless.
        if (self.searchBar.text.length > 0) {
            [self performOnlineSearch];
        } else {
            // If no text, just end the refreshing indicator.
            [self.tableView.refreshControl endRefreshing];
        }
    }
}

- (void)setLoading:(BOOL)loading {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (loading) {
            self.emptyLabel.hidden = YES;
            [self.activityIndicator startAnimating];
        } else {
            [self.activityIndicator stopAnimating];
            [self.tableView.refreshControl endRefreshing];
        }
    });
}

- (void)refreshLocalModsList {
    if (self.currentMode != ModsManagerModeLocal) return;

    [self setLoading:YES];
    NSString *profile = self.profileName ?: @"default";
    [[ModService sharedService] scanModsForProfile:profile completion:^(NSArray<ModItem *> *mods) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.localMods removeAllObjects];
            [self.localMods addObjectsFromArray:mods];
            [self filterLocalMods];
            [self setLoading:NO];
        });
    }];
}

- (void)performOnlineSearch {
    NSString *searchText = self.searchBar.text;
    if (searchText.length == 0) return;

    [self setLoading:YES];
    [self.onlineSearchResults removeAllObjects];
    [self.tableView reloadData];

    NSDictionary *filters = @{@"name": searchText};

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *modrinthResults = [[ModrinthAPI sharedInstance] searchModWithFilters:filters previousPageResult:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (modrinthResults) {
                [self.onlineSearchResults addObjectsFromArray:modrinthResults];
            }
            [self setLoading:NO];
            self.emptyLabel.hidden = self.onlineSearchResults.count > 0;
            if (self.onlineSearchResults.count == 0) {
                self.emptyLabel.text = localize(@"mods.empty.online.none", nil);
            }
            [self.tableView reloadData];
        });
    });
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (self.currentMode == ModsManagerModeLocal) {
        [self filterLocalMods];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if (self.currentMode == ModsManagerModeOnline) {
        [self performOnlineSearch];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    if (self.currentMode == ModsManagerModeLocal) {
        [self filterLocalMods];
    } else {
        [self.onlineSearchResults removeAllObjects];
        [self.tableView reloadData];
        [self updateUIForCurrentMode];
    }
}

- (void)filterLocalMods {
    [self.filteredLocalMods removeAllObjects];
    if (self.searchBar.text.length == 0) {
        [self.filteredLocalMods addObjectsFromArray:self.localMods];
    } else {
        NSString *searchText = [self.searchBar.text lowercaseString];
        for (ModItem *mod in self.localMods) {
            if ([mod.displayName.lowercaseString containsString:searchText] ||
                [mod.fileName.lowercaseString containsString:searchText]) {
                [self.filteredLocalMods addObject:mod];
            }
        }
    }
    self.emptyLabel.hidden = self.filteredLocalMods.count > 0;
    if (!self.emptyLabel.hidden) {
        self.emptyLabel.text = localize(@"mods.empty.local.none", nil);
    }
    [self.tableView reloadData];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentMode == ModsManagerModeLocal ? self.filteredLocalMods.count : self.onlineSearchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModCell" forIndexPath:indexPath];
    cell.delegate = self;

    if (self.currentMode == ModsManagerModeLocal) {
        ModItem *mod = self.filteredLocalMods[indexPath.row];
        [cell configureWithMod:mod displayMode:ModTableViewCellDisplayModeLocal];
    } else {
        NSDictionary *modData = self.onlineSearchResults[indexPath.row];
        ModItem *modItem = [[ModItem alloc] initWithOnlineData:modData];
        [cell configureWithMod:modItem displayMode:ModTableViewCellDisplayModeOnline];
    }

    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentMode != ModsManagerModeLocal || indexPath.row >= self.filteredLocalMods.count) {
        return nil;
    }

    ModItem *targetMod = self.filteredLocalMods[indexPath.row];
    NSString *toggleTitle = targetMod.disabled ? localize(@"mods.action.enable", @"Enable") : localize(@"mods.action.disable", @"Disable");
    UIColor *toggleColor = targetMod.disabled ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];

    UIContextualAction *toggleAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:toggleTitle handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        NSError *toggleError = nil;
        BOOL toggled = [[ModService sharedService] toggleEnableForMod:targetMod error:&toggleError];
        if (!toggled) {
            [self showSimpleAlertWithTitle:localize(@"mods.toggle.failed.title", @"Toggle failed") message:toggleError.localizedDescription ?: localize(@"mods.toggle.failed.message", @"Unable to change mod state.")];
            completionHandler(NO);
            return;
        }

        NSInteger filteredIndex = [self.filteredLocalMods indexOfObject:targetMod];
        if (filteredIndex != NSNotFound) {
            NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:filteredIndex inSection:indexPath.section];
            [tableView reloadRowsAtIndexPaths:@[currentIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            [tableView reloadData];
        }

        completionHandler(YES);
    }];
    toggleAction.backgroundColor = toggleColor;

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:localize(@"Delete", nil) handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"mods.delete.confirm.title", nil) message:[NSString stringWithFormat:localize(@"mods.delete.confirm.message", nil), targetMod.displayName] preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            completionHandler(NO);
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            NSError *deleteError = nil;
            if (![[ModService sharedService] deleteMod:targetMod error:&deleteError]) {
                [self showSimpleAlertWithTitle:localize(@"mods.delete.failed", nil) message:deleteError.localizedDescription ?: localize(@"mods.delete.failed.message", @"Unable to delete mod file.")];
                completionHandler(NO);
                return;
            }

            NSInteger indexInFullList = [self.localMods indexOfObject:targetMod];
            if (indexInFullList != NSNotFound) {
                [self.localMods removeObjectAtIndex:indexInFullList];
            }

            NSInteger filteredIndex = [self.filteredLocalMods indexOfObject:targetMod];
            if (filteredIndex != NSNotFound) {
                NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:filteredIndex inSection:indexPath.section];
                [self.filteredLocalMods removeObjectAtIndex:filteredIndex];
                [tableView deleteRowsAtIndexPaths:@[currentIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                [tableView reloadData];
            }

            completionHandler(YES);
        }]];

        [self presentViewController:alert animated:YES completion:nil];
    }];
    deleteAction.backgroundColor = [UIColor systemRedColor];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, toggleAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

#pragma mark - ModTableViewCellDelegate (Download Implementation)

- (void)modCellDidTapDownload:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath || self.currentMode != ModsManagerModeOnline) return;

    NSDictionary *modData = self.onlineSearchResults[indexPath.row];
    ModItem *modItem = [[ModItem alloc] initWithOnlineData:modData];
    
    ModVersionViewController *versionVC = [[ModVersionViewController alloc] init];
    versionVC.modItem = modItem;
    versionVC.delegate = self;
    
    [self.navigationController pushViewController:versionVC animated:YES];
}

#pragma mark - ModVersionViewControllerDelegate

- (void)modVersionViewController:(ModVersionViewController *)viewController didSelectVersion:(ModVersion *)version {
    ModItem *itemToDownload = viewController.modItem;
    
    // Find the primary file to download
    NSDictionary *primaryFile = version.primaryFile;
    if (!primaryFile || ![primaryFile[@"url"] isKindOfClass:[NSString class]]) {
        [self showSimpleAlertWithTitle:localize(@"Error", nil) message:localize(@"mods.invalid_download_link", nil)];
        return;
    }

    itemToDownload.selectedVersionDownloadURL = primaryFile[@"url"];
    itemToDownload.fileName = primaryFile[@"filename"];

    [self startDownloadForItem:itemToDownload];
}

- (void)startDownloadForItem:(ModItem *)item {
    // Show a temporary "downloading" alert
    UIAlertController *downloadingAlert = [UIAlertController alertControllerWithTitle:localize(@"mods.downloading.title", nil)
                                                                              message:[NSString stringWithFormat:@"%@...", item.displayName]
                                                                       preferredStyle:UIAlertControllerStyleAlert];

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [downloadingAlert.view addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
        [indicator.centerXAnchor constraintEqualToAnchor:downloadingAlert.view.centerXAnchor],
        [indicator.centerYAnchor constraintEqualToAnchor:downloadingAlert.view.centerYAnchor constant:20]
    ]];
    [indicator startAnimating];

    [self presentViewController:downloadingAlert animated:YES completion:nil];

    [[ModService sharedService] downloadMod:item toProfile:self.profileName completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // First, dismiss the "downloading" alert
            [downloadingAlert dismissViewControllerAnimated:YES completion:^{
                // Then, show the result alert
                if (error) {
                    [self showSimpleAlertWithTitle:localize(@"mods.download.failed", nil) message:error.localizedDescription];
                } else {
                    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:localize(@"mods.download.success", nil)
                                                                                          message:[NSString stringWithFormat:localize(@"mods.download.success.message", nil), item.displayName]
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [successAlert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        // After user acknowledges, switch to local mods and refresh
                        [self.modeSwitcher setSelectedSegmentIndex:0];
                        [self modeChanged:self.modeSwitcher];
                        [self refreshLocalModsList];
                    }]];
                    [self presentViewController:successAlert animated:YES completion:nil];
                }
            }];
        });
    }];
}

- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentMode == ModsManagerModeOnline) {
        // Handle online search item selection if necessary (e.g., show details)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)modCellDidTapToggle:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath || self.currentMode != ModsManagerModeLocal || indexPath.row >= self.filteredLocalMods.count) return;

    ModItem *mod = self.filteredLocalMods[indexPath.row];

    NSError *error = nil;
    BOOL success = [[ModService sharedService] toggleEnableForMod:mod error:&error];

    if (!success) {
        NSLog(@"[ModsManager] Error toggling mod: %@", error);
        [(ModTableViewCell *)cell updateToggleState:mod.disabled];
        [self showSimpleAlertWithTitle:localize(@"mods.toggle.failed.title", @"Toggle failed") message:error.localizedDescription ?: localize(@"mods.toggle.failed.message", @"Unable to change mod state.")];
        return;
    }

    [(ModTableViewCell *)cell updateToggleState:mod.disabled];
}

- (void)modCellDidTapOpenLink:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) return;

    ModItem *modItem = nil;
    if (self.currentMode == ModsManagerModeLocal) {
        modItem = self.filteredLocalMods[indexPath.row];
    } else {
        NSDictionary *modData = self.onlineSearchResults[indexPath.row];
        modItem = [[ModItem alloc] initWithOnlineData:modData];
    }

    if (modItem.onlineID && modItem.onlineID.length > 0) {
        NSString *urlString = [NSString stringWithFormat:@"https://modrinth.com/mod/%@", modItem.onlineID];
        NSURL *url = [NSURL URLWithString:urlString];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    } else {
        // Optionally, inform the user that there's no link available
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"mods.link.unavailable.title", nil) message:localize(@"mods.link.unavailable.message", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end

