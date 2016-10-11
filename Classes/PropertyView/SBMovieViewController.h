//
//  MovieViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42Metadata;

@interface SBMovieViewController : NSViewController

@property (nonatomic, readwrite) MP42Metadata *metadata;

- (IBAction)addTag:(id)sender;
- (IBAction)removeTag:(id)sender;

- (IBAction)addMetadataSet:(id)sender;

- (IBAction)showSaveSet:(id)sender;
- (IBAction)closeSaveSheet:(id)sender;
- (IBAction)saveSet:(id)sender;

- (IBAction)zoomSliderDidChange:(id)sender;

- (IBAction)selectArtwork:(id)sender;
- (IBAction)removeArtwork:(id)sender;

@end

NS_ASSUME_NONNULL_END
