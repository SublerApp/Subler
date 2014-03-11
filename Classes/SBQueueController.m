//
//  SBQueueController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBQueueController.h"
#import "SBQueueItem.h"
#import "SBDocument.h"
#import "SBTableView.h"
#import "MetadataImporter.h"

#import <MP42Foundation/MP42Utilities.h>


#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"
#define kOptionsPanelHeight 88

@interface SBQueueController () <NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate>

@property (readonly) SBQueue *queue;

- (void)updateUI;
- (void)updateDockTile;
- (NSURL *)queueURL;
- (NSMenuItem *)prepareDestPopupItem:(NSURL *)dest;
- (void)prepareDestPopup;

- (void)addItems:(NSArray *)items atIndexes:(NSIndexSet *)indexes;
- (void)removeItems:(NSArray *)items;

@end


@implementation SBQueueController

@synthesize queue = _queue;

+ (SBQueueController *)sharedManager
{
    static dispatch_once_t pred;
    static SBQueueController *sharedManager = nil;

    dispatch_once(&pred, ^{ sharedManager = [[self alloc] init]; });
    return sharedManager;
}

- (id)init
{
    if (self = [super initWithWindowNibName:@"Queue"]) {
        _queue = [[SBQueue alloc] initWithURL:[self queueURL]];
        [self removeCompletedItems:self];
        [self updateDockTile];
    }

    return self;
}

- (void)awakeFromNib
{
    [_progressIndicator setHidden:YES];
    [_countLabel setStringValue:@"Empty"];

    NSRect frame = [[self window] frame];
    frame.size.height += kOptionsPanelHeight;
    frame.origin.y -= kOptionsPanelHeight;

    [[self window] setFrame:frame display:NO animate:NO];

    frame = [[self window] frame];
    frame.size.height -= kOptionsPanelHeight;
    frame.origin.y += kOptionsPanelHeight;

    [tableScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
    [_optionsBox setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

    [[self window] setFrame:frame display:YES animate:NO];

    [tableScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_optionsBox setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    docImg = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('MOOV')] retain];
    [docImg setSize:NSMakeSize(16, 16)];

    [self prepareDestPopup];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [tableView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, SublerBatchTableViewDataType, nil]];

    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueWorkingNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
        [_countLabel setStringValue:@"Working"];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueCompletedNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
        [_progressIndicator setHidden:YES];
        [_progressIndicator stopAnimation:self];
        [_progressIndicator setDoubleValue:0];
        [_start setTitle:@"Start"];
        [_countLabel setStringValue:@"Done"];

        [self updateDockTile];
        [self updateUI];
    }];

    [self updateUI];
}

- (NSURL *)queueURL
{
    NSURL *appSupportURL = nil;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count]) {
        appSupportURL = [NSURL fileURLWithPath:[[[allPaths lastObject] stringByAppendingPathComponent:@"Subler"] stringByAppendingPathComponent:@"queue.sbqueue"] isDirectory:YES];
        return appSupportURL;
    } else {
        return nil;
    }
}

- (SBQueueStatus)status {
    return self.queue.status;
}

- (BOOL)saveQueueToDisk {
    return [self.queue saveQueueToDisk];
}

- (NSMenuItem *)prepareDestPopupItem:(NSURL*) dest
{
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:[dest lastPathComponent] action:@selector(destination:) keyEquivalent:@""];
    [folderItem setTag:10];

    NSImage *menuItemIcon = [[NSWorkspace sharedWorkspace] iconForFile:[dest path]];
    [menuItemIcon setSize:NSMakeSize(16, 16)];

    [folderItem setImage:menuItemIcon];

    return [folderItem autorelease];
}

