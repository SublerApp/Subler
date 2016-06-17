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

@interface SBMovieViewController : NSViewController

@property (nonatomic, readwrite) MP42Metadata *metadata;

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
