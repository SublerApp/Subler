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
@class MP42MetadataItem;

@interface SBMovieViewController : NSViewController

@property (nonatomic, readwrite) MP42Metadata *metadata;

- (IBAction)addTag:(id)sender;
- (IBAction)removeTag:(id)sender;

- (IBAction)addMetadataSet:(id)sender;

- (void)addMetadataItems:(NSArray<MP42MetadataItem *> *)items;
- (void)removeMetadataItems:(NSArray<MP42MetadataItem *> *)items;

- (void)addMetadataCoverArtItems:(NSArray<MP42MetadataItem *> *)items;
- (void)removeMetadataCoverArtItems:(NSArray<MP42MetadataItem *> *)items;

@property (nonatomic, weak) IBOutlet NSPopUpButton *setsPopUp;

// Set save window
@property (nonatomic, strong) IBOutlet NSWindow *saveSetWindow;
@property (nonatomic, weak) IBOutlet NSTextField *saveSetName;

@property (nonatomic, weak) IBOutlet NSButton *keepArtworks;
@property (nonatomic, weak) IBOutlet NSButton *keepAnnotations;

- (IBAction)zoomSliderDidChange:(id)sender;

- (IBAction)selectArtwork:(id)sender;
- (IBAction)removeArtwork:(id)sender;

@end

NS_ASSUME_NONNULL_END