- (void)prepareDestPopup
{
    NSMenuItem *folderItem = nil;

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"]) {
        destination = [[NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"]] retain];

#ifdef SB_SANDBOX
        if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestinationBookmark"]) {
            BOOL bookmarkDataIsStale;
            NSError *error;
            NSData *bookmarkData = [[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestinationBookmark"];

            [destination release];
            destination = [[NSURL
                          URLByResolvingBookmarkData:bookmarkData
                                             options:NSURLBookmarkResolutionWithSecurityScope
                                             relativeToURL:nil
                                             bookmarkDataIsStale:&bookmarkDataIsStale
                                             error:&error] retain];
        }
#endif
        if (![[NSFileManager defaultManager] fileExistsAtPath:[destination path] isDirectory:nil])
            destination = nil;
    }

    if (!destination) {
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if ([allPaths count])
            destination = [[NSURL fileURLWithPath:[allPaths lastObject]] retain];;
    }

    folderItem = [self prepareDestPopupItem:destination];

    [[destButton menu] insertItem:[NSMenuItem separatorItem] atIndex:0];
    [[destButton menu] insertItem:folderItem atIndex:0];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestinationSelected"] boolValue]) {
        [destButton selectItem:folderItem];
        customDestination = YES;
    }
}

- (IBAction)destination:(id)sender
{
    if ([sender tag] == 10) {
        customDestination = YES;
        [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
    } else {
        customDestination = NO;
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"SBQueueDestinationSelected"];
    }
}

- (void)updateDockTile
{
    NSUInteger count = [self.queue readyCount];

    if (count)
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%d", count]];
    else
        [[NSApp dockTile] setBadgeLabel:nil];
}

- (void)updateUI
{
    [tableView reloadData];
    if (self.queue.status != SBQueueStatusWorking) {
        [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
        [self updateDockTile];
    }
}

- (void)start:(id)sender
{
    if (self.queue.status == SBQueueStatusWorking)
        return;

    [_start setTitle:@"Stop"];
    [_countLabel setStringValue:@"Working."];
    [_progressIndicator setHidden:NO];
    [_progressIndicator startAnimation:self];

    [self.queue start];
}

- (void)progressStatus: (CGFloat)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_progressIndicator setIndeterminate:NO];
        [_progressIndicator setDoubleValue:progress];
    });
}

- (void)stop:(id)sender
{
    [self.queue stop];
}

- (IBAction)toggleStartStop:(id)sender
{
    if (self.queue.status == SBQueueStatusWorking) {
        [self stop:sender];
    } else {
        [self start:sender];
    }
}

- (IBAction)toggleOptions:(id)sender
{
    NSInteger value = 0;
    if (_optionsStatus) {
        value = -kOptionsPanelHeight;
        _optionsStatus = NO;
    }
    else {
        value = kOptionsPanelHeight;
        _optionsStatus = YES;
    }

    NSRect frame = [[self window] frame];
    frame.size.height += value;
    frame.origin.y -= value;

    [tableScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
    [_optionsBox setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

    [[self window] setFrame:frame display:YES animate:YES];

    [tableScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_optionsBox setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
}

#pragma mark Open methods

- (IBAction)open:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    [panel setAllowedFileTypes:supportedFileFormat()];

    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMutableArray *items = [[NSMutableArray alloc] init];

            for (NSURL *url in [panel URLs])
                [items addObject:[SBQueueItem itemWithURL:url]];

            [self addItems:items atIndexes:nil];
            [items release];

            [self updateUI];

            if ([_autoStartOption state])
                [self start:self];
        }
    }];
}

- (IBAction)chooseDestination:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;

    [panel setPrompt:@"Select"];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            destination = [[panel URL] retain];

            NSMenuItem *folderItem = [self prepareDestPopupItem:[panel URL]];

            [[destButton menu] removeItemAtIndex:0];
            [[destButton menu] insertItem:folderItem atIndex:0];

            [destButton selectItem:folderItem];
            customDestination = YES;

#ifdef SB_SANDBOX
            NSData *bookmark = nil;
            NSError *error = nil;
            bookmark = [[panel URL] bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil // Make it app-scoped
                                              error:&error];
            if (error) {
                NSLog(@"Error creating bookmark for URL (%@): %@", [panel URL], error);
                [NSApp presentError:error];
            }

            [[NSUserDefaults standardUserDefaults] setValue:bookmark forKey:@"SBQueueDestinationBookmark"];
