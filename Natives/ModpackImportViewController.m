//
//  ModpackImportViewController.m
//  Amethyst
//

#import "ModpackImportViewController.h"
#import "ModpackImportService.h"
#import "PLProfiles.h"
#import "utils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface ModpackImportViewController () <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIButton *importButton;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *importedModpacks;
@property (nonatomic, strong) ModpackImportService *importService;
@property (nonatomic, strong) NSDictionary *currentImportingModpack;
@property (nonatomic, strong) UIVisualEffectView *backgroundBlurView;
@property (nonatomic, assign) BOOL didAutoOpenImporter;

@end

@implementation ModpackImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = localize(@"modpack.library.title", nil);

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    self.backgroundBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.backgroundBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.backgroundBlurView];
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundBlurView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backgroundBlurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundBlurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundBlurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.importService = [[ModpackImportService alloc] init];
    self.importedModpacks = [NSMutableArray array];

    [self setupUI];
    [self loadImportedModpacks];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.opensImporterOnAppear && !self.didAutoOpenImporter) {
        self.didAutoOpenImporter = YES;
        [self selectModpackFile];
    }
}

- (void)setupUI {
    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.importButton setTitle:localize(@"modpack.library.import_button", nil) forState:UIControlStateNormal];
    [self.importButton setImage:[UIImage systemImageNamed:@"doc.badge.plus"] forState:UIControlStateNormal];
    [self.importButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.importButton.backgroundColor = [UIColor systemBlueColor];
    self.importButton.layer.cornerRadius = 10.0;
    self.importButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.importButton addTarget:self action:@selector(selectModpackFile) forControlEvents:UIControlEventTouchUpInside];
    [self.backgroundBlurView.contentView addSubview:self.importButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 80;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.backgroundBlurView.contentView addSubview:self.tableView];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.backgroundBlurView.contentView addSubview:self.activityIndicator];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.text = localize(@"modpack.library.empty", nil);
    [self.backgroundBlurView.contentView addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.importButton.topAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.topAnchor constant:16],
        [self.importButton.leadingAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.importButton.trailingAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.importButton.heightAnchor constraintEqualToConstant:50],

        [self.tableView.topAnchor constraintEqualToAnchor:self.importButton.bottomAnchor constant:16],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.safeAreaLayoutGuide.bottomAnchor],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.centerYAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.backgroundBlurView.contentView.centerYAnchor]
    ]];
}

- (void)loadImportedModpacks {
    NSArray *modpacks = [self.importService getImportedModpacks];
    [self.importedModpacks removeAllObjects];
    [self.importedModpacks addObjectsFromArray:modpacks];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.emptyLabel.hidden = self.importedModpacks.count > 0;
        [self.tableView reloadData];
    });
}

#pragma mark - File Picker

