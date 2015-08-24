//
//  SBPrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Ratings.h>

#import "SBPrefsController.h"
#import "SBMetadataSearchController.h"
#import "SBPresetManager.h"
#import "SBTableView.h"
#import "SBMovieViewController.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_ADVANCED    @"TOOLBAR_ADVANCED"
#define TOOLBAR_SETS        @"TOOLBAR_SETS"

@interface SBPrefsController ()
- (NSArray *)ratingsCountries;

- (void)setPrefView:(id)sender;
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier
                                       label:(NSString *)label
                                       image:(NSImage *)image;
@end

@implementation SBPrefsController

+ (void)registerUserDefaults
{    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"SBSaveFormat":                  @"m4v",
                                                              @"defaultSaveFormat":             @"0",
                                                              @"SBOrganizeAlternateGroups":     @"YES",
                                                              @"SBAudioMixdown":                @"1",
                                                              @"SBAudioBitrate":                @"96",
                                                              @"SBAudioConvertAC3":             @"YES",
                                                              @"SBAudioKeepAC3":                @"YES",
                                                              @"SBAudioConvertDts":             @"YES",
                                                              @"SBAudioKeepDts":                @"NO",
                                                              @"SBSubtitleConvertBitmap":       @"YES",
                                                              @"SBRatingsCountry":              @"All countries",
                                                              @"SBSaveFormat":                  @"m4v",
                                                              @"mp464bitOffset":                @"NO",
                                                              @"chaptersPreviewTrack":          @"YES",

                                                              @"SBMetadataPreference|Movie": @"TheMovieDB",
                                                              @"SBMetadataPreference|Movie|iTunes Store|Language": @"USA (English)",
                                                              @"SBMetadataPreference|Movie|TheMovieDB|Language": @"English",
                                                              @"SBMetadataPreference|TV": @"TheTVDB",
                                                              @"SBMetadataPreference|TV|iTunes Store|Language": @"USA (English)",
                                                              @"SBMetadataPreference|TV|TheTVDB|Language": @"English"}];
}

- (instancetype)init
{
    if ((self = [super initWithWindowNibName:@"Prefs"])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateTableView:)
                                                     name:@"SBPresetManagerUpdatedNotification" object:nil];
    }

    return self;
}

- (void)awakeFromNib
{
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: @"Preferences Toolbar"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode:NSToolbarSizeModeRegular];
    [[self window] setToolbar:toolbar];

    [toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)ident
 willBeInsertedIntoToolbar:(BOOL)flag
{
    if ([ident isEqualToString:TOOLBAR_GENERAL]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"General", @"Preferences General Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    }
    else if ([ident isEqualToString:TOOLBAR_ADVANCED]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Advanced", @"Preferences Audio Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameAdvanced]];
    }
    else if ([ident isEqualToString:TOOLBAR_SETS]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Sets", @"Preferences Sets Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameFolderSmart]];
    }    

    return nil;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return @[TOOLBAR_GENERAL, TOOLBAR_SETS, TOOLBAR_ADVANCED];
}

- (IBAction)clearRecentSearches:(id)sender {
    [SBMetadataSearchController clearRecentSearches];
}

- (IBAction)deleteCachedMetadata:(id)sender {
    [SBMetadataSearchController deleteCachedMetadata];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    return [[presetManager presets] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    if ([aTableColumn.identifier isEqualToString:@"name"]) {
        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        return [[[presetManager presets] objectAtIndex:rowIndex] presetName];
    }
    return nil;
}

- (IBAction)deletePreset:(id)sender
{
    [self closePopOver:self];

    NSInteger rowIndex = [tableView selectedRow];
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager removePresetAtIndex:rowIndex];
    [tableView reloadData];
}

- (IBAction)closePopOver:(id)sender
{
    if (_popover) {
        [_popover close];

        [_popover release];
        _popover = nil;
        [_controller release];
        _controller = nil;
    }
}

- (IBAction)toggleInfoWindow:(id)sender
{
    if (_currentRow == [tableView clickedRow] && _popover) {
        [self closePopOver:sender];
    } else {
        _currentRow = [tableView clickedRow];
        [self closePopOver:sender];

        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        _controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [_controller setMetadata:[[presetManager presets] objectAtIndex:_currentRow]];

        _popover = [[NSPopover alloc] init];
        _popover.contentViewController = _controller;
        _popover.contentSize = NSMakeSize(480.0f, 500.0f);

        [_popover showRelativeToRect:[tableView frameOfCellAtColumn:1 row:_currentRow] ofView:tableView preferredEdge:NSMaxYEdge];
    }
}

- (void)updateTableView:(id)sender
{
    [tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([tableView selectedRow] != -1)
        [removeSet setEnabled:YES];
    else
        [removeSet setEnabled:NO];
}

- (NSArray *)ratingsCountries {
	return [[MP42Ratings defaultManager] ratingsCountries];
}

- (IBAction) updateRatingsCountry:(id)sender {
	[[MP42Ratings defaultManager] updateRatingsCountry];
}

- (void)setPrefView:(id)sender
{
    NSView *view = generalView;
    if (sender) {
        NSString *identifier = [sender itemIdentifier];
        if ([identifier isEqualToString: TOOLBAR_ADVANCED])
            view = advancedView;
        else if ([identifier isEqualToString: TOOLBAR_SETS])
            view = setsView;
    }

    NSWindow *window = [self window];
    if ([window contentView] == view)
        return;

    NSRect windowRect = [window frame];
    CGFloat difference = ([view frame].size.height - [[window contentView] frame].size.height);
    windowRect.origin.y -= difference;
    windowRect.size.height += difference;

    [view setHidden:YES];
    [window setContentView:view];
    [window setFrame:windowRect display:YES animate:YES];
    [view setHidden:NO];

    //set title label
    if (sender)
        [window setTitle:[sender label]];
    else {
        NSToolbar *toolbar = [window toolbar];
        NSString *itemIdentifier = [toolbar selectedItemIdentifier];
        for (NSToolbarItem *item in [toolbar items])
            if ([[item itemIdentifier] isEqualToString:itemIdentifier]) {
                [window setTitle: [item label]];
                break;
            }
    }
}

- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier
                                       label:(NSString *)label
                                       image:(NSImage *)image
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    [item setLabel:label];
    [item setImage:image];
    [item setAction:@selector(setPrefView:)];
    [item setAutovalidates:NO];
    return [item autorelease];
}

@end
