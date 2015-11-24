//
//  SBQueueController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBQueueController.h"
#import "SBQueuePreferences.h"
#import "SBQueueItem.h"

#import "SBOptionsViewController.h"
#import "SBItemViewController.h"

#import "SBDocument.h"
#import "SBTableView.h"

#import <MP42Foundation/MP42FileImporter.h>

static void *SBQueueContex = &SBQueueContex;

#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"

@interface SBQueueController () <NSPopoverDelegate, NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate, SBItemViewDelegate>

@property (nonatomic, readonly) SBQueue *queue;
@property (nonatomic, retain) NSPopover *popover;
@property (nonatomic, retain) NSPopover *itemPopover;
@property (nonatomic, retain) SBOptionsViewController *windowController;

@property (nonatomic, readonly) NSMutableDictionary *options;
@property (nonatomic, readonly) SBQueuePreferences *prefs;

- (IBAction)removeSelectedItems:(id)sender;
- (IBAction)removeCompletedItems:(id)sender;

- (IBAction)edit:(id)sender;
- (IBAction)showInFinder:(id)sender;

- (IBAction)toggleStartStop:(id)sender;
- (IBAction)toggleOptions:(id)sender;
- (IBAction)toggleItemsOptions:(id)sender;

- (IBAction)open:(id)sender;

@end


@implementation SBQueueController

@synthesize queue = _queue;
@synthesize popover = _popover;
@synthesize itemPopover = _itemPopover;
@synthesize windowController = _windowController;
@synthesize options = _options;
@synthesize prefs = _prefs;

+ (SBQueueController *)sharedManager {
    static dispatch_once_t pred;
    static SBQueueController *sharedManager = nil;

    dispatch_once(&pred, ^{ sharedManager = [[self alloc] init]; });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super initWithWindowNibName:@"Queue"]) {
        [SBQueuePreferences registerUserDefaults];
        _prefs = [[SBQueuePreferences alloc] init];
        _options = _prefs.options;

        _queue = [[SBQueue alloc] initWithURL:_prefs.queueURL];

        [self removeCompletedItems:self];
        [self updateDockTile];
    }

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [_progressIndicator setHidden:YES];

    // Load a generic movie icon to display in the table view
    _docImg = [[[NSWorkspace sharedWorkspace] iconForFileType:@"public.movie"] retain];
    [_docImg setSize:NSMakeSize(16, 16)];

    [_tableView registerForDraggedTypes:@[NSFilenamesPboardType, SublerBatchTableViewDataType]];


    // Observe the changes to SBQueueOptimize
    [self addObserver:self forKeyPath:@"options.SBQueueOptimize" options:NSKeyValueObservingOptionInitial context:SBQueueContex];

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
        [_startItem setImage:[NSImage imageNamed:@"playBackTemplate"]];
        [_countLabel setStringValue:@"Done"];

        [self updateUI];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueFailedNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        NSDictionary *info = [note userInfo];
        if ([[info valueForKey:@"Error"] isMemberOfClass:[NSError class]]) {
            [NSApp presentError:[info valueForKey:@"Error"]];
        }
    }];

    // Update the UI the first time
    [self updateUI];
}

#pragma mark - User Interface Validation

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

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SBQueueContex) {
        if ([keyPath isEqualToString:@"options.SBQueueOptimize"]) {
            self.queue.optimize = [[self.options objectForKey:SBQueueOptimize] boolValue];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Queue methods

/**
 * The queue status
 */
- (SBQueueStatus)status {
    return self.queue.status;
}

/**
 * Saves the queue and the user defaults.
 */
- (BOOL)saveQueueToDisk {
    [self.prefs saveUserDefaults];
    return [self.queue saveQueueToDisk];
}

/**
 * Opens a SBQueueItem in a new document window
 * and removes it from the queue.
 */
- (void)editItem:(SBQueueItem *)item {
    item.status = SBQueueItemStatusWorking;
    [self updateUI];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __block NSError *error;
        BOOL result = NO;

        if (!item.mp4File) {
            result = [item prepare:&error];
            if (result == NO) {
                NSLog(@"%@", error);
            }

        }

        MP42File *mp4 = item.mp4File;
        dispatch_sync(dispatch_get_main_queue(), ^{
            SBDocument *doc = [[SBDocument alloc] initWithMP4:mp4 error:&error];

            if (doc) {
                [[NSDocumentController sharedDocumentController] addDocument:doc];
                [doc makeWindowControllers];
                [doc showWindows];
                [doc release];

                [self.itemPopover close];

                [self removeItems:@[item]];
                [self updateUI];
            } else {
                NSLog(@"%@", error);
            }
        });
    });
}

