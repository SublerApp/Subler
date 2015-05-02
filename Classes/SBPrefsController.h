//
//  SBPrefsController.h
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBMovieViewController;
@class SBTableView;

@interface SBPrefsController : NSWindowController <NSToolbarDelegate, NSWindowDelegate> {
@private
    IBOutlet NSView *generalView, *advancedView, *setsView;

    NSPopover *_popover;
    SBMovieViewController *_controller;
    NSInteger _currentRow;

    IBOutlet SBTableView *tableView;
    IBOutlet NSButton    *removeSet;
}

+ (void)registerUserDefaults;

- (instancetype)init;
- (IBAction)clearRecentSearches:(id) sender;
- (IBAction)deleteCachedMetadata:(id) sender;
- (IBAction)toggleInfoWindow:(id) sender;

- (IBAction)deletePreset:(id) sender;

- (IBAction)updateRatingsCountry:(id)sender;

@end
