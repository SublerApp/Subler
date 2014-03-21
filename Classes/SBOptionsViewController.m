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

@interface SBOptionsViewController ()

@property (nonatomic) NSMutableDictionary *options;
@property (nonatomic, copy) NSMutableArray *sets;

- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@property (nonatomic, retain) NSURL *destination;

@end

@implementation SBOptionsViewController

@synthesize options = _options;
@synthesize sets = _sets;

@synthesize destination = _destination;

- (instancetype)initWithOptions:(NSMutableDictionary *)options {
    self = [self init];
    if (self) {
        _options = [options retain];
        _sets = [[NSMutableArray alloc] init];
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
    [panel beginSheetModalForWindow:nil completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMenuItem *folderItem = [self prepareDestPopupItem:[panel URL]];

            [[_destButton menu] removeItemAtIndex:0];
            [[_destButton menu] insertItem:folderItem atIndex:0];

            [_destButton selectItem:folderItem];

            [self.options setValue:[panel URL] forKey:@"SBQueueDestination"];
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        }
        else
            [_destButton selectItemAtIndex:2];
    }];
}

- (NSMenuItem *)prepareDestPopupItem:(NSURL*) dest {
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

- (void)prepareSetsPopup {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSetsMenu:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];
    [self updateSetsMenu:self];
}

- (void)updateSetsMenu:(id)sender {
    self.sets = [[SBPresetManager sharedManager].presets mutableCopy];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_options release];
    [_sets release];
    [_destination release];

    [super dealloc];
}

@end
