//
//  SBDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import "SBDocument.h"
#import "SBQueueController.h"
#import "SBQueueItem.h"
#import "SBFileImport.h"
#import "SBTableView.h"

#import "SBEmptyViewController.h"
#import "SBMovieViewController.h"
#import "SBVideoViewController.h"
#import "SBSoundViewController.h"
#import "SBChapterViewController.h"

#import "SBMetadataSearchController.h"
#import "SBArtworkSelector.h"
#import "SBMetadataResult.h"
#import "SBMetadataResultMap.h"

#import "SBChapterSearchController.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Languages.h>
#import <MP42Foundation/MP42Utilities.h>

#define SublerTableViewDataType @"SublerTableViewDataType"

@interface SBDocument () <NSTableViewDelegate, SBFileImportDelegate, SBMetadataSearchControllerDelegate, SBChapterSearchControllerDelegate>
{
    IBOutlet NSSplitView    *splitView;

    NSSavePanel                     *_currentSavePanel;
    IBOutlet NSView                 *saveView;
    IBOutlet NSPopUpButton          *fileFormat;

    IBOutlet NSToolbarItem  *addTracks;
    IBOutlet NSToolbarItem  *deleteTrack;
    IBOutlet NSToolbarItem  *searchMetadata;
    IBOutlet NSToolbarItem  *searchChapters;
    IBOutlet NSToolbarItem  *sendToQueue;

    NSArray<NSString *> *languages;

    NSViewController        *propertyView;
    IBOutlet NSView         *targetView;

    IBOutlet NSWindow       *offsetWindow;
    IBOutlet NSTextField    *offset;

    IBOutlet NSButton *cancelSave;
    IBOutlet NSButton *_64bit_data;
    IBOutlet NSButton *_64bit_time;
    BOOL _optimize;

    NSDictionary                 *_detailMonospacedAttr;
}

@property (nonatomic, weak) IBOutlet NSWindow *documentWindow;
@property (nonatomic, weak) IBOutlet SBTableView *tracksTable;

@property (nonatomic, weak) IBOutlet NSWindow *saveWindow;
@property (nonatomic, weak) IBOutlet NSTextField *saveOperationName;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressBar;

@property (nonatomic, strong) MP42File *mp4;

@property (nonatomic, strong) NSWindowController *sheetController;

@end

@implementation SBDocument

- (NSString *)windowNibName
{
    return @"SBDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    languages = [[MP42Languages defaultManager] languages];
    _optimize = NO;

    [self reloadPropertyView];
    sendToQueue.image = [NSImage imageNamed:NSImageNameShareTemplate];

    [self.tracksTable registerForDraggedTypes:@[SublerTableViewDataType]];
    [self.documentWindow registerForDraggedTypes:@[NSFilenamesPboardType]];

    [self.progressBar setUsesThreadedAnimation:NO];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"rememberWindowSize"] integerValue]) {
        [self.documentWindow setFrameAutosaveName:@"documentSave"];
        [self.documentWindow setFrameUsingName:@"documentSave"];
        splitView.autosaveName = @"splitViewSave";
    }

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        NSFont *font = [NSFont monospacedDigitSystemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular];
        NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        ps.alignment = NSTextAlignmentRight;

        _detailMonospacedAttr = @{NSFontAttributeName: font,
                         NSParagraphStyleAttributeName: ps};

    }
}

- (instancetype)initWithMP4:(MP42File *)mp4File error:(NSError * __autoreleasing *)outError
{
    if (self = [super initWithType:@"Video-MPEG4" error:outError]) {
        self.mp4 = mp4File;
        if (mp4File.URL){
            self.fileURL = mp4File.URL;
        }
        else {
            [self updateChangeCount:NSChangeDone];
        }
    }

    return self;
}

- (instancetype)initWithType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    if (self = [super initWithType:typeName error:outError]) {
        self.mp4 = [[MP42File alloc] init];
    }

    return self;
}


#pragma mark - Read methods

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)type
{
    return NO;
}

