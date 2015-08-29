//
//  MovieViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42File;
@class MP42Metadata;
@class SBTableView;
@class SBImageBrowserView;

@interface SBMovieViewController : NSViewController {
    MP42Metadata            *metadata;

    IBOutlet NSPopUpButton  *tagList;
    IBOutlet NSPopUpButton  *setList;

    IBOutlet SBTableView    *tagsTableView;

    IBOutlet NSPopUpButton  *mediaKind;
    IBOutlet NSPopUpButton  *contentRating;
    IBOutlet NSPopUpButton  *hdVideo;
    IBOutlet NSButton       *gapless;
    IBOutlet NSButton       *podcast;

    IBOutlet NSButton       *removeTag;

    IBOutlet NSWindow       *saveWindow;
    IBOutlet NSTextField    *presetName;
    
    NSPopUpButtonCell       *ratingCell;
    NSComboBoxCell          *genreCell;

    NSDictionary<NSString *, id> *tags;
    NSArray<NSString *> *_tagsArray;
    NSDictionary    *detailBoldAttr;

    NSMutableDictionary  *dct;
    NSTableColumn *tabCol;
    CGFloat width;
    
    IBOutlet SBImageBrowserView *imageBrowser;

    IBOutlet NSButton       *addArtwork;
    IBOutlet NSButton       *removeArtwork;
}

- (void) setFile: (MP42File *)file;
- (void) setMetadata: (MP42Metadata *)data;

- (IBAction) addTag: (id) sender;
- (IBAction) removeTag: (id) sender;

- (IBAction) addMetadataSet: (id)sender;

- (IBAction) showSaveSet: (id)sender;
- (IBAction) closeSaveSheet: (id) sender;
- (IBAction) saveSet: (id)sender;

- (IBAction) changeMediaKind: (id) sender;
- (IBAction) changecContentRating: (id) sender;
- (IBAction) changeGapless: (id) sender;
- (IBAction) changePodcast: (id) sender;
- (IBAction) changehdVideo: (id) sender;

- (IBAction) zoomSliderDidChange:(id)sender;

- (IBAction) selectArtwork: (id) sender;
- (IBAction) removeArtwork: (id) sender;

@end

NS_ASSUME_NONNULL_END