#pragma mark - Queue items creation

/**
 *  Creates a new SBQueueItem from an NSURL,
 *  and adds the current actions to it.
 */
- (SBQueueItem *)createItemWithURL:(NSURL *)url {
    SBQueueItem *item = [SBQueueItem itemWithURL:url];

    if ([[self.options objectForKey:SBQueueMetadata] boolValue]) {
        [item addAction:[[[SBQueueMetadataAction alloc] initWithMovieLanguage:[self.options objectForKey:SBQueueMovieProviderLanguage]
                                                               tvShowLanguage:[self.options objectForKey:SBQueueTVShowProviderLanguage]
                                                           movieProvider:[self.options objectForKey:SBQueueMovieProvider]
                                                          tvShowProvider:[self.options objectForKey:SBQueueTVShowProvider]] autorelease]];
    }

    if ([[self.options objectForKey:SBQueueSubtitles] boolValue]) {
        [item addAction:[[[SBQueueSubtitlesAction alloc] init] autorelease]];
    }

    if ([[self.options objectForKey:SBQueueOrganize] boolValue]) {
        [item addAction:[[[SBQueueOrganizeGroupsAction alloc] init] autorelease]];
    }

    if ([[self.options objectForKey:SBQueueFixFallbacks] boolValue]) {
        [item addAction:[[[SBQueueFixFallbacksAction alloc] init] autorelease]];
    }

    if ([self.options objectForKey:SBQueueSet]) {
        [item addAction:[[[SBQueueSetAction alloc] initWithSet:[self.options objectForKey:SBQueueSet]] autorelease]];
    }

    id type;
    [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL];

    NSURL *destination = [self.options objectForKey:SBQueueDestination];
    if (destination) {
        destination = [[[destination URLByAppendingPathComponent:[url lastPathComponent]] URLByDeletingPathExtension]
                       URLByAppendingPathExtension:[self.options objectForKey:SBQueueFileType]];
    } else  if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)@"public.mpeg-4")) {
        destination = [[url copy] autorelease];
    } else {
        destination = [[url URLByDeletingPathExtension]
                       URLByAppendingPathExtension:[self.options objectForKey:SBQueueFileType]];
    }

    item.destURL = destination;

    return item;
}

/**
 *  Adds a SBQueueItem to the queue
 */
- (void)addItem:(SBQueueItem *)item {
    [self addItems:@[item] atIndexes:nil];
    [self updateUI];
}

/**
 *  Adds an array of SBQueueItem to the queue.
 *  Implements the undo manager.
 */
- (void)addItems:(NSArray<SBQueueItem *> *)items atIndexes:(NSIndexSet *)indexes; {
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

    if ([[self.options objectForKey:SBQueueAutoStart] boolValue])
        [self start:self];

    [mutableIndexes release];
}

/**
 *  Removes an array of SBQueueItemfromto the queue.
 *  Implements the undo manager.
 */
