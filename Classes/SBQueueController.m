//
//  SBQueueController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBQueueController.h"
#import "SBOptionsViewController.h"

#import "SBQueueItem.h"
#import "SBDocument.h"
#import "SBTableView.h"

#import <MP42Foundation/MP42Utilities.h>

static NSString *fileType = @"mp4";

#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"
#define kOptionsPanelHeight 88

@interface SBQueueController () <NSPopoverDelegate, NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate>

@property (readonly) SBQueue *queue;
@property NSPopover *popover;

@property NSMutableDictionary *options;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)updateUI;
- (void)updateDockTile;
- (NSURL *)queueURL;

- (void)addItems:(NSArray *)items atIndexes:(NSIndexSet *)indexes;
- (void)removeItems:(NSArray *)items;

@end


@implementation SBQueueController

@synthesize queue = _queue;
@synthesize popover = _popover;
@synthesize options = _options;

+ (SBQueueController *)sharedManager {
    static dispatch_once_t pred;
    static SBQueueController *sharedManager = nil;

    dispatch_once(&pred, ^{ sharedManager = [[self alloc] init]; });
    return sharedManager;
}

- (id)init {
    if (self = [super initWithWindowNibName:@"Queue"]) {
        _queue = [[SBQueue alloc] initWithURL:[self queueURL]];
        [self removeCompletedItems:self];
        [self updateDockTile];
    }

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [_progressIndicator setHidden:YES];
    [_countLabel setStringValue:@"Empty"];

    _docImg = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('MOOV')] retain];
    [_docImg setSize:NSMakeSize(16, 16)];

    [_tableView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, SublerBatchTableViewDataType, nil]];

    // Init options
    [self initOptions];

    // Register to the queue notifications
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueWorkingNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        NSDictionary *info = [note userInfo];
        [_countLabel setStringValue:[info valueForKey:@"ProgressString"]];
        [_progressIndicator setIndeterminate:NO];
        [_progressIndicator setDoubleValue:[[info valueForKey:@"Progress"] doubleValue]];

        if ([[info valueForKey:@"ItemIndex"] integerValue] != -1) {
            [self updateUI];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueCompletedNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        [_progressIndicator setHidden:YES];
        [_progressIndicator stopAnimation:self];
        [_progressIndicator setDoubleValue:0];
        [_progressIndicator setIndeterminate:YES];
        [_start setTitle:@"Start"];
        [_countLabel setStringValue:@"Done"];

        [self updateDockTile];
        [self updateUI];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueFailedNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        NSDictionary *info = [note userInfo];
        [NSApp presentError:[info valueForKey:@"Error"]];
    }];

    [self updateUI];
}

- (void)initOptions {
    _options = [[NSMutableDictionary alloc] init];

    // Observe the changes to SBQueueOptimize
    [self addObserver:self forKeyPath:@"options.SBQueueOptimize" options:0 context:NULL];

    [_options setObject:@YES forKey:@"SBQueueOrganize"];
    [_options setObject:@YES forKey:@"SBQueueMetadata"];
    [_options setObject:@NO forKey:@"SBQueueAutoStart"];
    [_options setObject:@YES forKey:@"SBQueueOptimize"];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"]) {
        [_options setObject:[NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"]] forKey:@"SBQueueDestination"];
    }
}

- (NSURL *)queueURL {
    NSURL *appSupportURL = nil;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count]) {
        appSupportURL = [NSURL fileURLWithPath:[[[allPaths lastObject] stringByAppendingPathComponent:@"Subler"]
                                                stringByAppendingPathComponent:@"queue.sbqueue"] isDirectory:YES];
        return appSupportURL;
    } else {
        return nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"options.SBQueueOptimize"]) {
        self.queue.optimize = [[self.options objectForKey:@"SBQueueOptimize"] boolValue];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (SBQueueStatus)status {
    return self.queue.status;
}

- (BOOL)saveQueueToDisk {
    return [self.queue saveQueueToDisk];
}

#pragma mark - NSPopover delegate

- (void)createPopover {
    if (self.popover == nil) {
        // create and setup our popover
        _popover = [[NSPopover alloc] init];

        // the popover retains us and we retain the popover,
        // we drop the popover whenever it is closed to avoid a cycle
        self.popover.contentViewController = [[[SBOptionsViewController alloc] initWithOptions:self.options] autorelease];
        self.popover.appearance = NSPopoverAppearanceMinimal;
        self.popover.animates = YES;

        // AppKit will close the popover when the user interacts with a user interface element outside the popover.
        // note that interacting with menus or panels that become key only when needed will not cause a transient popover to close.
        self.popover.behavior = NSPopoverBehaviorSemitransient;

        // so we can be notified when the popover appears or closes
        self.popover.delegate = self;
    }
}

- (NSWindow *)detachableWindowForPopover:(NSPopover *)popover {
    _detachedWindow.contentView = [[SBOptionsViewController alloc] initWithOptions:self.options].view;

    return _detachedWindow;
}

- (void)popoverDidClose:(NSNotification *)notification {
    self.popover = nil;
}

#pragma mark - UI methods

- (void)updateDockTile {
    NSUInteger count = [self.queue readyCount];

    if (count)
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%d", count]];
    else
        [[NSApp dockTile] setBadgeLabel:nil];
}

- (void)updateUI {
    [_tableView reloadData];
    if (self.queue.status != SBQueueStatusWorking) {
        [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
        [self updateDockTile];
    }
}

- (void)start:(id)sender {
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

- (void)stop:(id)sender {
    [self.queue stop];
}

- (IBAction)toggleStartStop:(id)sender {
    if (self.queue.status == SBQueueStatusWorking) {
        [self stop:sender];
    } else {
        [self start:sender];
    }
}

- (IBAction)toggleOptions:(id)sender {
    [self createPopover];

    if (!self.popover.isShown) {
        NSButton *targetButton = (NSButton *)sender;
        [self.popover showRelativeToRect:[targetButton bounds] ofView:sender preferredEdge:NSMaxXEdge];
    } else {
        [self.popover close];
    }
}

#pragma mark Open methods

- (IBAction)open:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    [panel setAllowedFileTypes:supportedFileFormat()];

    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMutableArray *items = [[NSMutableArray alloc] init];

            for (NSURL *url in [panel URLs]) {
                SBQueueItem *item = [self createItemWithURL:url];
                [items addObject:item];
            }

            [self addItems:items atIndexes:nil];
            [items release];

            [self updateUI];
        }
    }];
}