- (BOOL)isEntireFileLoaded
{
    return NO;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    self.mp4 = [[MP42File alloc] initWithURL:absoluteURL error:outError];

    if (!self.mp4) {
        return NO;
	}

    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing *)outError
{
    self.mp4 = [[MP42File alloc] initWithURL:absoluteURL error:outError];

    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeCleared];

    if (!self.mp4) {
        return NO;
	}
    return YES;
}

#pragma mark - Save methods

- (IBAction)cancelSaveOperation:(id)sender
{
    [cancelSave setEnabled:NO];
    [self.mp4 cancel];
}

- (IBAction)saveAndOptimize:(id)sender
{
    _optimize = YES;
    [self saveDocument:sender];
}

- (IBAction)sendToExternalApp:(id)sender
{
    // Send to itunes after save.
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *appPath = [workspace fullPathForApplication:@"iTunes"];

    if (appPath) {
        [workspace openFile:self.fileURL.path withApplication:appPath];
    }
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation
{
    return YES;
}

/**
 * Show the progress modal sheet.
 */
- (void)showProgressSheet
{
    self.progressBar.doubleValue = 0;
    self.progressBar.indeterminate = YES;
    self.saveOperationName.stringValue = NSLocalizedString(@"Saving…", @"Document Saving sheet.");

    [self.progressBar startAnimation:self];
    [self.windowForSheet beginSheet:self.saveWindow completionHandler:NULL];
}

- (void)endProgressSheet
{
    [self.progressBar stopAnimation:self];
    [self.windowForSheet endSheet:self.saveWindow];
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    void (^modifiedCompletionhandler)(NSError * _Nullable) = ^void(NSError * _Nullable error) {
        MP42File *reloadedFile = nil;
        NSError *reloadError;

        if (error == nil) {
            reloadedFile = [[MP42File alloc] initWithURL:[NSURL fileURLWithPath:url.path] error:&reloadError];
        }

        [self endProgressSheet];

        if (reloadedFile) {
            self.mp4 = reloadedFile;

            [self.tracksTable reloadData];
            [self reloadPropertyView];

            completionHandler(error);
        }
        else if (reloadError) {
            completionHandler(reloadError);
        }
        else {
            completionHandler(error);
        }
    };

    [self showProgressSheet];
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:modifiedCompletionhandler];
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError * _Nullable *)outError
{
    [self unblockUserInteraction];

    IOPMAssertionID assertionID;
    // Enable sleep assertion
    CFStringRef reasonForActivity= CFSTR("Subler Save Operation");
    IOReturn io_success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
    BOOL result = NO;
    NSDictionary<NSString *, NSNumber *> *options = [self saveAttributes];

    __weak SBDocument *weakSelf = self;
    self.mp4.progressHandler = ^(double progress){
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.progressBar setIndeterminate:NO];
            weakSelf.progressBar.doubleValue = progress;
        });
    };

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBOrganizeAlternateGroups"] boolValue]) {
        [self.mp4 organizeAlternateGroups];
    }

    switch (saveOperation) {
        case NSSaveOperation:
            // movie file already exists, so we'll just update
            // the movie resource.
            result = [self.mp4 updateMP4FileWithOptions:options error:outError];
            break;

        case NSSaveAsOperation:
            // movie does not exist, create a new one from scratch.
            result = [self.mp4 writeToUrl:url options:options error:outError];
            break;

        default:
            NSAssert(NO, @"Unhandled save operation");
            break;
    }

    if (result && _optimize) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.saveOperationName setStringValue:NSLocalizedString(@"Optimizing…", @"Document Optimize sheet.")];
        });
        result = [self.mp4 optimize];
        _optimize = NO;
    }

    self.mp4.progressHandler = nil;

    if (io_success == kIOReturnSuccess) {
        IOPMAssertionRelease(assertionID);
    }

    return result;
}