#endif
            [[NSUserDefaults standardUserDefaults] setValue:[[panel URL] path] forKey:@"SBQueueDestination"];
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        }
        else
            [destButton selectItemAtIndex:2];
    }];
}

#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self.queue count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"nameColumn"])
        return [[[self.queue itemAtIndex:rowIndex] URL] lastPathComponent];

    if ([aTableColumn.identifier isEqualToString:@"statusColumn"]) {
        SBQueueItemStatus batchStatus = [[self.queue itemAtIndex:rowIndex] status];
        if (batchStatus == SBQueueItemStatusCompleted)
            return [NSImage imageNamed:@"EncodeComplete"];
        else if (batchStatus == SBQueueItemStatusWorking)
            return [NSImage imageNamed:@"EncodeWorking"];
        else if (batchStatus == SBQueueItemStatusFailed)
            return [NSImage imageNamed:@"EncodeCanceled"];
        else
            return docImg;
    }

    return nil;
}

- (void)_deleteSelectionFromTableView:(NSTableView *)aTableView
{
    NSMutableIndexSet *rowIndexes = [[aTableView selectedRowIndexes] mutableCopy];
    NSInteger clickedRow = [aTableView clickedRow];
    NSUInteger selectedIndex = -1;
    if ([rowIndexes count])
         selectedIndex = [rowIndexes firstIndex];

    if (clickedRow != -1 && ![rowIndexes containsIndex:clickedRow]) {
        [rowIndexes removeAllIndexes];
        [rowIndexes addIndex:clickedRow];
    }

    NSArray *array = [self.queue itemsAtIndexes:rowIndexes];

    // A item with a status of SBQueueItemStatusWorking can not be removed
    for (SBQueueItem *item in array)
        if ([item status] == SBQueueItemStatusWorking)
            [rowIndexes removeIndex:[self.queue indexOfItem:item]];

    if ([rowIndexes count]) {
        if ([NSTableView instancesRespondToSelector:@selector(beginUpdates)]) {
            #if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
            [aTableView beginUpdates];
            [aTableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationEffectFade];
            [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
            [self removeItems:array];
            [aTableView endUpdates];
            #endif
        }
        else {
            [self removeItems:array];
            [aTableView reloadData];
            [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        }

        if (self.queue.status != SBQueueStatusWorking) {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
            [self updateDockTile];
        }
    }
    [rowIndexes release];
}

- (IBAction)edit:(id)sender
{
    /*SBQueueItem *item = [[self.queue itemAtIndex:[tableView clickedRow]] retain];
    
    [self removeItems:[NSArray arrayWithObject:item]];
    [self updateUI];

    MP42File *mp4;
    if (!item.mp4File)
        mp4 = [self prepareQueueItem:item.URL error:NULL];
    else
        mp4 = item.mp4File;

    SBDocument *doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    [doc setMp4File:mp4];
    [item release];*/
}

- (IBAction)showInFinder:(id)sender
{
    SBQueueItem *item = [self.queue itemAtIndex:[tableView clickedRow]];
    [[NSWorkspace sharedWorkspace] selectFile:[item.destURL path] inFileViewerRootedAtPath:nil];
}

- (IBAction)removeSelectedItems:(id)sender
{
    [self _deleteSelectionFromTableView:tableView];
}

- (IBAction)removeCompletedItems:(id)sender
{
    NSIndexSet *indexes = [self.queue removeCompletedItems];

    if ([indexes count]) {
        if ([NSTableView instancesRespondToSelector:@selector(beginUpdates)]) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
            [tableView beginUpdates];
            [tableView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationEffectFade];
            [tableView endUpdates];
#endif
        } else {
            [tableView reloadData];
        }

        if (self.queue.status != SBQueueStatusWorking) {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
            [self updateDockTile];
        }
    }
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];

    if (action == @selector(removeSelectedItems:))
        if ([tableView selectedRow] != -1 || [tableView clickedRow] != -1)
            return YES;

    if (action == @selector(showInFinder:)) {
        if ([tableView clickedRow] != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:[tableView clickedRow]];
            if ([item status] == SBQueueItemStatusCompleted)
                return YES;
        }
    }

    if (action == @selector(edit:))
        return YES;
    
    if (action == @selector(removeCompletedItems:))
        return YES;

    if (action == @selector(chooseDestination:))
        return YES;

    if (action == @selector(destination:))
        return YES;

    return NO;
}

