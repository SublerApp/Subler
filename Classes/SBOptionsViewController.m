//
//  QueueOptionsController.m
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import "SBOptionsViewController.h"

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import "Subler-Swift.h"

static void *SBOptionsViewContex = &SBOptionsViewContex;

@interface SBOptionsViewController () {
@private
    IBOutlet NSPopUpButton *_destButton;

    NSMutableDictionary *_options;
    NSMutableArray *_sets;

    NSArray *_moviesProviders;
    NSArray *_tvShowsProviders;
    NSArray *_movieLanguages;
    NSArray *_tvShowLanguages;

    NSURL *_destination;
}

@property (nonatomic) NSMutableDictionary *options;
@property (nonatomic, strong) NSMutableArray *sets;

@property (nonatomic, strong) NSArray *moviesProviders;
@property (nonatomic, strong) NSArray *tvShowsProviders;
@property (nonatomic, strong) NSArray *movieLanguages;
@property (nonatomic, strong) NSArray *tvShowLanguages;

@property (nonatomic, strong) NSArray *languages;
@property (nonatomic, strong) MP42Languages *langManager;

- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@property (nonatomic, strong) NSURL *destination;

@end

@implementation SBOptionsViewController

- (instancetype)initWithOptions:(NSMutableDictionary *)options {
    self = [self init];
    if (self) {
        _options = options;
        _sets = [[NSMutableArray alloc] init];
        _moviesProviders = [SBMetadataImporter movieProviders];
        _tvShowsProviders = [SBMetadataImporter tvProviders];
        _languages = [[MP42Languages defaultManager] localizedExtendedLanguages];
        _langManager = MP42Languages.defaultManager;
    }
    return self;
}

- (instancetype)init {
    self = [super initWithNibName:@"QueueOptions" bundle:nil];
    if (self) {
    }
    return self;
}

