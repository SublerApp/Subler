//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42Metadata;

@protocol SBFileImportDelegate
- (void)importDoneWithTracks:(NSArray *)tracksToBeImported andMetadata:(MP42Metadata *)metadata;
@end

@interface SBFileImport : NSWindowController <NSTableViewDelegate> {
@private
    NSArray         *_fileURLs;
    NSMutableArray  *_fileImporters;
    NSMutableArray  *_tracks;
    
    NSMutableArray		*_importCheckArray;
    NSMutableArray      *_actionArray;

	id<SBFileImportDelegate> delegate;
	IBOutlet NSTableView *tracksTableView;
	IBOutlet NSButton    *addTracksButton;
    IBOutlet NSButton    *importMetadata;
}

- (instancetype)initWithDelegate:(id <SBFileImportDelegate>)del andFiles:(NSArray *)files error:(NSError **)outError;

- (IBAction)closeWindow:(id)sender;
- (IBAction)addTracks:(id)sender;

- (BOOL)onlyContainsSubtitleTracks;

- (IBAction)checkSelected:(id)sender;
- (IBAction)uncheckSelected:(id)sender;

@end
