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

#import "SBEmptyViewController.h"
#import "SBMovieViewController.h"
#import "SBVideoViewController.h"
#import "SBSoundViewController.h"
#import "SBChapterViewController.h"

#import "SBMetadataSearchController.h"
#import "SBArtworkSelector.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42Languages.h>
#import <MP42Foundation/MP42Utilities.h>

#define SublerTableViewDataType @"SublerTableViewDataType"

@interface SBDocument () <MP42FileDelegate, SBFileImportDelegate>

@end

@implementation SBDocument

- (NSString *)windowNibName
{
    return @"SBDocument";
}

- (void)awakeFromNib
{
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"rememberWindowSize"] integerValue]) {
        [documentWindow setFrameAutosaveName:@"documentSave"];
        [documentWindow setFrameUsingName:@"documentSave"];
        [splitView setAutosaveName:@"splitViewSave"];
    }

    [optBar setUsesThreadedAnimation:NO];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    languages = [[[MP42Languages defaultManager] languages] copy];

    SBMovieViewController *controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
    [controller setFile:mp4File];
    if (controller !=nil){
        propertyView = controller;
        [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
        [[propertyView view] setFrame:[targetView bounds]];
        [targetView addSubview: [propertyView view]];
    }

    [documentWindow recalculateKeyViewLoop];

    [fileTracksTable registerForDraggedTypes:[NSArray arrayWithObjects:SublerTableViewDataType, nil]];
    [documentWindow registerForDraggedTypes:[NSArray arrayWithObjects:
                                   NSColorPboardType, NSFilenamesPboardType, nil]];

    _optimize = NO;

    [sendToQueue setImage:[NSImage imageNamed:NSImageNameShareTemplate]];
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
    if (self = [super initWithType:typeName error:outError])
        mp4File = [[MP42File alloc] initWithDelegate:self];

    return self;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)type
{
    return NO;
}

- (BOOL)isEntireFileLoaded
{
    return NO;
}

#pragma mark Read methods

- (void)reloadFile:(NSURL *)absoluteURL
{
    if (absoluteURL) {
        MP42File *newFile = [[MP42File alloc] initWithExistingFile:absoluteURL andDelegate:self];
        if (newFile) {
            [mp4File autorelease];
            mp4File = newFile;
            [fileTracksTable reloadData];
            [self tableViewSelectionDidChange:nil];
        }
        else
            [self close];
    }
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    mp4File = [[MP42File alloc] initWithExistingFile:absoluteURL andDelegate:self];

    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
        
        return NO;
	}

    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    [mp4File release];
    mp4File = [[MP42File alloc] initWithExistingFile:absoluteURL andDelegate:self];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeCleared];

    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];   
        
        return NO;
	}
    return YES;
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

#pragma mark Save methods

- (BOOL)saveDidComplete:(NSError **)outError URL:(NSURL *)absoluteURL
{
    [NSApp endSheet: savingWindow];
    [savingWindow orderOut:self];
    [optBar stopAnimation:self];

    if (*outError) {
        [self presentError:*outError
            modalForWindow:documentWindow
                  delegate:nil
        didPresentSelector:NULL
               contextInfo:NULL];

        [*outError release];
    }

    [self reloadFile:absoluteURL];

    return YES;
}