#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [self.queue count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
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
            return _docImg;
    }

    return nil;
}

- (void)_deleteSelectionFromTableView:(NSTableView *)aTableView {
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

- (IBAction)edit:(id)sender {
    SBQueueItem *item = [[self.queue itemAtIndex:[_tableView clickedRow]] retain];
    
    [self removeItems:[NSArray arrayWithObject:item]];
    [self updateUI];

    if (!item.mp4File)
        [item prepareItem:NULL];

    MP42File *mp4 = item.mp4File;

    SBDocument *doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    [doc setMp4File:mp4];
    [item release];
}

- (IBAction)showInFinder:(id)sender {
    SBQueueItem *item = [self.queue itemAtIndex:[_tableView clickedRow]];
    [[NSWorkspace sharedWorkspace] selectFile:[item.destURL path] inFileViewerRootedAtPath:nil];
}

- (IBAction)removeSelectedItems:(id)sender {
    [self _deleteSelectionFromTableView:_tableView];
}

- (IBAction)removeCompletedItems:(id)sender {
    NSIndexSet *indexes = [self.queue indexesOfItemsWithStatus:SBQueueItemStatusCompleted];

    if ([indexes count]) {
        if ([NSTableView instancesRespondToSelector:@selector(beginUpdates)]) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
            [_tableView beginUpdates];
            [_tableView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationEffectFade];
            [_tableView endUpdates];
            [self.queue removeItemsAtIndexes:indexes];
#endif
        } else {
            [_tableView reloadData];
        }

        if (self.queue.status != SBQueueStatusWorking) {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
            [self updateDockTile];
        }
    }
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = [anItem action];

    if (action == @selector(removeSelectedItems:)) {
        if ([_tableView selectedRow] != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:[_tableView selectedRow]];
            if ([item status] != SBQueueItemStatusWorking)
                return YES;
        } else if ([_tableView clickedRow] != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:[_tableView clickedRow]];
            if ([item status] != SBQueueItemStatusWorking)
                return YES;
        }
    }

    if (action == @selector(showInFinder:)) {
        if ([_tableView clickedRow] != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:[_tableView clickedRow]];
            if ([item status] == SBQueueItemStatusCompleted)
                return YES;
        }
    }

    if (action == @selector(edit:)) {
        if ([_tableView clickedRow] != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:[_tableView clickedRow]];
            if (item.status == SBQueueItemStatusReady)
                return YES;
        }
    }

    if (action == @selector(removeCompletedItems:))
        return YES;

    return NO;
}

#pragma mark Drag & Drop

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
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

    if (_tableView == [info draggingSource]) { // From self
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
                [queueItems addObject:[self createItemWithURL:url]];
                [indexes addIndex:row];
            }

            [self addItems:queueItems atIndexes:indexes];

            [queueItems release];
            [indexes release];
            [self updateUI];

            return YES;
        }
    }

    return NO;
}

- (SBQueueItem *)createItemWithURL:(NSURL *)url {
    SBQueueItem *item = [SBQueueItem itemWithURL:url];

    if ([[self.options objectForKey:@"SBQueueMetadata"] boolValue]) {
        [item addAction:[[[SBQueueMetadataAction alloc] init] autorelease]];
        [item addAction:[[[SBQueueSubtitlesAction alloc] init] autorelease]];
    }
    if ([[self.options objectForKey:@"SBQueueOrganize"] boolValue]) {
        [item addAction:[[[SBQueueOrganizeGroupsAction alloc] init] autorelease]];
    }

    if ([self.options objectForKey:@"SBQueueSet"]) {
        [item addAction:[[[SBQueueSetAction alloc] initWithSet:[self.options objectForKey:@"SBQueueSet"]] autorelease]];
    }


    NSURL *destination = [self.options objectForKey:@"SBQueueDestination"];
    if (destination) {
        destination = [[[destination URLByAppendingPathComponent:[url lastPathComponent]] URLByDeletingPathExtension] URLByAppendingPathExtension:fileType];
    }

    item.destURL = destination;

    return item;
}

- (void)addItem:(SBQueueItem *)item {
    [self addItems:[NSArray arrayWithObject:item] atIndexes:nil];
    [self updateUI];
}

- (void)addItems:(NSArray *)items atIndexes:(NSIndexSet *)indexes; {
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

    if ([[self.options objectForKey:@"SBQueueAutoStart"] boolValue])
        [self start:self];

    [mutableIndexes release];
}

- (void)removeItems:(NSArray *)items {
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