#pragma mark - Save panel

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    _currentSavePanel = savePanel;
    savePanel.extensionHidden = NO;
    savePanel.accessoryView = saveView;

    NSArray<NSString *> *formats = [self writableTypesForSaveOperation:NSSaveAsOperation];

    [fileFormat removeAllItems];
    for (NSString *format in formats) {
        [fileFormat addItemWithTitle:format];
    }

    [fileFormat selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] valueForKey:@"defaultSaveFormat"] integerValue]];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]) {
        _currentSavePanel.allowedFileTypes = @[[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]];
    }

    NSString *filename = nil;
    for (MP42Track *track in self.mp4.tracks) {
        if (track.sourceURL) {
            filename = track.sourceURL.lastPathComponent.stringByDeletingPathExtension;
            break;
        }
    }

    if (filename) {
        savePanel.nameFieldStringValue = filename;
    }

    if (self.mp4.dataSize > 4200000000) {
        _64bit_data.state = NSOnState;
    }

    return YES;
}

- (IBAction)setSaveFormat:(NSPopUpButton *)sender
{
    NSString *requiredFileType = nil;
    NSInteger index = sender.indexOfSelectedItem;

    switch (index) {
        case 0:
            requiredFileType = MP42FileTypeM4V;
            break;
        case 1:
            requiredFileType = MP42FileTypeMP4;
            break;
        case 2:
            requiredFileType = MP42FileTypeM4A;
            break;
        case 3:
            requiredFileType = MP42FileTypeM4A;
            break;
        case 4:
            requiredFileType = MP42FileTypeM4R;
            break;
        default:
            requiredFileType = MP42FileTypeM4V;
            break;
    }

    _currentSavePanel.allowedFileTypes = @[requiredFileType];
    [[NSUserDefaults standardUserDefaults] setObject:requiredFileType forKey:@"SBSaveFormat"];
}

- (NSDictionary<NSString *, NSNumber *> *)saveAttributes {
    NSMutableDictionary<NSString *, NSNumber *> * attributes = [[NSMutableDictionary alloc] init];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue]) {
        attributes[MP42GenerateChaptersPreviewTrack] = @YES;
    }

    if (_64bit_data.state) { attributes[MP4264BitData] = @YES; }
    if (_64bit_time.state) { attributes[MP4264BitTime] = @YES; }

    return attributes;
}

#pragma mark - Interface validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = anItem.action;

    if (action == @selector(saveDocument:))
        if (self.documentEdited)
            return YES;

    if (action == @selector(saveDocumentAs:))
        return YES;
    
    if (action == @selector(revertDocumentToSaved:))
        if (self.documentEdited)
            return YES;

    if (action == @selector(saveAndOptimize:))
        if (!self.documentEdited && (self.mp4).hasFileRepresentation)
            return YES;

    if (action == @selector(selectMetadataFile:))
        return YES;

    if (action == @selector(selectFile:))
        return YES;

    if (action == @selector(deleteTrack:))
        return YES;

    if (action == @selector(searchMetadata:))
        return YES;

    if (action == @selector(searchChapters:))
        return YES;

    if (action == @selector(sendToQueue:))
        return YES;

    if (action == @selector(sendToExternalApp:))
        return YES;

    if (action == @selector(showTrackOffsetSheet:) && self.tracksTable.selectedRow != -1)
        return YES;

    if (action == @selector(addChaptersEvery:))
        return YES;
    
    if (action == @selector(iTunesFriendlyTrackGroups:))
        return YES;

    if (action == @selector(fixAudioFallbacks:))
        return YES;

	if (action == @selector(export:) && self.tracksTable.selectedRow != -1)
		if ([[self.mp4 trackAtIndex:self.tracksTable.selectedRow] respondsToSelector:@selector(exportToURL:error:)] &&
            [self.mp4 trackAtIndex:self.tracksTable.selectedRow].muxed)
			return YES;

    return NO;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    if (toolbarItem == addTracks) {
        return YES;
    }

    if (toolbarItem == deleteTrack) {
        if (self.tracksTable.selectedRow != -1 && NSApp.active)
                return YES;
    }

    if (toolbarItem == searchMetadata) {
        return YES;
    }

    if (toolbarItem == searchChapters) {
        return YES;
    }

    if (toolbarItem == sendToQueue) {
        return YES;
    }

    return NO;
}

