//
//  QueueOptionsController.m
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import "SBOptionsViewController.h"
#import "SBPresetManager.h"

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import "MetadataImporter.h"

static void *SBOptionsViewContex = &SBOptionsViewContex;

@interface SBOptionsViewController ()

@property (nonatomic) NSMutableDictionary *options;
@property (nonatomic, retain) NSMutableArray *sets;

@property (nonatomic, retain) NSArray *moviesProviders;
@property (nonatomic, retain) NSArray *tvShowsProviders;
@property (nonatomic, retain) NSArray *movieLanguages;
@property (nonatomic, retain) NSArray *tvShowLanguages;

- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@property (nonatomic, retain) NSURL *destination;

@end

@implementation SBOptionsViewController

@synthesize options = _options;
@synthesize sets = _sets;
@synthesize moviesProviders = _moviesProviders;
@synthesize tvShowsProviders = _tvShowsProviders;
@synthesize movieLanguages = _movieLanguages;
@synthesize tvShowLanguages = _tvShowLanguages;

@synthesize destination = _destination;

- (instancetype)initWithOptions:(NSMutableDictionary *)options {
    self = [self init];
    if (self) {
        _options = [options retain];
        _sets = [[NSMutableArray alloc] init];
        _moviesProviders = [[MetadataImporter movieProviders] retain];
        _tvShowsProviders = [[MetadataImporter tvProviders] retain];

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
                [string release];
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
    SEL action = [anItem action];

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

            NSString *oldLanguage = [self.options valueForKey:@"SBQueueMovieProviderLanguage"];
            self.movieLanguages = [MetadataImporter languagesForProvider:newProvider];

            if (![self.movieLanguages containsObject:oldLanguage]) {
                [self.options setValue:[MetadataImporter defaultLanguageForProvider:newProvider] forKeyPath:@"SBQueueMovieProviderLanguage"];
            }
        } else if ([keyPath isEqualToString:@"options.SBQueueTVShowProvider"]) {
            NSString *newProvider = [change valueForKey:NSKeyValueChangeNewKey];

            NSString *oldLanguage = [self.options valueForKey:@"SBQueueTVShowProviderLanguage"];

            self.tvShowLanguages = [MetadataImporter languagesForProvider:newProvider];
            if (![self.tvShowLanguages containsObject:oldLanguage]) {
                [self.options setValue:[MetadataImporter defaultLanguageForProvider:newProvider] forKeyPath:@"SBQueueTVShowProviderLanguage"];
            }
        } else {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
}

#pragma mark Destination PopUp

- (void)prepareDestPopup {
    NSMenuItem *folderItem = nil;

    if ([self.options valueForKey:@"SBQueueDestination"]) {
        self.destination = [self.options valueForKey:@"SBQueueDestination"];

        if (![[NSFileManager defaultManager] fileExistsAtPath:[self.destination path] isDirectory:nil])
            self.destination = nil;
    }

    if (!self.destination) {
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if ([allPaths count]) {
            self.destination = [NSURL fileURLWithPath:[allPaths lastObject]];
        }
    }

    folderItem = [self prepareDestPopupItem:self.destination];

    [[_destButton menu] insertItem:[NSMenuItem separatorItem] atIndex:0];
    [[_destButton menu] insertItem:folderItem atIndex:0];

    if ([self.options valueForKey:@"SBQueueDestination"]) {
        [_destButton selectItem:folderItem];
    } else {
        [_destButton selectItemWithTag:10];
    }
}

- (IBAction)chooseDestination:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;

    [panel setPrompt:@"Select"];
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMenuItem *folderItem = [self prepareDestPopupItem:[panel URL]];

            [[_destButton menu] removeItemAtIndex:0];
            [[_destButton menu] insertItem:folderItem atIndex:0];

            [_destButton selectItem:folderItem];

            [self.options setValue:[panel URL] forKey:@"SBQueueDestination"];
            self.destination = panel.URL;
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        } else {
            [_destButton selectItemAtIndex:2];
        }
    }];
}

- (NSMenuItem *)prepareDestPopupItem:(NSURL *)dest {
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:[dest lastPathComponent] action:@selector(destination:) keyEquivalent:@""];

    NSImage *menuItemIcon = [[NSWorkspace sharedWorkspace] iconForFile:[dest path]];
    [menuItemIcon setSize:NSMakeSize(16, 16)];

    [folderItem setImage:menuItemIcon];

    return [folderItem autorelease];
}

- (IBAction)destination:(id)sender {
    if ([sender tag] == 10) {
        [self.options removeObjectForKey:@"SBQueueDestination"];
    } else {
        [self.options setObject:self.destination forKey:@"SBQueueDestination"];
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
    self.sets = [[[SBPresetManager sharedManager].presets mutableCopy] autorelease];
    if (![self.sets containsObject:[self.options objectForKey:@"SBQueueSet"]]) {
        [self.options removeObjectForKey:@"SBQueueSet"];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_options release];
    [_sets release];
    [_destination release];

    [_moviesProviders release];
    [_tvShowsProviders release];

    [_movieLanguages release];
    [_tvShowLanguages release];

    @try {
        [self removeObserver:self forKeyPath:@"options.SBQueueMovieProvider"];
        [self removeObserver:self forKeyPath:@"options.SBQueueTVShowProvider"];
    } @catch (NSException * __unused exception) {}

    [super dealloc];
}

@end