#pragma mark Drag & Drop

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    // Copy the row numbers to the pasteboard.    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:SublerBatchTableViewDataType] owner:self];
    [pboard setData:data forType:SublerBatchTableViewDataType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)view
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (nil == [info draggingSource]) { // From other application
        [view setDropRow: row dropOperation: NSTableViewDropAbove];
        return NSDragOperationCopy;
    } else if (view == [info draggingSource] && operation == NSTableViewDropAbove) { // From self
        return NSDragOperationEvery;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)tableView:(NSTableView *)view
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
        dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if (tableView == [info draggingSource]) { // From self
        NSData *rowData = [pboard dataForType:SublerBatchTableViewDataType];
        NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
        NSUInteger i = [rowIndexes countOfIndexesInRange:NSMakeRange(0, row)];
        row -= i;

        NSArray *objects = [self.queue itemsAtIndexes:rowIndexes];
        [self.queue removeItemsAtIndexes:rowIndexes];

        for (id object in [objects reverseObjectEnumerator])
            [self.queue insertItem:object atIndex:row];

        NSIndexSet *selectionSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [rowIndexes count])];

        [view reloadData];
        [view selectRowIndexes:selectionSet byExtendingSelection:NO];

        return YES;
    } else { // From other documents
        if ([[pboard types] containsObject:NSURLPboardType] ) {
            NSArray *items = [pboard readObjectsForClasses:
                               [NSArray arrayWithObject: [NSURL class]] options: nil];
            NSMutableArray *queueItems = [[NSMutableArray alloc] init];
            NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

            for (NSURL *url in items) {
                [queueItems addObject:[SBQueueItem itemWithURL:url]];
                [indexes addIndex:row];
            }

            [self addItems:queueItems atIndexes:indexes];

            [queueItems release];
            [indexes release];
            [self updateUI];

            if ([_autoStartOption state])
                [self start:self];

            return YES;
        }
    }

    return NO;
}

- (void)addItem:(SBQueueItem *)item
{
    [self addItems:[NSArray arrayWithObject:item] atIndexes:nil];
    [self updateUI];

    if ([_autoStartOption state])
        [self start:self];
}

- (void)addItems:(NSArray *)items atIndexes:(NSIndexSet *)indexes;
{
    NSMutableIndexSet *mutableIndexes = [indexes mutableCopy];
    if ([indexes count] == [items count]) {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue insertItem:item atIndex:[mutableIndexes firstIndex]];
            [mutableIndexes removeIndexesInRange:NSMakeRange(0, 1)];
        }
    } else if ([indexes count] == 1) {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue insertItem:item atIndex:[mutableIndexes firstIndex]];
        }
    } else {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue addItem:item];
        }
    }

    NSUndoManager *undo = [[self window] undoManager];
    [[undo prepareWithInvocationTarget:self] removeItems:items];

    if (![undo isUndoing]) {
        [undo setActionName:@"Add Queue Item"];
    }
    if ([undo isUndoing] || [undo isRedoing])
        [self updateUI];

    if ([_autoStartOption state])
        [self start:self];

    [mutableIndexes release];
}

- (void)removeItems:(NSArray *)items
{
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    for (id item in items) {
        [indexes addIndex:[self.queue indexOfItem:item]];
        [self.queue removeItem:item];
    }

    NSUndoManager *undo = [[self window] undoManager];
    [[undo prepareWithInvocationTarget:self] addItems:items atIndexes:indexes];

    if (![undo isUndoing]) {
        [undo setActionName:@"Delete Queue Item"];
    }
    if ([undo isUndoing] || [undo isRedoing])
        [self updateUI];

    [indexes release];
}

@end
