#import "VersionManagerViewController.h"
#import "PLProfiles.h"
#import "LauncherProfileEditorViewController.h"
#import "ModsManagerViewController.h"
#import "ShadersManagerViewController.h"
#import "LauncherPrefGameDirViewController.h"
#import "ModpackImportService.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Modern Tile Base Cell

@interface VMTileBaseCell : UICollectionViewCell
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *contentContainer;
- (void)setupViews;
@end

@implementation VMTileBaseCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowOpacity = 0.15;
    self.layer.shadowRadius = 8;
    self.layer.masksToBounds = NO;
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.contentView.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.layer.cornerRadius = 16;
    self.blurView.layer.masksToBounds = YES;
    self.blurView.layer.borderWidth = 0.5;
    self.blurView.layer.borderColor = [UIColor separatorColor].CGColor;
    [self.contentView addSubview:self.blurView];
    
    self.contentContainer = [[UIView alloc] initWithFrame:self.contentView.bounds];
    self.contentContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:self.contentContainer];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

#pragma mark - Quick Action Tile Cell

@interface VMQuickActionCell : VMTileBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@implementation VMQuickActionCell

- (void)setupViews {
    [super setupViews];
    
    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentContainer addSubview:self.iconView];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 2;
    [self.contentContainer addSubview:self.titleLabel];
    
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 2;
    [self.contentContainer addSubview:self.subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:16],
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.iconView.widthAnchor constraintEqualToConstant:28],
        [self.iconView.heightAnchor constraintEqualToConstant:28],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:12],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentContainer.bottomAnchor constant:-12]
    ]];
}

- (void)configureWithIcon:(NSString *)iconName title:(NSString *)title subtitle:(NSString *)subtitle color:(UIColor *)color {
    self.iconView.image = [UIImage systemImageNamed:iconName];
    self.iconView.tintColor = color;
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
}

@end

#pragma mark - Version Card Cell

@interface VMVersionCardCell : VMTileBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIView *selectedBadge;
@end

@implementation VMVersionCardCell

- (void)setupViews {
    [super setupViews];
    
    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.image = [UIImage systemImageNamed:@"cube.box.fill"];
    self.iconView.tintColor = [UIColor systemBlueColor];
    [self.contentContainer addSubview:self.iconView];
    
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.nameLabel.textColor = [UIColor labelColor];
    self.nameLabel.numberOfLines = 1;
    [self.contentContainer addSubview:self.nameLabel];
    
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.versionLabel.textColor = [UIColor secondaryLabelColor];
    [self.contentContainer addSubview:self.versionLabel];
    
    self.selectedBadge = [[UIView alloc] init];
    self.selectedBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedBadge.backgroundColor = [UIColor systemGreenColor];
    self.selectedBadge.layer.cornerRadius = 12;
    self.selectedBadge.hidden = YES;
    [self.contentContainer addSubview:self.selectedBadge];
    
    UIImageView *checkmark = [[UIImageView alloc] init];
    checkmark.translatesAutoresizingMaskIntoConstraints = NO;
    checkmark.image = [UIImage systemImageNamed:@"checkmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIFontWeightBold]];
    checkmark.tintColor = [UIColor whiteColor];
    [self.selectedBadge addSubview:checkmark];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.contentContainer.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:36],
        [self.iconView.heightAnchor constraintEqualToConstant:36],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:12],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:14],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.selectedBadge.leadingAnchor constant:-8],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.versionLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.selectedBadge.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.selectedBadge.centerYAnchor constraintEqualToAnchor:self.nameLabel.centerYAnchor],
        [self.selectedBadge.widthAnchor constraintEqualToConstant:24],
        [self.selectedBadge.heightAnchor constraintEqualToConstant:24],
        [checkmark.centerXAnchor constraintEqualToAnchor:self.selectedBadge.centerXAnchor],
        [checkmark.centerYAnchor constraintEqualToAnchor:self.selectedBadge.centerYAnchor]
    ]];
}