- (void)endSave:(id)sender {
    /* Post an event so our event loop wakes up */
    [NSApp postEvent:[NSEvent otherEventWithType:NSApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL subtype:0 data1:0 data2:0] atStart:NO];
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    __block BOOL success = NO;
    __block int32_t done = 0;
    __block NSError *inError = NULL;

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue])
        [attributes setObject:@YES forKey:MP42GenerateChaptersPreviewTrack];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBOrganizeAlternateGroups"] boolValue])
        [attributes setObject:@YES forKey:MP42OrganizeAlternateGroups];


    [optBar setIndeterminate:YES];
    [optBar startAnimation:self];
    [saveOperationName setStringValue:@"Saving…"];
    [NSApp beginSheet:savingWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];

    IOPMAssertionID assertionID;
    // Enable sleep assertion
    CFStringRef reasonForActivity= CFSTR("Subler Save Operation");
    IOReturn io_success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &assertionID);

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        switch (saveOperation) {
            case NSSaveOperation:
                // movie file already exists, so we'll just update
                // the movie resource
                success = [mp4File updateMP4FileWithAttributes:attributes error:&inError];
                break;
            case NSSaveAsOperation:
                if ([_64bit_data state]) [attributes setObject:@YES forKey:MP4264BitData];
                if ([_64bit_time state]) [attributes setObject:@YES forKey:MP4264BitTime];
                success = [mp4File writeToUrl:absoluteURL withAttributes:attributes error:&inError];
                break;
            case NSSaveToOperation:
                // not implemented
                break;
        }
        if (_optimize) {
            [saveOperationName setStringValue:@"Optimizing…"];
            [mp4File optimize];
            _optimize = NO;
        }

        done = 1;
        [inError retain];
    });

    while (!done) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        @try {
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
            if (event) [NSApp sendEvent:event];
        }
        @catch (NSException *localException) {
            NSLog(@"Exception thrown during save: %@", localException);
        }
        @finally {
            [pool drain];
        }
    }

    if (io_success == kIOReturnSuccess)
        IOPMAssertionRelease(assertionID);

    *outError = [inError autorelease];

    [attributes release];
    [self saveDidComplete:outError URL:absoluteURL];
    return success;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    _currentSavePanel = savePanel;
    [savePanel setExtensionHidden:NO];
    [savePanel setAccessoryView:saveView];

    NSArray *formats = [self writableTypesForSaveOperation:NSSaveAsOperation];
    [fileFormat removeAllItems];
    for (id format in formats)
        [fileFormat addItemWithTitle:format];

    [fileFormat selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] valueForKey:@"defaultSaveFormat"] integerValue]];
	if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"])
		[_currentSavePanel setAllowedFileTypes:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]]];

    NSString *filename = nil;
    for (NSUInteger i = 0; i < [mp4File tracksCount]; i++) {
        MP42Track *track = [mp4File trackAtIndex:i];
        if ([track sourceURL]) {
            filename = [[[track sourceURL] lastPathComponent] stringByDeletingPathExtension];
            break;
        }
    }

    if (filename)
        [savePanel performSelector:@selector(setNameFieldStringValue:) withObject:filename];

    if (mp4File.dataSize > 4200000000)
        [_64bit_data setState:NSOnState];

    return YES;
}

- (IBAction)setSaveFormat:(id)sender
{
    NSString *requiredFileType = nil;
    NSInteger index = [sender indexOfSelectedItem];
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
        default:
            requiredFileType = MP42FileTypeM4V;
            break;
    }

    [_currentSavePanel setAllowedFileTypes:[NSArray arrayWithObject:requiredFileType]];
    [[NSUserDefaults standardUserDefaults] setObject:requiredFileType forKey:@"SBSaveFormat"];
}

- (IBAction)cancelSaveOperation:(id)sender
{
    [cancelSave setEnabled:NO];
    [mp4File cancel];
}

- (IBAction)saveAndOptimize:(id)sender
{
    _optimize = YES;
    [self saveDocument:sender];
}

- (IBAction)sendToExternalApp:(id)sender
{
    /* send to itunes after save */
    NSAppleScript *myScript = [[NSAppleScript alloc] initWithSource:
                               [NSString stringWithFormat:@"%@%@%@", @"tell application \"iTunes\" to open (POSIX file \"", [[self fileURL] path], @"\")"]];

    [myScript executeAndReturnError: nil];
    [myScript release];
}

#pragma mark Interface validation