#pragma mark - Table Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.mp4.tracks.count;
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [self.mp4 trackAtIndex:rowIndex];

    if (!track) {
        return nil;
    }

    if ([tableColumn.identifier isEqualToString:@"trackId"]) {
        return (track.trackId == 0) ? @"na" : [NSString stringWithFormat:@"%d", track.trackId];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"]) {
        return track.name;
    }

    if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
        return track.formatSummary;
    }

    if ([tableColumn.identifier isEqualToString:@"trackEnabled"]) {
        return @(track.isEnabled);
    }

    if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {

        if (_detailMonospacedAttr) {
            return [[NSAttributedString alloc] initWithString:track.timeString attributes:_detailMonospacedAttr];
        }
        else {
            return track.timeString;
        }
    }

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
        return track.language;
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    MP42Track *track = [self.mp4 trackAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
        if (![track.language isEqualToString:anObject]) {
            track.language = anObject;
            [self updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"trackName"]) {
        if (![track.name isEqualToString:anObject]) {
            track.name = anObject;
            [self updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"trackEnabled"]) {
        if (!(track.enabled  == [anObject integerValue])) {
            track.enabled = [anObject boolValue];
            [self updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    [self reloadPropertyView];
}

- (void)reloadPropertyView
{
    if (propertyView.view != nil) {
        // remove the undo items from the dealloced view
        [self.undoManager removeAllActionsWithTarget:propertyView];

        // remove the current view
		[propertyView.view removeFromSuperview];

        // remove the current view controller
    }

    NSInteger row = self.tracksTable.selectedRow;

    id controller = nil;
    id track = (row != -1) ? [self.mp4 trackAtIndex:row] : nil;

    if (row == -1) {
        controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [(SBMovieViewController *)controller setMetadata:self.mp4.metadata];
    } else if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
        controller = [[SBChapterViewController alloc] initWithNibName:@"ChapterView" bundle:nil];
        [controller setTrack:track];
    } else if ([track isKindOfClass:[MP42VideoTrack class]]) {
        controller = [[SBVideoViewController alloc] initWithNibName:@"VideoView" bundle:nil];
        [controller setTrack:track];
        [controller setFile:self.mp4];
    } else if ([track isKindOfClass:[MP42AudioTrack class]]) {
        controller = [[SBSoundViewController alloc] initWithNibName:@"SoundView" bundle:nil];
        [controller setSoundTrack:track];
        [controller setFile:self.mp4];
    } else {
        controller = [[SBEmptyViewController alloc] initWithNibName:@"EmptyView" bundle:nil];
    }

    propertyView = controller;

    // embed the current view to our host view
	[targetView addSubview:propertyView.view];
    [self.documentWindow recalculateKeyViewLoop];

	// make sure we automatically resize the controller's view to the current window size
	propertyView.view.frame = targetView.bounds;
    propertyView.view.autoresizingMask = ( NSViewWidthSizable | NSViewHeightSizable );
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    // Copy the row numbers to the pasteboard.
    if ([self.mp4 trackAtIndex:rowIndexes.firstIndex].muxed) {
        return NO;
    }

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:@[SublerTableViewDataType] owner:self];
    [pboard setData:data forType:SublerTableViewDataType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    NSUInteger count = self.mp4.tracks.count;
    if (op == NSTableViewDropAbove && row < count) {
        if (![self.mp4 trackAtIndex:row].muxed) {
            return NSDragOperationEvery;
        }
    } else if (op == NSTableViewDropAbove && row == count) {
        return NSDragOperationEvery;
    }

    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSData *rowData = [pboard dataForType:SublerTableViewDataType];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSInteger dragRow = rowIndexes.firstIndex;
    
    [self.mp4 moveTrackAtIndex:dragRow toIndex:row];

    [self.tracksTable reloadData];
    return YES;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
    return YES;
}

#pragma mark - NSComboBoxCell dataSource

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell
{
    return languages.count;
}

- (id)comboBoxCell:(NSComboBoxCell *)comboBoxCell objectValueForItemAtIndex:(NSInteger)index {
    return languages[index];
}

- (NSUInteger)comboBoxCell:(NSComboBoxCell *)comboBoxCell indexOfItemWithStringValue:(NSString *)string {
    return [languages indexOfObject: string];
}

#pragma mark - Various things

- (IBAction)sendToQueue:(id)sender
{
    SBQueueController *queue =  [SBQueueController sharedManager];
    if ((self.mp4).hasFileRepresentation) {
        SBQueueItem *item = [SBQueueItem itemWithMP4:self.mp4];
        [queue addItem:item];
        [self close];
    } else {
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.prompt = NSLocalizedString(@"Send To Queue", nil);

        [self prepareSavePanel:panel];

        [panel beginSheetModalForWindow:self.documentWindow completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                NSDictionary *attributes = [self saveAttributes];

                SBQueueItem *item = [SBQueueItem itemWithMP4:self.mp4 destinationURL:panel.URL attributes:attributes];
                [queue addItem:item];

                [self close];
            }
        }];
    }
}

#pragma mark - Metadata search

- (NSString *)sourceFilename {
    for (MP42Track *track in self.mp4.tracks) {
        if (track.sourceURL) {
            return track.sourceURL.lastPathComponent;
        }
    }
    return nil;
}

- (IBAction)searchMetadata:(id)sender
{
    NSString *filename = [self sourceFilename];

    if (!filename) {
        filename = self.fileURL.lastPathComponent;
    }

    self.sheetController = [[SBMetadataSearchController alloc] initWithDelegate:self searchString:filename];
    [self.documentWindow beginSheet:self.sheetController.window completionHandler:^(NSModalResponse returnCode) {
        self.sheetController = nil;
    }];
}

- (void)metadataImportDone:(SBMetadataResult *)metadataToBeImported
{
    if (metadataToBeImported) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        SBMetadataResultMap *map = metadataToBeImported.mediaKind == 9 ?
        [defaults SB_resultMapForKey:@"SBMetadataMovieResultMap"] : [defaults SB_resultMapForKey:@"SBMetadataTvShowResultMap"];
        BOOL keepEmptyKeys = [defaults boolForKey:@"SBMetadataKeepEmptyAnnotations"];
        MP42Metadata *mappedMetadata = [metadataToBeImported metadataUsingMap:map keepEmptyKeys:keepEmptyKeys];

        [self.mp4.metadata mergeMetadata:mappedMetadata];

        for (MP42Track *track in self.mp4.tracks)
            if ([track isKindOfClass:[MP42VideoTrack class]]) {
                MP42VideoTrack *videoTrack = (MP42VideoTrack *)track;
                int hdVideo = isHdVideo((uint64_t)videoTrack.trackWidth, (uint64_t)videoTrack.trackHeight);

                if (hdVideo) {
                    self.mp4.metadata[@"HD Video"] = @(hdVideo);
                }
            }
        [self updateChangeCount:NSChangeDone];
        [self.tracksTable reloadData];
        [self reloadPropertyView];
    }

}