- (void)configureWithName:(NSString *)name version:(NSString *)version isSelected:(BOOL)isSelected {
    self.nameLabel.text = name;
    self.versionLabel.text = version ?: localize(@"version_manager.unknown_version", @"Unknown version");
    self.selectedBadge.hidden = !isSelected;
    
    if (isSelected) {
        self.blurView.layer.borderColor = [UIColor systemGreenColor].CGColor;
        self.blurView.layer.borderWidth = 1.5;
    } else {
        self.blurView.layer.borderColor = [UIColor separatorColor].CGColor;
        self.blurView.layer.borderWidth = 0.5;
    }
}

@end

#pragma mark - Header View

@interface VMSectionHeaderView : UICollectionReusableView
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation VMSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        self.titleLabel.textColor = [UIColor labelColor];
        [self addSubview:self.titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

@end

#pragma mark - View Controller

@interface VersionManagerViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *profileList;
@property (nonatomic, strong) NSString *selectedProfile;
@property (nonatomic, strong) NSArray<NSDictionary *> *importedModpacks;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *importedModpacksByProfileName;
@end

@implementation VersionManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"version_manager.title", @"Version Manager");
    self.view.backgroundColor = [UIColor clearColor];
    [self setupCollectionView];
    [self loadProfiles];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(profileChanged)
                                                 name:@"SelectedProfileChanged"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(profileChanged)
                                                 name:@"ReloadProfileList"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadProfiles];
    [self.collectionView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)profileChanged {
    [self loadProfiles];
    [self.collectionView reloadData];
}

#pragma mark - Setup

- (void)setupCollectionView {
    UICollectionViewLayout *layout = [self createLayout];
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    
    [self.collectionView registerClass:[VMQuickActionCell class] forCellWithReuseIdentifier:@"QuickActionCell"];
    [self.collectionView registerClass:[VMVersionCardCell class] forCellWithReuseIdentifier:@"VersionCell"];
    [self.collectionView registerClass:[VMSectionHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView"];
    
    [self.view addSubview:self.collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor]
    ]];
}

- (UICollectionViewLayout *)createLayout {
    return [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(NSInteger sectionIndex, id<NSCollectionLayoutEnvironment> _Nonnull layoutEnvironment) {
        CGFloat width = layoutEnvironment.container.contentSize.width;
        BOOL isiPad = width > 700;
        
        if (sectionIndex == 0) {
            NSInteger columnCount = isiPad ? 5 : 3;
            NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0 / columnCount]
                                                                              heightDimension:[NSCollectionLayoutDimension absoluteDimension:100]];
            NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            item.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
            
            NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                                                               heightDimension:[NSCollectionLayoutDimension absoluteDimension:100]];
            NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];
            
            NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
            section.contentInsets = NSDirectionalEdgeInsetsMake(8, 14, 8, 14);
            return section;
        } else {
            NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:isiPad ? 0.5 : 1.0]
                                                                              heightDimension:[NSCollectionLayoutDimension absoluteDimension:70]];
            NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
            item.contentInsets = NSDirectionalEdgeInsetsMake(4, 8, 4, 8);
            
            NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                                                               heightDimension:[NSCollectionLayoutDimension absoluteDimension:70]];
            NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];
            
            NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
            section.contentInsets = NSDirectionalEdgeInsetsMake(0, 14, 20, 14);
            
            NSCollectionLayoutSize *headerSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                                                             heightDimension:[NSCollectionLayoutDimension absoluteDimension:44]];
            NSCollectionLayoutBoundarySupplementaryItem *header = [NSCollectionLayoutBoundarySupplementaryItem boundarySupplementaryItemWithLayoutSize:headerSize elementKind:UICollectionElementKindSectionHeader alignment:NSRectAlignmentTop];
            section.boundarySupplementaryItems = @[header];
            return section;
        }
    }];
}

#pragma mark - Data