- (void)removeItems:(NSArray<SBQueueItem *> *)items {
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

#pragma mark - NSPopover delegate

/**
 *  Creates a popover with the queue options.
 */
- (void)createOptionsPopover {
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

-(NSWindow *)createOptionsWindow {
    if (!self.windowController) {
        self.windowController = [[[SBOptionsViewController alloc] initWithOptions:self.options] autorelease];
    }
    _detachedWindow.contentView = self.windowController.view;
    _detachedWindow.delegate = self;

    return _detachedWindow;
}

/**
 *  Creates a popover with a SBQueueItem
 */
- (void)createItemPopover:(SBQueueItem *)item {
    self.itemPopover = [[[NSPopover alloc] init] autorelease];

    // the popover retains us and we retain the popover,
    // we drop the popover whenever it is closed to avoid a cycle
    SBItemViewController *view = [[[SBItemViewController alloc] initWithItem:item] autorelease];
    view.delegate = self;
    self.itemPopover.contentViewController = view;
    self.itemPopover.appearance = NSPopoverAppearanceMinimal;
    self.itemPopover.animates = YES;

    // AppKit will close the popover when the user interacts with a user interface element outside the popover.
    // note that interacting with menus or panels that become key only when needed will not cause a transient popover to close.
    self.itemPopover.behavior = NSPopoverBehaviorSemitransient;

    // so we can be notified when the popover appears or closes
    self.itemPopover.delegate = self;

}

- (void)setPopoverSize:(NSSize)size {
    self.itemPopover.contentSize = size;
}

- (BOOL)popoverShouldDetach:(NSPopover *)popover
{
    if (popover == self.popover) {
        return YES;
    }

    return NO;
}

- (NSWindow *)detachableWindowForPopover:(NSPopover *)popover {
    if (NSAppKitVersionNumber <= 1343) {
        if (popover == self.popover) {
            return [self createOptionsWindow];
        }
    }

    return nil;
}

- (void)windowWillClose:(NSNotification *)notification {
    self.windowController = nil;
}

- (void)popoverDidClose:(NSNotification *)notification {
    NSPopover *closedPopover = [notification object];
    if (self.popover == closedPopover) {
        self.popover = nil;
    }
    if (self.itemPopover == closedPopover) {
        self.itemPopover = nil;
    }
}

#pragma mark - UI methods

/**
 *  Updates the count on the app dock icon.
 */
- (void)updateDockTile {
    NSUInteger count = [self.queue readyCount] + ((self.queue.status == SBQueueStatusWorking) ? 1 : 0);

    if (count) {
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%lu", (unsigned long)count]];
    }
    else {
        [[NSApp dockTile] setBadgeLabel:nil];
    }
}

- (void)updateUI {
    [_tableView reloadData];
    [self updateDockTile];

    if (self.queue.status != SBQueueStatusWorking) {
        [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
    }
}

- (void)start:(id)sender {
    if (self.queue.status == SBQueueStatusWorking)
        return;

    [_startItem setImage:[NSImage imageNamed:@"stopTemplate"]];
    [_countLabel setStringValue:@"Working."];
    [_progressIndicator setHidden:NO];
    [_progressIndicator startAnimation:self];

    [self.queue start];
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
    [self createOptionsPopover];

    if (!self.popover.isShown) {
        NSButton *targetButton = (NSButton *)sender;
        [self.popover showRelativeToRect:[targetButton bounds] ofView:sender preferredEdge:NSMaxYEdge];
    } else {
        [self.popover close];
        self.popover = nil;
    }
}

- (IBAction)toggleItemsOptions:(id)sender {
    NSInteger clickedRow = [sender clickedRow];
    SBQueueItem *item = [self.queue itemAtIndex:clickedRow];

    if (self.itemPopover.isShown && [(SBItemViewController *)self.itemPopover.contentViewController item] == item) {
        [self.itemPopover close];
        self.itemPopover = nil;
    } else {
        [self createItemPopover:[self.queue itemAtIndex:clickedRow]];
        [self.itemPopover showRelativeToRect:[sender frameOfCellAtColumn:2 row:clickedRow] ofView:sender preferredEdge:NSMaxXEdge];
    }
}

#pragma mark Open methods

- (IBAction)open:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowedFileTypes = [MP42FileImporter supportedFileFormats];

    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMutableArray<SBQueueItem *> *items = [[NSMutableArray alloc] init];

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
    if ([aTableColumn.identifier isEqualToString:@"nameColumn"]) {
        return [[[self.queue itemAtIndex:rowIndex] URL] lastPathComponent];
    } else if ([aTableColumn.identifier isEqualToString:@"statusColumn"]) {
        SBQueueItemStatus batchStatus = [[self.queue itemAtIndex:rowIndex] status];
        if (batchStatus == SBQueueItemStatusCompleted)
            return [NSImage imageNamed:@"EncodeComplete"];
        else if (batchStatus == SBQueueItemStatusWorking || batchStatus == SBQueueItemStatusEditing)
            return [NSImage imageNamed:@"EncodeWorking"];
        else if (batchStatus == SBQueueItemStatusFailed || batchStatus == SBQueueItemStatusCancelled)
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

    NSArray<SBQueueItem *> *array = [self.queue itemsAtIndexes:rowIndexes];

    // A item with a status of SBQueueItemStatusWorking can not be removed
    for (SBQueueItem *item in array)
        if ([item status] == SBQueueItemStatusWorking)
            [rowIndexes removeIndex:[self.queue indexOfItem:item]];

    if ([rowIndexes count]) {
            [aTableView beginUpdates];
            [aTableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationEffectFade];
            [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
            [self removeItems:array];
            [aTableView endUpdates];

        if (self.queue.status != SBQueueStatusWorking) {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
            [self updateDockTile];
        }
    }
    [rowIndexes release];
}

- (IBAction)edit:(id)sender {
    SBQueueItem *item = [[self.queue itemAtIndex:[_tableView clickedRow]] retain];
    [self editItem:item];
    [item release];
}

- (IBAction)showInFinder:(id)sender {
    SBQueueItem *item = [self.queue itemAtIndex:[_tableView clickedRow]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[item.destURL]];
}

- (IBAction)removeSelectedItems:(id)sender {
    [self _deleteSelectionFromTableView:_tableView];
}

- (IBAction)removeCompletedItems:(id)sender {
    NSIndexSet *indexes = [self.queue indexesOfItemsWithStatus:SBQueueItemStatusCompleted];

    if ([indexes count]) {
            [_tableView beginUpdates];
            [_tableView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationEffectFade];
            [_tableView endUpdates];
            [self.queue removeItemsAtIndexes:indexes];

        if (self.queue.status != SBQueueStatusWorking) {
            [_countLabel setStringValue:[NSString stringWithFormat:@"%lu files in queue.", (unsigned long)[self.queue count]]];
            [self updateDockTile];
        }
    }
}

#pragma mark Drag & Drop

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    // Copy the row numbers to the pasteboard.    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:@[SublerBatchTableViewDataType] owner:self];
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

        NSArray<SBQueueItem *> *objects = [self.queue itemsAtIndexes:rowIndexes];
        [self.queue removeItemsAtIndexes:rowIndexes];

        for (id object in [objects reverseObjectEnumerator])
            [self.queue insertItem:object atIndex:row];

        NSIndexSet *selectionSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [rowIndexes count])];

        [view reloadData];
        [view selectRowIndexes:selectionSet byExtendingSelection:NO];

        return YES;
    } else { // From other documents
        if ([[pboard types] containsObject:NSURLPboardType] ) {
            NSArray *items = [pboard readObjectsForClasses:@[[NSURL class]] options: nil];
            NSMutableArray *queueItems = [[NSMutableArray alloc] init];
            NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];
            NSArray<NSString *> *supportedFileFormats = [MP42FileImporter supportedFileFormats];

            for (NSURL *url in items) {
                if ([supportedFileFormats containsObject:url.pathExtension.lowercaseString]) {
                    [queueItems addObject:[self createItemWithURL:url]];
                    [indexes addIndex:row];
                }
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

@end