- (void)progressStatus:(CGFloat)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [optBar setIndeterminate:NO];
        [optBar setDoubleValue:progress];
    });
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];

    if (action == @selector(saveDocument:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(saveDocumentAs:))
        return YES;
    
    if (action == @selector(revertDocumentToSaved:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(saveAndOptimize:))
        if (![self isDocumentEdited] && [mp4File hasFileRepresentation])
            return YES;

    if (action == @selector(selectMetadataFile:))
        return YES;

    if (action == @selector(selectFile:))
        return YES;

    if (action == @selector(deleteTrack:))
        return YES;

    if (action == @selector(searchMetadata:))
        return YES;

    if (action == @selector(sendToQueue:))
        return YES;

    if (action == @selector(sendToExternalApp:))
        return YES;

    if (action == @selector(showTrackOffsetSheet:) && [fileTracksTable selectedRow] != -1)
        return YES;

    if (action == @selector(addChaptersEvery:))
        return YES;
    
    if (action == @selector(iTunesFriendlyTrackGroups:))
        return YES;

	if (action == @selector(export:) && [fileTracksTable selectedRow] != -1)
		if ([[mp4File trackAtIndex:[fileTracksTable selectedRow]] respondsToSelector:@selector(exportToURL:error:)] &&
            [[mp4File trackAtIndex:[fileTracksTable selectedRow]] muxed])
			return YES;

    return NO;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    if (toolbarItem == addTracks)
            return YES;

    else if (toolbarItem == deleteTrack)
        if ([fileTracksTable selectedRow] != -1 && [NSApp isActive])
                return YES;

    if (toolbarItem == searchMetadata)
        return YES;

    if (toolbarItem == sendToQueue)
        return YES;

    return NO;
}

#pragma mark table datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)t
{
    if (!mp4File)
        return 0;

    return [mp4File tracksCount];
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [mp4File trackAtIndex:rowIndex];

    if (!track)
        return nil;

    if ([tableColumn.identifier isEqualToString:@"trackId"]) {
        if ([track Id] == 0)
            return @"na";
        else
            return [NSString stringWithFormat:@"%d", [track Id]];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return track.name;

    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return track.formatSummary;

    if ([tableColumn.identifier isEqualToString:@"trackEnabled"])
        return @(track.enabled);

    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return track.timeString;

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return track.language;

    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    MP42Track *track = [mp4File trackAtIndex:rowIndex];

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
            track.enabled = [anObject integerValue];
            [self updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([propertyView view] != nil)
		[[propertyView view] removeFromSuperview];	// remove the current view

    [[self undoManager] removeAllActionsWithTarget:propertyView];  // remove the undo items from the dealloced view

	if (propertyView != nil)
		[propertyView release];		// remove the current view controller

    NSInteger row = [fileTracksTable selectedRow];
    if (row == -1)
    {
        SBMovieViewController *controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [controller setFile:mp4File];
        if (controller !=nil)
            propertyView = controller;
    }
    else if (row != -1 && [[mp4File trackAtIndex:row] isMemberOfClass:[MP42ChapterTrack class]])
    {
        SBChapterViewController *controller = [[SBChapterViewController alloc] initWithNibName:@"ChapterView" bundle:nil];
        [controller setTrack:(MP42ChapterTrack *)[mp4File trackAtIndex:row]];
        if (controller !=nil)
            propertyView = controller;
    }
    else if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42VideoTrack class]])
    {
        SBVideoViewController *controller = [[SBVideoViewController alloc] initWithNibName:@"VideoView" bundle:nil];
        [controller setTrack:(MP42VideoTrack *)[mp4File trackAtIndex:row]];
        [controller setFile:mp4File];
        if (controller !=nil)
            propertyView = controller;
    }
    else if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42AudioTrack class]])
    {
        SBSoundViewController *controller = [[SBSoundViewController alloc] initWithNibName:@"SoundView" bundle:nil];
        [controller setTrack:(MP42AudioTrack *)[mp4File trackAtIndex:row]];
        [controller setFile:mp4File];
        if (controller !=nil)
            propertyView = controller;
    }
    else
    {
        SBEmptyViewController *controller = [[SBEmptyViewController alloc] initWithNibName:@"EmptyView" bundle:nil];
        if (controller !=nil)
                propertyView = controller;
    }

    // embed the current view to our host view
	[targetView addSubview: [propertyView view]];
    [documentWindow recalculateKeyViewLoop];

	// make sure we automatically resize the controller's view to the current window size
	[[propertyView view] setFrame: [targetView bounds]];
    [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    // Copy the row numbers to the pasteboard.
    if ([[mp4File trackAtIndex:[rowIndexes firstIndex]] muxed])
        return NO;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:SublerTableViewDataType] owner:self];
    [pboard setData:data forType:SublerTableViewDataType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    if (op == NSTableViewDropAbove && row < [mp4File tracksCount]) {
        if(![[mp4File trackAtIndex:row] muxed])
            return NSDragOperationEvery;
    }
    else if (op == NSTableViewDropAbove && row == [mp4File tracksCount])
        return NSDragOperationEvery;

    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:SublerTableViewDataType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSInteger dragRow = [rowIndexes firstIndex];
    
    [mp4File moveTrackAtIndex:dragRow toIndex:row];
    [fileTracksTable reloadData];
    return YES;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
    return YES;
}

/* NSComboBoxCell dataSource */

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell
{
    return [languages count];
}

- (id)comboBoxCell:(NSComboBoxCell *)comboBoxCell objectValueForItemAtIndex:(NSInteger)index {
    return [languages objectAtIndex:index];
}

- (NSUInteger)comboBoxCell:(NSComboBoxCell *)comboBoxCell indexOfItemWithStringValue:(NSString *)string {
    return [languages indexOfObject: string];
}

#pragma mark Various things