- (void)selectModpackFile {
    NSArray<UTType *> *contentTypes = @[
        [UTType typeWithFilenameExtension:@"mrpack"],
        [UTType typeWithFilenameExtension:@"zip"]
    ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) {
        return;
    }

    NSURL *fileURL = urls.firstObject;
    NSString *fileExtension = fileURL.pathExtension.lowercaseString;
    if (![fileExtension isEqualToString:@"mrpack"] && ![fileExtension isEqualToString:@"zip"]) {
        [self showAlertWithTitle:localize(@"modpack.library.invalid_file.title", nil)
                         message:localize(@"modpack.library.invalid_file.message", nil)];
        return;
    }

    BOOL accessGranted = [fileURL startAccessingSecurityScopedResource];
    if (!accessGranted) {
        [self showAlertWithTitle:localize(@"modpack.library.access_denied.title", nil)
                         message:localize(@"modpack.library.access_denied.message", nil)];
        return;
    }

    [self.activityIndicator startAnimating];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSDictionary *modpackInfo = [self.importService parseModpackAtURL:fileURL error:&error];
        [fileURL stopAccessingSecurityScopedResource];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            if (error) {
                [self showAlertWithTitle:localize(@"modpack.library.parse_failed.title", nil)
                                 message:error.localizedDescription];
                return;
            }
            if (modpackInfo) {
                self.currentImportingModpack = modpackInfo;
                [self showModpackImportConfirmation:modpackInfo];
            } else {
                [self showAlertWithTitle:localize(@"modpack.library.parse_failed.title", nil)
                                 message:localize(@"modpack.library.parse_failed.message", nil)];
            }
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {}

#pragma mark - Import Flow

- (void)showModpackImportConfirmation:(NSDictionary *)modpackInfo {
    NSString *unknownText = localize(@"modpack.library.unknown", nil);
    NSString *name = modpackInfo[@"name"] ?: unknownText;
    NSString *version = modpackInfo[@"version"] ?: unknownText;
    NSString *mcVersion = modpackInfo[@"minecraftVersion"] ?: unknownText;
    NSString *loader = modpackInfo[@"loader"] ?: unknownText;
    NSString *loaderVersion = modpackInfo[@"loaderVersion"] ?: @"";
    NSString *message = [NSString stringWithFormat:localize(@"modpack.library.confirm.message", nil), name, version, mcVersion, loader, loaderVersion];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"modpack.library.confirm.title", nil)
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
        self.currentImportingModpack = nil;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"modpack.library.confirm.action", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self startModpackImport:modpackInfo];
    }]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startModpackImport:(NSDictionary *)modpackInfo {
    [self.activityIndicator startAnimating];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self.importService importModpack:modpackInfo error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.currentImportingModpack = nil;
            if (success) {
                [self showAlertWithTitle:localize(@"modpack.library.import.success.title", nil)
                                 message:[NSString stringWithFormat:localize(@"modpack.library.import.success.message", nil), modpackInfo[@"name"]]
                              completion:^{
                    [self loadImportedModpacks];
                }];
            } else {
                NSString *errorMsg = error ? error.localizedDescription : localize(@"modpack.library.unknown", nil);
                [self showAlertWithTitle:localize(@"modpack.library.import.failure.title", nil)
                                 message:errorMsg];
            }
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.importedModpacks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModpackCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ModpackCell"];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.layer.cornerRadius = 12;
        blurView.layer.masksToBounds = YES;
        blurView.tag = 1001;
        [cell.contentView insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [blurView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:12],
            [blurView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
            [blurView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4]
        ]];
    }

    NSDictionary *modpack = self.importedModpacks[indexPath.row];
    NSString *unknownText = localize(@"modpack.library.unknown", nil);
    NSString *name = modpack[@"name"] ?: unknownText;
    NSString *mcVersion = modpack[@"minecraftVersion"] ?: unknownText;
    NSString *loader = modpack[@"loader"] ?: unknownText;

    cell.textLabel.text = name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Minecraft %@ - %@", mcVersion, loader];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = [UIImage systemImageNamed:@"archivebox"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = nil;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *modpack = self.importedModpacks[indexPath.row];
    [self showModpackOptions:modpack];
}

- (void)showModpackOptions:(NSDictionary *)modpack {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:modpack[@"name"]
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:localize(@"modpack.library.action.launch", nil)
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self launchModpack:modpack];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil)
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self deleteModpack:modpack];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)launchModpack:(NSDictionary *)modpack {
    NSString *profileName = modpack[@"profileName"];
    if (profileName.length > 0 && PLProfiles.current.profiles[profileName]) {
        PLProfiles.current.selectedProfileName = profileName;
        [self showAlertWithTitle:localize(@"modpack.library.launch.selected.title", nil)
                         message:[NSString stringWithFormat:localize(@"modpack.library.launch.selected.message", nil), profileName]];
    } else {
        [self showAlertWithTitle:localize(@"Error", nil)
                         message:localize(@"modpack.library.launch.missing_profile", nil)];
    }
}

- (void)deleteModpack:(NSDictionary *)modpack {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:localize(@"modpack.library.delete.confirm.title", nil)
                                                                     message:[NSString stringWithFormat:localize(@"modpack.library.delete.confirm.message", nil), modpack[@"name"]]
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil)
                                                style:UIAlertActionStyleDestructive
                                              handler:^(UIAlertAction * _Nonnull action) {
        [self.activityIndicator startAnimating];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            BOOL success = [self.importService deleteModpack:modpack error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                if (success) {
                    [self loadImportedModpacks];
                } else {
                    [self showAlertWithTitle:localize(@"modpack.library.delete.failure.title", nil)
                                     message:error.localizedDescription];
                }
            });
        });
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

#pragma mark - Alerts

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [self showAlertWithTitle:title message:message completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message completion:(void (^ _Nullable)(void))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        if (completion) {
            completion();
        }
    }]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

@end