- (void)loadView {
    [super loadView];

    // Hack to fix crappy anti-aliasing on Yosemite
    // unfortunately it fixes the checkboxes anti-aliasing,
    // but break the popup buttons one…
    if (NSClassFromString(@"NSVisualEffectView")) {
        self.view.wantsLayer = YES;

        for (NSButton *subview in self.view.subviews) {
            if ([subview isKindOfClass:[NSButton class]]) {
                NSAttributedString *string = [[NSAttributedString alloc] initWithString:subview.title
                                                                             attributes:@{NSForegroundColorAttributeName:[NSColor labelColor],
                                                                                        NSFontAttributeName:[NSFont labelFontOfSize:11]}];
                subview.attributedTitle = string;
            }
        }
    }

    // Observe the providers changes
    // to update the specific provider languages popup
    [self addObserver:self
           forKeyPath:@"options.SBQueueMovieProvider"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:SBOptionsViewContex];

    [self addObserver:self
           forKeyPath:@"options.SBQueueTVShowProvider"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:SBOptionsViewContex];

    [self prepareDestPopup];
    [self prepareSetsPopup];
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = anItem.action;

    if (action == @selector(chooseDestination:))
        return YES;

    if (action == @selector(destination:))
        return YES;

    return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SBOptionsViewContex) {
        // Update the languages popup
        if ([keyPath isEqualToString:@"options.SBQueueMovieProvider"]){
            NSString *newProvider = [change valueForKey:NSKeyValueChangeNewKey];
            SBMetadataImporter *importer = [SBMetadataImporter importerWithProvider:newProvider];

            self.movieLanguages = [self localizedLanguagesForImporter:importer];

            NSString *oldLanguage = [self.options valueForKey:@"SBQueueMovieProviderLanguage"];

            if (![importer.languages containsObject:oldLanguage]) {
                [self.options setValue:[SBMetadataImporter defaultLanguageWithProvider:newProvider] forKeyPath:@"SBQueueMovieProviderLanguage"];
            }
        } else if ([keyPath isEqualToString:@"options.SBQueueTVShowProvider"]) {
            NSString *newProvider = [change valueForKey:NSKeyValueChangeNewKey];
            SBMetadataImporter *importer = [SBMetadataImporter importerWithProvider:newProvider];
            self.tvShowLanguages = [self localizedLanguagesForImporter:importer];

            NSString *oldLanguage = [self.options valueForKey:@"SBQueueTVShowProviderLanguage"];

            if (![importer.languages containsObject:oldLanguage]) {
                [self.options setValue:[SBMetadataImporter defaultLanguageWithProvider:newProvider] forKeyPath:@"SBQueueTVShowProviderLanguage"];
            }
        } else {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
}

- (NSArray<NSString *> *)localizedLanguagesForImporter:(SBMetadataImporter *)importer
{
    NSMutableArray *languages = [NSMutableArray array];
    SBMetadataImporterLanguageType type = importer.languageType;

    for (NSString *lang in importer.languages) {
        if (type == SBMetadataImporterLanguageTypeISO) {
            [languages addObject:[_langManager localizedLangForExtendedTag:lang]];
        }
        else {
            [languages addObject:lang];
        }
    }
    return languages;
}

#pragma mark Destination PopUp

- (void)prepareDestPopup {
    NSMenuItem *folderItem = nil;

    if ([self.options valueForKey:@"SBQueueDestination"]) {
        self.destination = [self.options valueForKey:@"SBQueueDestination"];

        if (![[NSFileManager defaultManager] fileExistsAtPath:self.destination.path isDirectory:nil]) {
            self.destination = nil;
        }
    }

    if (!self.destination) {
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if (allPaths.count) {
            self.destination = [NSURL fileURLWithPath:allPaths.lastObject];
        }
    }

    if (self.destination) {
        folderItem = [self prepareDestPopupItem:self.destination];

        [_destButton.menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        [_destButton.menu insertItem:folderItem atIndex:0];

        if ([self.options valueForKey:@"SBQueueDestination"]) {
            [_destButton selectItem:folderItem];
        }
        else {
            [_destButton selectItemWithTag:10];
        }
    }
}

- (IBAction)chooseDestination:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;

    panel.prompt = NSLocalizedString(@"Select", @"Select queue destination.");
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMenuItem *folderItem = [self prepareDestPopupItem:panel.URL];

            [self->_destButton.menu removeItemAtIndex:0];
            [self->_destButton.menu insertItem:folderItem atIndex:0];

            [self->_destButton selectItem:folderItem];

            [self.options setValue:panel.URL forKey:@"SBQueueDestination"];
            self.destination = panel.URL;
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        } else {
            [self->_destButton selectItemAtIndex:2];
        }
    }];
}

- (NSMenuItem *)prepareDestPopupItem:(nonnull NSURL *)dest {
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:dest.lastPathComponent action:@selector(destination:) keyEquivalent:@""];

    NSImage *menuItemIcon = [[NSWorkspace sharedWorkspace] iconForFile:dest.path];
    menuItemIcon.size = NSMakeSize(16, 16);

    folderItem.image = menuItemIcon;

    return folderItem;
}

- (IBAction)destination:(id)sender {
    if ([sender tag] == 10) {
        [self.options removeObjectForKey:@"SBQueueDestination"];
    } else {
        self.options[@"SBQueueDestination"] = self.destination;
    }
}

#pragma mark Sets PopUp

- (void)prepareSetsPopup {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSetsMenu:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];
    [self updateSetsMenu:self];
}

- (void)updateSetsMenu:(id)sender {
    self.sets = [SBPresetManager.shared.metadataPresets mutableCopy];
    if (![self.sets containsObject:(self.options)[@"SBQueueSet"]]) {
        [self.options removeObjectForKey:@"SBQueueSet"];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];



    @try {
        [self removeObserver:self forKeyPath:@"options.SBQueueMovieProvider"];
        [self removeObserver:self forKeyPath:@"options.SBQueueTVShowProvider"];
    } @catch (NSException * __unused exception) {}

}

@end