- (IBAction)sendToQueue:(id)sender
{
    SBQueueController *queue =  [SBQueueController sharedManager];
    if ([mp4File hasFileRepresentation]) {
        SBQueueItem *item = [SBQueueItem itemWithMP4:mp4File];
        [queue addItem:item];
        [self close];
    }
    else {
        NSSavePanel * panel = [NSSavePanel savePanel];
        [self prepareSavePanel:panel];

        [panel setPrompt:@"Send To Queue"];

        [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
                if ([_64bit_data state]) [attributes setObject:@YES forKey:MP4264BitData];
                if ([_64bit_time state]) [attributes setObject:@YES forKey:MP4264BitTime];

                SBQueueItem *item = [SBQueueItem itemWithMP4:mp4File url:[panel URL] attributes:attributes];
                [queue addItem:item];

                [attributes release];
                [self close];
            }
        }];
    }
}

- (IBAction)searchMetadata:(id)sender
{
    importWindow = [[SBMetadataSearchController alloc] initWithDelegate:self];
    
    [NSApp beginSheet:[importWindow window] modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction)showTrackOffsetSheet:(id)sender
{
    [offset setStringValue:[NSString stringWithFormat:@"%lld",
                            [[[mp4File tracks] objectAtIndex:[fileTracksTable selectedRow]] startOffset]]];

    [NSApp beginSheet:offsetWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction)setTrackOffset:(id)sender
{
    MP42Track *selectedTrack = [[mp4File tracks] objectAtIndex:[fileTracksTable selectedRow]];
    [selectedTrack setStartOffset:[offset integerValue]];

    [self updateChangeCount:NSChangeDone];

    [NSApp endSheet: offsetWindow];
    [offsetWindow orderOut:self];
}

- (IBAction)closeOffsetSheet:(id)sender
{
    [NSApp endSheet: offsetWindow];
    [offsetWindow orderOut:self];
}

- (IBAction)deleteTrack:(id)sender
{
    if ([fileTracksTable selectedRow] == -1  || [fileTracksTable editedRow] != -1)
        return;

    [mp4File removeTrackAtIndex:[fileTracksTable selectedRow]];

    [mp4File organizeAlternateGroups];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

// Import tracks from file

- (void)addChapterTrack:(NSURL *)fileURL
{
    [mp4File addTrack:[MP42ChapterTrack chapterTrackFromFile:fileURL]];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)selectFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    [panel setAllowedFileTypes:supportedFileFormat()];

    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *fileExtension = [[panel.URLs objectAtIndex: 0] pathExtension];

            if ([fileExtension caseInsensitiveCompare: @"txt"] == NSOrderedSame)
                [self addChapterTrack:[panel.URLs objectAtIndex: 0]];
            else
                [self performSelectorOnMainThread:@selector(showImportSheet:)
                                       withObject:panel.URLs waitUntilDone: NO];
        }
    }];
}

- (void)showImportSheet:(NSArray *)fileURLs
{
    NSError *error = nil;

    importWindow = [[SBFileImport alloc] initWithDelegate:self andFiles:fileURLs error:&error];

    if (importWindow)
        [NSApp beginSheet:[importWindow window] modalForWindow:documentWindow
            modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:importWindow];
    else if (error)
            [self presentError:error modalForWindow:documentWindow delegate:nil didPresentSelector:NULL contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;{
    [importWindow autorelease], importWindow = nil;

    // IKImageBrowserView is a bit problematic, do the refresh at the end of the run loop
    dispatch_async(dispatch_get_main_queue(), ^{
        [fileTracksTable reloadData];
        [self tableViewSelectionDidChange:nil];
    });
}

- (void)importDoneWithTracks:(NSArray *)tracksToBeImported andMetadata:(MP42Metadata *)metadata
{
    if (tracksToBeImported) {
        for (id track in tracksToBeImported)
            [mp4File addTrack:track];

        [self updateChangeCount:NSChangeDone];
        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBOrganizeAlternateGroups"] boolValue])
            [mp4File organizeAlternateGroups];
    }

    if (metadata) {
        [mp4File.metadata mergeMetadata:metadata];
        [self updateChangeCount:NSChangeDone];
    }
}

- (void)metadataImportDone:(MP42Metadata *)metadataToBeImported
{
    if (metadataToBeImported) {
        [mp4File.metadata mergeMetadata:metadataToBeImported];

        for (MP42Track *track in mp4File.tracks)
            if ([track isKindOfClass:[MP42VideoTrack class]]) {
                int hdVideo = isHdVideo([((MP42VideoTrack *) track) trackWidth], [((MP42VideoTrack *) track) trackHeight]);

                if (hdVideo)
                    [mp4File.metadata setTag:@(hdVideo) forKey:@"HD Video"];

                [self updateChangeCount:NSChangeDone];
            }
    }

    [NSApp endSheet:[importWindow window]];
    [[importWindow window] orderOut:self];
    [importWindow autorelease], importWindow = nil;

    if (metadataToBeImported) {
        [self tableViewSelectionDidChange:nil];
        [self updateChangeCount:NSChangeDone];
    }
}

- (void)addMetadata:(NSURL *)URL
{
    if ([[URL pathExtension] isEqualToString:@"xml"] || [[URL pathExtension] isEqualToString:@"nfo"]) {
        MP42Metadata *xmlMetadata = [[MP42Metadata alloc] initWithFileURL:URL];
        [mp4File.metadata mergeMetadata:xmlMetadata];
        [xmlMetadata release];
    }
    else {
        MP42File *file = nil;
        if ((file = [[MP42File alloc] initWithExistingFile:URL andDelegate:self])) {
            [mp4File.metadata mergeMetadata:file.metadata];
            [file release];
        }
    }

    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)selectMetadataFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", @"xml", @"nfo", nil]];
    
    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self addMetadata:[panel URL]];
        }
    }];
}