- (void)loadProfiles {
    NSMutableDictionary *profiles = PLProfiles.current.profiles;
    NSMutableArray *list = [NSMutableArray array];
    for (NSString *key in profiles.allKeys) {
        [list addObject:key];
    }
    self.profileList = [list sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj2 compare:obj1];
    }];
    self.selectedProfile = PLProfiles.current.selectedProfileName;

    NSArray<NSDictionary *> *importedModpacks = [[[ModpackImportService alloc] init] getImportedModpacks];
    self.importedModpacks = importedModpacks ?: @[];

    NSMutableDictionary<NSString *, NSDictionary *> *byProfileName = [NSMutableDictionary dictionary];
    for (NSDictionary *modpackInfo in self.importedModpacks) {
        NSString *profileName = modpackInfo[@"profileName"];
        if (profileName.length > 0) {
            byProfileName[profileName] = modpackInfo;
        }
    }
    self.importedModpacksByProfileName = byProfileName;
}

- (NSDictionary *)importedModpackForProfileName:(NSString *)profileName {
    return self.importedModpacksByProfileName[profileName];
}

- (NSString *)displayNameForProfileName:(NSString *)profileName profile:(NSDictionary *)profile {
    NSDictionary *modpackInfo = [self importedModpackForProfileName:profileName];
    NSString *modpackName = modpackInfo[@"name"];
    if (modpackName.length > 0) {
        return modpackName;
    }
    NSString *displayName = profile[@"name"];
    return displayName.length > 0 ? displayName : profileName;
}

- (NSString *)formattedLoaderTextForModpackInfo:(NSDictionary *)modpackInfo {
    NSString *loader = modpackInfo[@"loader"];
    NSString *loaderVersion = modpackInfo[@"loaderVersion"];
    if (loader.length == 0) {
        return @"";
    }
    if (loaderVersion.length > 0) {
        return [NSString stringWithFormat:@"%@ %@", loader, loaderVersion];
    }
    return loader;
}

- (NSString *)detailTextForProfileName:(NSString *)profileName profile:(NSDictionary *)profile {
    NSDictionary *modpackInfo = [self importedModpackForProfileName:profileName];
    if (modpackInfo.count > 0) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        NSString *modpackVersion = modpackInfo[@"version"];
        NSString *minecraftVersion = modpackInfo[@"minecraftVersion"];
        NSString *loaderText = [self formattedLoaderTextForModpackInfo:modpackInfo];

        if (modpackVersion.length > 0) {
            [parts addObject:[NSString stringWithFormat:localize(@"version_manager.profile_modpack_version", @"Modpack %@"), modpackVersion]];
        }
        if (minecraftVersion.length > 0) {
            [parts addObject:[NSString stringWithFormat:localize(@"version_manager.profile_minecraft_version", @"Minecraft %@"), minecraftVersion]];
        }
        if (loaderText.length > 0) {
            [parts addObject:loaderText];
        }
        if (parts.count > 0) {
            return [parts componentsJoinedByString:@" - "];
        }
    }

    NSString *versionId = profile[@"lastVersionId"];
    if (versionId.length > 0) {
        return versionId;
    }
    return localize(@"version_manager.unknown_version", @"Unknown version");
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 2;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (section == 0) return 3;
    return self.profileList.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        VMQuickActionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"QuickActionCell" forIndexPath:indexPath];
        
        switch (indexPath.item) {
            case 0:
                [cell configureWithIcon:@"folder.fill"
                                   title:localize(@"preference.title.game_directory", nil)
                                subtitle:getPrefObject(@"general.game_directory")
                                   color:[UIColor systemBlueColor]];
                break;
            case 1:
                [cell configureWithIcon:@"puzzlepiece.extension.fill"
                                   title:localize(@"profile.manage_mods", nil)
                                subtitle:localize(@"version_manager.manage_mods.subtitle", @"Manage installed mods")
                                   color:[UIColor systemOrangeColor]];
                break;
            case 2:
                [cell configureWithIcon:@"paintbrush.fill"
                                   title:localize(@"version_manager.manage_shaders", @"Shader Packs")
                                subtitle:localize(@"version_manager.manage_shaders.subtitle", @"Manage installed shader packs")
                                   color:[UIColor systemPurpleColor]];
                break;
        }
        return cell;
    } else {
        VMVersionCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"VersionCell" forIndexPath:indexPath];
        
        NSString *profileName = self.profileList[indexPath.item];
        NSDictionary *profile = PLProfiles.current.profiles[profileName];
        BOOL isSelected = [profileName isEqualToString:self.selectedProfile];
        
        [cell configureWithName:[self displayNameForProfileName:profileName profile:profile]
                        version:[self detailTextForProfileName:profileName profile:profile]
                     isSelected:isSelected];
        return cell;
    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader && indexPath.section == 1) {
        VMSectionHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
        header.titleLabel.text = localize(@"profile.section.profiles", nil);
        return header;
    }
    return [UICollectionReusableView new];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        switch (indexPath.item) {
            case 0: [self openGameDirectory]; break;
            case 1: [self openModsManager]; break;
            case 2: [self openShadersManager]; break;
        }
    } else {
        [self showProfileActions:self.profileList[indexPath.item]];
    }
}