#pragma mark - Chapters search

- (IBAction)searchChapters:(id)sender
{
    NSString *title = self.mp4.metadata[MP42MetadataKeyName];

    if (title.length == 0) {
        title = [self sourceFilename];
    }

    NSUInteger duration = self.mp4.duration;

    self.sheetController = [[SBChapterSearchController alloc] initWithDelegate:self searchTitle:title andDuration:duration];
    [self.documentWindow beginSheet:self.sheetController.window completionHandler:^(NSModalResponse returnCode) {
        self.sheetController = nil;
    }];
}

- (void)chapterImportDone:(NSArray<MP42TextSample *> *)chapterToBeImported
{
    if (chapterToBeImported) {

        MP42ChapterTrack *newChapter = [[MP42ChapterTrack alloc] init];
        for (MP42TextSample *chapter in chapterToBeImported) {
            [newChapter addChapter:chapter];
        }
        newChapter.duration = self.mp4.duration;
        [self.mp4 addTrack:newChapter];

        [self updateChangeCount:NSChangeDone];

        [self.tracksTable reloadData];
        [self reloadPropertyView];
        [self updateChangeCount:NSChangeDone];
    }
}

- (IBAction)showTrackOffsetSheet:(id)sender
{
    offset.stringValue = [NSString stringWithFormat:@"%lld",
                            (self.mp4).tracks[self.tracksTable.selectedRow].startOffset];

    [self.documentWindow beginSheet:offsetWindow completionHandler:NULL];
}

