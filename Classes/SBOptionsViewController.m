//
//  QueueOptionsController.m
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import "SBOptionsViewController.h"

@interface SBOptionsViewController ()

@property NSMutableDictionary *options;

- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@end

@implementation SBOptionsViewController

@synthesize options = _options;

- (instancetype)initWithOptions:(NSMutableDictionary *)options {
    self = [self init];
    if (self) {
        _options = [options retain];
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
}

- (void)prepareDestPopup {
    NSMenuItem *folderItem = nil;

    if ([self.options valueForKey:@"SBQueueDestination"]) {
        _destination = [[self.options valueForKey:@"SBQueueDestination"] retain];

    if (![[NSFileManager defaultManager] fileExistsAtPath:[_destination path] isDirectory:nil])
            _destination = nil;
    }

    if (!_destination) {
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if ([allPaths count])
            _destination = [[NSURL fileURLWithPath:[allPaths lastObject]] retain];;
    }

    folderItem = [self prepareDestPopupItem:_destination];

    [[_destButton menu] insertItem:[NSMenuItem separatorItem] atIndex:0];
    [[_destButton menu] insertItem:folderItem atIndex:0];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestinationSelected"] boolValue]) {
        [_destButton selectItem:folderItem];
        _customDestination = YES;
    }
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = [anItem action];

    if (action == @selector(chooseDestination:))
        return YES;

    if (action == @selector(destination:))
        return YES;
    
    return NO;
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
            _destination = [[panel URL] retain];

            NSMenuItem *folderItem = [self prepareDestPopupItem:[panel URL]];

            [[_destButton menu] removeItemAtIndex:0];
            [[_destButton menu] insertItem:folderItem atIndex:0];

            [_destButton selectItem:folderItem];
            _customDestination = YES;

            [self.options setValue:[panel URL] forKey:@"SBQueueDestination"];
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        }
        else
            [_destButton selectItemAtIndex:2];
    }];
}

- (NSMenuItem *)prepareDestPopupItem:(NSURL*) dest {
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:[dest lastPathComponent] action:@selector(destination:) keyEquivalent:@""];
    [folderItem setTag:10];

    NSImage *menuItemIcon = [[NSWorkspace sharedWorkspace] iconForFile:[dest path]];
    [menuItemIcon setSize:NSMakeSize(16, 16)];

    [folderItem setImage:menuItemIcon];

    return [folderItem autorelease];
}

- (IBAction)destination:(id)sender {
    if ([sender tag] == 10) {
        _customDestination = YES;
        [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
    } else {
        _customDestination = NO;
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"SBQueueDestinationSelected"];
    }
}

- (void)dealloc {
    [_options release];
    [super dealloc];
}

@end