#pragma mark - Actions

- (void)openGameDirectory {
    LauncherPrefGameDirViewController *vc = [[LauncherPrefGameDirViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openModsManager {
    if (!self.selectedProfile) {
        [self showAlert:localize(@"version_manager.select_profile_first", @"Please select a profile first")];
        return;
    }
    ModsManagerViewController *vc = [[ModsManagerViewController alloc] init];
    vc.profileName = self.selectedProfile;
    vc.initialMode = ModsManagerModeLocal;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openShadersManager {
    if (!self.selectedProfile) {
        [self showAlert:localize(@"version_manager.select_profile_first", @"Please select a profile first")];
        return;
    }
    ShadersManagerViewController *vc = [[ShadersManagerViewController alloc] init];
    vc.profileName = self.selectedProfile;
    vc.initialMode = ShadersManagerModeLocal;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showProfileActions:(NSString *)profileName {
    NSDictionary *profile = PLProfiles.current.profiles[profileName];
    BOOL isSelected = [profileName isEqualToString:self.selectedProfile];
    NSString *displayName = [self displayNameForProfileName:profileName profile:profile];
    NSString *detailText = [self detailTextForProfileName:profileName profile:profile];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:displayName
                                                                   message:detailText
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (!isSelected) {
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"version_manager.select_profile", @"Select this profile") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            PLProfiles.current.selectedProfileName = profileName;
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Edit profile", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self editProfile:profileName];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self deleteProfile:profileName];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editProfile:(NSString *)profileName {
    NSDictionary *profile = PLProfiles.current.profiles[profileName];
    LauncherProfileEditorViewController *vc = [[LauncherProfileEditorViewController alloc] init];
    vc.profile = [profile mutableCopy];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)deleteProfile:(NSString *)profileName {
    if (self.profileList.count <= 1) {
        [self showAlert:localize(@"version_manager.min_profile_required", @"At least one profile must be kept")];
        return;
    }

    NSDictionary *profile = PLProfiles.current.profiles[profileName];
    NSString *displayName = [self displayNameForProfileName:profileName profile:profile];
    
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:localize(@"version_manager.delete_confirm.title", @"Confirm deletion")
                                                                     message:[NSString stringWithFormat:localize(@"version_manager.delete_confirm.message", @"Delete \"%@\"?"), displayName]
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:localize(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [PLProfiles.current.profiles removeObjectForKey:profileName];
        if ([PLProfiles.current.selectedProfileName isEqualToString:profileName]) {
            PLProfiles.current.selectedProfileName = PLProfiles.current.profiles.allKeys.firstObject;
        }
        [PLProfiles.current save];
        [self loadProfiles];
        [self.collectionView reloadData];
    }]];
    
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Notice", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
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