- (IBAction)setTrackOffset:(id)sender
{
    MP42Track *selectedTrack = (self.mp4).tracks[self.tracksTable.selectedRow];
    selectedTrack.startOffset = offset.integerValue;
    [self updateChangeCount:NSChangeDone];

    [self.documentWindow endSheet:offsetWindow];
}

- (IBAction)closeOffsetSheet:(id)sender
{
    [self.documentWindow endSheet:offsetWindow];
}

- (IBAction)deleteTrack:(id)sender
{
    if (self.tracksTable.selectedRow == -1  || self.tracksTable.editedRow != -1) {
        return;
    }

    [self.mp4 removeTrackAtIndex:self.tracksTable.selectedRow];

    [self.mp4 organizeAlternateGroups];

    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

// Import tracks from file

- (void)addChapterTrack:(NSURL *)fileURL
{
    [self.mp4 addTrack:[MP42ChapterTrack chapterTrackFromFile:fileURL]];

    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

- (void)updateChapters:(MP42ChapterTrack *)chapters fromCSVFile:(NSURL *)URL
{
    NSError *error;
    if ([chapters updateFromCSVFile:URL error:&error]) {
        [self reloadPropertyView];
        [self updateChangeCount:NSChangeDone];
    }
    else {
        [self presentError:error modalForWindow:self.documentWindow delegate:nil didPresentSelector:NULL contextInfo:nil];
    }
}

- (IBAction)selectFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;

    MP42ChapterTrack *chapters = self.mp4.chapters;

    NSMutableArray<NSString *> *supportedFileFormats = [[MP42FileImporter supportedFileFormats] mutableCopy];
    [supportedFileFormats addObject:@"txt"];

    if (chapters) {
        [supportedFileFormats addObject:@"csv"];
    }

    panel.allowedFileTypes = supportedFileFormats;

    [panel beginSheetModalForWindow:self.documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *fileExtension = panel.URLs.firstObject.pathExtension;

            if ([fileExtension caseInsensitiveCompare: @"txt"] == NSOrderedSame) {
                [self addChapterTrack:(panel.URLs)[0]];
            }
            else if ([fileExtension caseInsensitiveCompare: @"csv"] == NSOrderedSame) {
                [self updateChapters:chapters fromCSVFile:panel.URLs.firstObject];
            }
            else {
                [self showImportSheet:panel.URLs];
            }
        }
    }];
}

- (void)showImportSheet:(NSArray<NSURL *> *)fileURLs
{
    NSError *error = nil;

    self.sheetController = [[SBFileImport alloc] initWithURLs:fileURLs delegate:self error:&error];

    if (self.sheetController) {
		if (((SBFileImport *)self.sheetController).onlyContainsSubtitleTracks) {
			[(SBFileImport *)self.sheetController addTracks:self];
            [self.tracksTable reloadData];
            [self reloadPropertyView];
            self.sheetController = nil;
		}
        else {
            // show the dialog
            [self.documentWindow beginSheet:self.sheetController.window completionHandler:^(NSModalResponse returnCode) {
                self.sheetController = nil;
            }];
		}
    }
    else if (error) {
            [self presentError:error modalForWindow:self.documentWindow delegate:nil didPresentSelector:NULL contextInfo:nil];
    }
}

- (void)importDoneWithTracks:(NSArray<MP42Track *> *)tracksToBeImported andMetadata:(MP42Metadata *)metadata
{
    if (tracksToBeImported) {
        for (MP42Track *track in tracksToBeImported) {
            [self.mp4 addTrack:track];
        }

        [self updateChangeCount:NSChangeDone];

        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBOrganizeAlternateGroups"] boolValue]) {
            [self.mp4 organizeAlternateGroups];
        }
    }

    if (metadata) {
        [self.mp4.metadata mergeMetadata:metadata];
        [self updateChangeCount:NSChangeDone];
    }

    [self.tracksTable reloadData];
    [self reloadPropertyView];
}

