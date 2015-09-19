//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42FileImporter;
@class MP42Track;
@class MP42Metadata;

@protocol SBFileImportDelegate
- (void)importDoneWithTracks:(NSArray<MP42Track *> *)tracksToBeImported andMetadata:(MP42Metadata *)metadata;
@end

@interface SBFileImport : NSWindowController <NSTableViewDelegate> {
@private
    NSArray<NSURL *>  *_fileURLs;

    NSMutableArray<MP42FileImporter *> *_fileImporters;
    NSMutableArray  *_tracks;
    
    NSMutableArray<NSNumber *> *_importCheckArray;
    NSMutableArray<NSNumber *> *_actionArray;

	id<SBFileImportDelegate> _delegate;

	IBOutlet NSTableView *tracksTableView;
	IBOutlet NSButton    *addTracksButton;
    IBOutlet NSButton    *importMetadata;
}

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithURLs:(NSArray<NSURL *> *)fileURLs delegate:(id <SBFileImportDelegate>)delegate error:(NSError **)error;

- (IBAction)closeWindow:(id)sender;
- (IBAction)addTracks:(id)sender;

@property (nonatomic, readonly) BOOL onlyContainsSubtitleTracks;

- (IBAction)checkSelected:(id)sender;
- (IBAction)uncheckSelected:(id)sender;

@end

NS_ASSUME_NONNULL_END
