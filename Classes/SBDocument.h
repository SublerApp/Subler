//
//  SBDocument.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42File;
@class ExpandedTableView;

@interface SBDocument : NSDocument

@property (nonatomic, strong) MP42File *mp4;

- (instancetype)initWithMP4:(MP42File *)mp4File error:(NSError * __autoreleasing *)outError;

@property (nonatomic, weak) IBOutlet ExpandedTableView *tracksTable;
@property (nonatomic, strong, nullable) NSWindowController *sheetController;

- (IBAction)selectFile:(id)sender;
- (IBAction)deleteTrack:(id)sender;
- (IBAction)sendToQueue:(id)sender;

- (IBAction)showTrackOffsetSheet:(id)sender;
- (IBAction)setTrackOffset:(id)sender;
- (IBAction)closeOffsetSheet:(id)sender;

- (IBAction)setSaveFormat:(NSPopUpButton *)sender;
- (IBAction)cancelSaveOperation:(id)sender;
- (IBAction)sendToExternalApp:(id)sender;

- (IBAction)saveAndOptimize:(id)sender;

- (IBAction)selectMetadataFile:(id)sender;
- (IBAction)addChaptersEvery:(id)sender;
- (IBAction)iTunesFriendlyTrackGroups:(id)sender;

- (IBAction)export:(id)sender;

- (void)reload;
- (void)reloadPropertyView;

@end

NS_ASSUME_NONNULL_END