- (void)addMetadata:(NSURL *)URL
{
    if ([URL.pathExtension isEqualToString:@"xml"] || [URL.pathExtension isEqualToString:@"nfo"]) {
        MP42Metadata *xmlMetadata = [[MP42Metadata alloc] initWithFileURL:URL];
        [self.mp4.metadata mergeMetadata:xmlMetadata];
    }
    else {
        MP42File *file = nil;
        if ((file = [[MP42File alloc] initWithURL:URL error:NULL])) {
            [self.mp4.metadata mergeMetadata:file.metadata];
        }
    }

    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)selectMetadataFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowedFileTypes = @[@"mp4", @"m4v", @"m4a", @"xml", @"nfo"];
    
    [panel beginSheetModalForWindow:self.documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self addMetadata:panel.URL];
        }
    }];
}

- (IBAction)export:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];

    NSString *filename = self.fileURL.URLByDeletingPathExtension.lastPathComponent;
    NSInteger row = self.tracksTable.selectedRow;

    if (row != -1 && [[self.mp4 trackAtIndex:row] isKindOfClass:[MP42SubtitleTrack class]]) {
        panel.allowedFileTypes = @[@"srt"];
        filename = [filename stringByAppendingFormat:@".%@", [self.mp4 trackAtIndex:row].language];
    }
	else if (row != -1 ) {
        filename = [filename stringByAppendingString:@" - Chapters"];
        panel.allowedFileTypes = @[@"txt"];
    }

    panel.canSelectHiddenExtension = YES;
    panel.nameFieldStringValue = filename;

    [panel beginSheetModalForWindow:self.documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {

            NSError *error;
            id track = [self.mp4 trackAtIndex:row];

            if (![track exportToURL:panel.URL error:&error]) {

                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle: NSLocalizedString(@"OK", "Export alert panel -> button")];
                [alert setMessageText: NSLocalizedString(@"File Could Not Be Saved", "Export alert panel -> title")];
                alert.informativeText = [NSString stringWithFormat:
                                            NSLocalizedString(@"There was a problem creating the file \"%@\".",
                                                              "Export alert panel -> message"), panel.URL.lastPathComponent];
                alert.alertStyle = NSWarningAlertStyle;
                
                [alert runModal];
            }

        }
    }];
}

- (IBAction)addChaptersEvery:(id)sender
{
    MP42ChapterTrack *chapterTrack = self.mp4.chapters;
    NSInteger minutes = [sender tag] * 60 * 1000;

    if (!chapterTrack) {
        chapterTrack = [[MP42ChapterTrack alloc] init];
        chapterTrack.duration = self.mp4.duration;
        [self.mp4 addTrack:chapterTrack];
    }

    if (minutes) {
        for (NSInteger i = 0, y = 1; i < self.mp4.duration; i += minutes, y++) {
            [chapterTrack addChapter:[NSString stringWithFormat:@"Chapter %ld", (long)y]
                            duration:i];
        }
    }
    else {
        [chapterTrack addChapter:@"Chapter 1"
                        duration:self.mp4.duration];
    }

    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)iTunesFriendlyTrackGroups:(id)sender
{
    [self.mp4 organizeAlternateGroups];
    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)fixAudioFallbacks:(id)sender {
    [self.mp4 setAutoFallback];
    [self.tracksTable reloadData];
    [self reloadPropertyView];
    [self updateChangeCount:NSChangeDone];
}

#pragma mark - Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

    if ([pboard.types containsObject:NSFilenamesPboardType]) {
         if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
         }
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];

    if ( [pboard.types containsObject:NSURLPboardType] ) {
        NSArray *items = [pboard readObjectsForClasses:@[[NSURL class]] options:nil];
        NSMutableArray<NSURL *> *supportedItems = [[NSMutableArray alloc] init];

        for (NSURL *url in items) {
            NSString *pathExtension = url.pathExtension;
            if ([pathExtension caseInsensitiveCompare: @"txt"] == NSOrderedSame) {
                [self addChapterTrack:url];
            }
            else if ([pathExtension caseInsensitiveCompare: @"xml"] == NSOrderedSame ||
                     [pathExtension caseInsensitiveCompare: @"nfo"] == NSOrderedSame) {
                [self addMetadata:url];
            }
            else if ([MP42FileImporter canInitWithFileType:pathExtension]) {
                [supportedItems addObject:url];
            }
        }
        
        if (supportedItems.count) {
            [self showImportSheet:supportedItems];
        }

        return YES;
    }

    return NO;
}

@end