- (IBAction)export:(id)sender
{
    NSInteger row = [fileTracksTable selectedRow];
    NSSavePanel * panel = [NSSavePanel savePanel];
    NSString *filename = [[[[self fileURL] path] stringByDeletingPathExtension] lastPathComponent];

    if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42SubtitleTrack class]]) {
        [panel setAllowedFileTypes:[NSArray arrayWithObject: @"srt"]];
        filename = [filename stringByAppendingFormat:@".%@", [[mp4File trackAtIndex:row] language]];
    }
	else if (row != -1 ) {
        filename = [filename stringByAppendingString:@" - Chapters"];
		[panel setAllowedFileTypes:[NSArray arrayWithObject: @"txt"]];
    }

    [panel setCanSelectHiddenExtension: YES];
    [panel setNameFieldStringValue:filename];
    
    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            id track = [mp4File trackAtIndex:[fileTracksTable selectedRow]];
            
            if (![track exportToURL: [panel URL] error: nil]) {
                NSAlert * alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle: NSLocalizedString(@"OK", "Export alert panel -> button")];
                [alert setMessageText: NSLocalizedString(@"File Could Not Be Saved", "Export alert panel -> title")];
                [alert setInformativeText: [NSString stringWithFormat:
                                            NSLocalizedString(@"There was a problem creating the file \"%@\".",
                                                              "Export alert panel -> message"), [[[panel URL] path] lastPathComponent]]];
                [alert setAlertStyle: NSWarningAlertStyle];
                
                [alert runModal];
                [alert release];
            }

        }
    }];
}

- (IBAction)addChaptersEvery:(id)sender
{
    MP42ChapterTrack *chapterTrack = [mp4File chapters];
    NSInteger minutes = [sender tag] * 60 * 1000;
    NSInteger i, y = 1;

    if (!chapterTrack) {
        chapterTrack = [[MP42ChapterTrack alloc] init];
        [chapterTrack setDuration:mp4File.duration];
        [mp4File addTrack:chapterTrack];
        [chapterTrack release];
    }

    if (minutes)
        for (i = 0, y = 1; i < mp4File.duration; i += minutes, y++) {
            [chapterTrack addChapter:[NSString stringWithFormat:@"Chapter %ld", (long)y]
                            duration:i];
        }
    else
        [chapterTrack addChapter:@"Chapter 1"
                        duration:mp4File.duration];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction)iTunesFriendlyTrackGroups:(id)sender
{
    [mp4File organizeAlternateGroups];
    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

// Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
         if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
         }
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        NSArray *items = [pboard readObjectsForClasses:
                           [NSArray arrayWithObject: [NSURL class]] options: nil];
        NSMutableArray *supItems = [[[NSMutableArray alloc] init] autorelease];

        for (NSURL *file in items) {
            if ([[file pathExtension] caseInsensitiveCompare: @"txt"] == NSOrderedSame)
                [self addChapterTrack:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"xml"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"nfo"] == NSOrderedSame)
                [self addMetadata:file];
            else if (isFileFormatSupported([file pathExtension])) {
                [supItems addObject:file];
            }
        }
        
        if ([supItems count])
            [self showImportSheet:supItems];

        return YES;
    }
    return NO;
}

- (MP42File *)mp4File {
    return mp4File;
}

- (void)setMp4File:(MP42File *)mp4 {
    [mp4File autorelease];
    mp4File = [mp4 retain];
    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
}

- (void)dealloc
{
    [propertyView release];
    [languages release];

    [mp4File release];
    [super dealloc];
}

@end
