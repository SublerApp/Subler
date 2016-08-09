//
//  SBPrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "SBPrefsController.h"
#import "SBMetadataPrefsViewController.h"
#import "SBMetadataSearchController.h"
#import "SBPresetManager.h"
#import "SBMovieViewController.h"
#import "SBMetadataResultMap.h"

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Ratings.h>

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_METADATA    @"TOOLBAR_METADATA"
#define TOOLBAR_ADVANCED    @"TOOLBAR_ADVANCED"
#define TOOLBAR_SETS        @"TOOLBAR_SETS"

@interface SBPrefsController () <NSWindowDelegate>

@property (nonatomic, strong) IBOutlet NSView *generalView;
@property (nonatomic, strong) IBOutlet NSView *advancedView;
@property (nonatomic, strong) IBOutlet NSView *setsView;
@property (nonatomic, strong) SBMetadataPrefsViewController *metadataController;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSButton *removeSetButton;

@property (nonatomic, readwrite) SBMovieViewController *controller;
@property (nonatomic, readwrite) NSPopover *popover;
@property (nonatomic, readwrite) NSInteger currentRow;

@end

@implementation SBPrefsController

+ (void)registerUserDefaults
{
    NSData *movieDefaultMap = [NSKeyedArchiver archivedDataWithRootObject:[SBMetadataResultMap movieDefaultMap]];
    NSData *tvShowDefaultMap = [NSKeyedArchiver archivedDataWithRootObject:[SBMetadataResultMap tvShowDefaultMap]];

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
                                                              @"SBMetadataPreference|TV|TheTVDB|Language": @"English",

                                                              @"SBMetadataMovieResultMap" : movieDefaultMap,
                                                              @"SBMetadataTvShowResultMap" : tvShowDefaultMap,
                                                              @"SBMetadataKeepEmptyAnnotations" : @NO,
                                                              }];
}

- (instancetype)init
{
    if ((self = [super initWithWindowNibName:@"Prefs"])) {
        _metadataController = [[SBMetadataPrefsViewController alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateTableView:)
                                                     name:@"SBPresetManagerUpdatedNotification" object:nil];
    }

    return self;
}

- (void)awakeFromNib
{
    self.window.toolbar.allowsUserCustomization = NO;
    [self.window.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

#pragma mark - General

- (IBAction)clearRecentSearches:(id)sender
{
    [SBMetadataSearchController clearRecentSearches];
}

- (IBAction)deleteCachedMetadata:(id)sender
{
    [SBMetadataSearchController deleteCachedMetadata];
}

- (NSArray *)ratingsCountries
{
    return [[MP42Ratings defaultManager] ratingsCountries];
}

- (IBAction) updateRatingsCountry:(id)sender
{
    [[MP42Ratings defaultManager] updateRatingsCountry];
}

#pragma mark - Sets

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    return presetManager.presets.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"name"]) {
        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        return presetManager.presets[rowIndex].presetName;
    }
    return nil;
}

- (IBAction)deletePreset:(id)sender
{
    [self closePopOver:self];

    NSInteger rowIndex = self.tableView.selectedRow;
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager removePresetAtIndex:rowIndex];
    [self.tableView reloadData];
}

- (IBAction)closePopOver:(id)sender
{
    if (self.popover) {
        [self.popover close];

        self.popover = nil;
        self.controller = nil;
    }
}

- (IBAction)toggleInfoWindow:(id)sender
{
    if (self.currentRow == self.tableView.clickedRow && _popover) {
        [self closePopOver:sender];
    }
    else {
        self.currentRow = self.tableView.clickedRow;
        [self closePopOver:sender];

        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        self.controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [self.controller setMetadata:presetManager.presets[_currentRow]];

        self.popover = [[NSPopover alloc] init];
        self.popover.contentViewController = _controller;
        self.popover.contentSize = NSMakeSize(480.0f, 500.0f);

        [self.popover showRelativeToRect:[self.tableView frameOfCellAtColumn:1 row:self.currentRow] ofView:self.tableView preferredEdge:NSMaxYEdge];
    }
}

- (void)updateTableView:(id)sender
{
    [self.tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (self.tableView.selectedRow != -1) {
        self.removeSetButton.enabled = YES;
    }
    else {
        self.removeSetButton.enabled = NO;
    }
}

- (IBAction)setPrefView:(id)sender
{
    NSView *view = self.generalView;
    if (sender) {
        NSString *identifier = [sender itemIdentifier];
        if ([identifier isEqualToString:TOOLBAR_ADVANCED]) {
            view = self.advancedView;
        }
        else if ([identifier isEqualToString:TOOLBAR_SETS]) {
            view = self.setsView;
        }
        else if ([identifier isEqualToString:TOOLBAR_METADATA]) {
            view = self.metadataController.view;
        }
    }

    NSWindow *window = self.window;
    if (window.contentView == view) {
        return;
    }

    window.contentView = view;

    if (window.isVisible) {
        view.hidden = YES;

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.allowsImplicitAnimation = YES;
            [window layoutIfNeeded];

        } completionHandler:^{
            view.hidden = NO;
            [self SB_setTitle:sender];
        }];
    }
    else {
        [self SB_setTitle:sender];
    }
}

- (void)SB_setTitle:(id)sender
{
    // Set title label
    if (sender) {
        self.window.title = [sender label];
    }
    else {
        NSToolbar *toolbar = self.window.toolbar;
        NSString *itemIdentifier = toolbar.selectedItemIdentifier;
        for (NSToolbarItem *item in toolbar.items)
            if ([item.itemIdentifier isEqualToString:itemIdentifier]) {
                self.window.title = item.label;
                break;
            }
    }
}

@end
