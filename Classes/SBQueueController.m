//
//  SBQueueController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBQueueController.h"
#import "SBQueueItem.h"
#import "SBQueuePreferences.h"

#import "SBOptionsViewController.h"
#import "SBItemViewController.h"

#import "SBDocument.h"
#import "SBTableView.h"

#import <MP42Foundation/MP42FileImporter.h>

#import "Subler-Swift.h"

static void *SBQueueContex = &SBQueueContex;

#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"

@interface SBQueueController () <NSPopoverDelegate, NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate, SBItemViewDelegate>

@property (nonatomic, readonly) SBQueuePreferences *prefs;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *options;

@property (nonatomic, weak) IBOutlet SBTableView *table;

@property (nonatomic, readonly) NSImage *docImg;

@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, weak) IBOutlet NSPanel *detachedWindow;

@property (nonatomic, strong) NSPopover *itemPopover;
@property (nonatomic, strong) SBOptionsViewController *windowController;

@property (nonatomic, weak) IBOutlet NSToolbarItem *startItem;

@property (nonatomic, weak) IBOutlet NSTextField *statusLabel;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressBar;

@end

@implementation SBQueueController

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

    if ([NSWindow respondsToSelector:@selector(setAllowsAutomaticWindowTabbing:)]) {
        self.window.tabbingMode = NSWindowTabbingModeDisallowed;
    }

    [self.progressBar setHidden:YES];

    // Load a generic movie icon to display in the table view
    _docImg = [[NSWorkspace sharedWorkspace] iconForFileType:@"mov"];
    _docImg.size = NSMakeSize(16, 16);

    // Drag & Drop
    [self.table registerForDraggedTypes:@[NSFilenamesPboardType, SublerBatchTableViewDataType]];

    // Observe the changes to SBQueueOptimize
    [self addObserver:self forKeyPath:@"options.SBQueueOptimize" options:NSKeyValueObservingOptionInitial context:SBQueueContex];

    // Register to the queue notifications
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueWorkingNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        NSDictionary *info = note.userInfo;
        self.statusLabel.stringValue = [info valueForKey:@"ProgressString"];
        [self.progressBar setIndeterminate:NO];
        self.progressBar.doubleValue = [[info valueForKey:@"Progress"] doubleValue];

        NSInteger index = [info[@"ItemIndex"] integerValue];
        if (index != -1) {
            [self updateUIIndexes:[NSIndexSet indexSetWithIndex:index]];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:SBQueueCompletedNotification object:self.queue queue:mainQueue usingBlock:^(NSNotification *note) {
        [self.progressBar setHidden:YES];
        [self.progressBar stopAnimation:self];
        self.progressBar.doubleValue = 0;
        [self.progressBar setIndeterminate:YES];
        self.startItem.image = [NSImage imageNamed:@"playBackTemplate"];
        [self.statusLabel setStringValue:NSLocalizedString(@"Done", @"Queue -> Done")];

        [self updateUI];

        if ([self.options[SBQueueShowDoneNotification] boolValue]) {
            NSDictionary *info = note.userInfo;

            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = NSLocalizedString(@"Queue done", nil);
            if ([info[@"FailedCount"] unsignedIntegerValue]) {
                notification.informativeText = [NSString stringWithFormat:@"Completed: %lu; Failed: %lu",
                                                [info[@"CompletedCount"] unsignedIntegerValue],
                                                [info[@"FailedCount"] unsignedIntegerValue]];
            }
            else {
                notification.informativeText = [NSString stringWithFormat:@"Completed: %lu",
                                                [info[@"CompletedCount"] unsignedIntegerValue]];
            }
            notification.soundName = NSUserNotificationDefaultSoundName;
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
    }];

    // Update the UI the first time
    [self updateUI];
}

#pragma mark - User Interface Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = anItem.action;

    if (action == @selector(removeSelectedItems:)) {
        if (self.table.selectedRow != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:self.table.selectedRow];
            if (item.status != SBQueueItemStatusWorking)
                return YES;
        } else if (self.table.clickedRow != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:self.table.clickedRow];
            if (item.status != SBQueueItemStatusWorking)
                return YES;
        }
    }

    if (action == @selector(showInFinder:)) {
        if (self.table.clickedRow != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:self.table.clickedRow];
            if (item.status == SBQueueItemStatusCompleted)
                return YES;
        }
    }

    if (action == @selector(edit:)) {
        if (self.table.clickedRow != -1) {
            SBQueueItem *item = [self.queue itemAtIndex:self.table.clickedRow];
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
            self.queue.optimize = [(self.options)[SBQueueOptimize] boolValue];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            SBDocument *doc = [[SBDocument alloc] initWithMP4:mp4 error:&error];

            if (doc) {
                [[NSDocumentController sharedDocumentController] addDocument:doc];
                [doc makeWindowControllers];
                [doc showWindows];

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

    if ([(self.options)[SBQueueMetadata] boolValue]) {
        [item addAction:[[SBQueueMetadataAction alloc] initWithMovieLanguage:self.options[SBQueueMovieProviderLanguage]
                                                              tvShowLanguage:self.options[SBQueueTVShowProviderLanguage]
                                                           movieProvider:self.options[SBQueueMovieProvider]
                                                          tvShowProvider:self.options[SBQueueTVShowProvider]
                                                            preferredArtwork:[self.options[SBQueueProviderArtwork] unsignedIntegerValue]]];
    }

    if ([(self.options)[SBQueueSubtitles] boolValue]) {
        [item addAction:[[SBQueueSubtitlesAction alloc] init]];
    }

    if ([(self.options)[SBQueueOrganize] boolValue]) {
        [item addAction:[[SBQueueOrganizeGroupsAction alloc] init]];
    }

    if ([(self.options)[SBQueueFixFallbacks] boolValue]) {
        [item addAction:[[SBQueueFixFallbacksAction alloc] init]];
    }

    if ([(self.options)[SBQueueClearTrackName] boolValue]) {
        [item addAction:[[SBQueueClearTrackNameAction alloc] init]];
    }

    if ([(self.options)[SBQueueFixTrackLanguage] boolValue]) {
        [item addAction:[[SBQueueSetLanguageAction alloc] initWithLanguage:self.options[SBQueueFixTrackLanguageValue]]];
    }

    if ([(self.options)[SBQueueApplyColorSpace] boolValue]) {
        [item addAction:[[SBQueueColorSpaceAction alloc] initWithTag:[self.options[SBQueueApplyColorSpaceValue] unsignedIntegerValue]]];
    }

    if (self.options[SBQueueSet]) {
        [item addAction:[[SBQueueSetAction alloc] initWithPreset:self.options[SBQueueSet]]];
    }

    id type;
    [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL];

    NSURL *destination = self.options[SBQueueDestination];
    if (destination) {
        destination = [[destination URLByAppendingPathComponent:url.lastPathComponent].URLByDeletingPathExtension
                       URLByAppendingPathExtension:self.options[SBQueueFileType]];
    } else  if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)@"public.mpeg-4")) {
        destination = [url copy];
    } else {
        destination = [url.URLByDeletingPathExtension
                       URLByAppendingPathExtension:(self.options)[SBQueueFileType]];
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
    if (indexes.count == items.count) {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue insertItem:item atIndex:mutableIndexes.firstIndex];
            [mutableIndexes removeIndexesInRange:NSMakeRange(0, 1)];
        }
    } else if (indexes.count == 1) {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue insertItem:item atIndex:mutableIndexes.firstIndex];
        }
    } else {
        for (id item in [items reverseObjectEnumerator]) {
            [self.queue addItem:item];
        }
    }

    NSUndoManager *undo = self.window.undoManager;
    [[undo prepareWithInvocationTarget:self] removeItems:items];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Add Queue Item", @"Queue -> redo add item.")];
    }
    if (undo.undoing || undo.redoing)
        [self updateUI];

    if ([(self.options)[SBQueueAutoStart] boolValue])
        [self start:self];

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

    NSUndoManager *undo = self.window.undoManager;
    [[undo prepareWithInvocationTarget:self] addItems:items atIndexes:indexes];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Delete Queue Item", @"Queue -> Undo delete item.")];
    }
    if (undo.undoing || undo.redoing)
        [self updateUI];

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
        self.popover.contentViewController = [[SBOptionsViewController alloc] initWithOptions:self.options];
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
        self.windowController = [[SBOptionsViewController alloc] initWithOptions:self.options];
    }
    _detachedWindow.contentView = self.windowController.view;
    _detachedWindow.delegate = self;

    return _detachedWindow;
}

/**
 *  Creates a popover with a SBQueueItem
 */
- (void)createItemPopover:(SBQueueItem *)item {
    self.itemPopover = [[NSPopover alloc] init];

    // the popover retains us and we retain the popover,
    // we drop the popover whenever it is closed to avoid a cycle
    SBItemViewController *view = [[SBItemViewController alloc] initWithItem:item];
    view.delegate = self;
    self.itemPopover.contentViewController = view;
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
    NSPopover *closedPopover = notification.object;
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
    NSUInteger count = self.queue.readyCount + ((self.queue.status == SBQueueStatusWorking) ? 1 : 0);

    if (count) {
        NSApp.dockTile.badgeLabel = [NSString stringWithFormat:@"%lu", (unsigned long)count];
    }
    else {
        NSApp.dockTile.badgeLabel = nil;
    }
}

- (void)updateUIIndexes:(NSIndexSet *)indexes {
    [self.table reloadDataForRowIndexes:indexes columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    [self updateState];
}

- (void)updateUI {
    [self.table reloadData];
    [self updateState];
}

- (void)updateState
{
    if (self.queue.status != SBQueueStatusWorking) {
        if (self.queue.count == 1) {
            self.statusLabel.stringValue = NSLocalizedString(@"1 item in queue", nil);
        }
        else {
            self.statusLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%lu items in queue.", nil), (unsigned long)self.queue.count];
        }
    }
    [self updateDockTile];
}

- (IBAction)start:(id)sender {
    if (self.queue.status == SBQueueStatusWorking) {
        return;
    }

    self.startItem.image = [NSImage imageNamed:@"stopTemplate"];
    [self.statusLabel setStringValue:NSLocalizedString(@"Working.", @"Queue -> Working")];
    [self.progressBar setHidden:NO];
    [self.progressBar startAnimation:self];

    [self.queue start];
}

- (IBAction)stop:(id)sender {
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
        [self.popover showRelativeToRect:targetButton.bounds ofView:sender preferredEdge:NSMaxYEdge];
    } else {
        [self.popover close];
        self.popover = nil;
    }
}

- (IBAction)toggleItemsOptions:(id)sender {
    NSInteger index = [self.table rowForView:sender];
    SBQueueItem *item = [self.queue itemAtIndex:index];

    if (self.itemPopover.isShown && ((SBItemViewController *)self.itemPopover.contentViewController).item == item) {
        [self.itemPopover close];
        self.itemPopover = nil;
    }
    else {
        [self createItemPopover:item];
        [self.itemPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
    }
}

#pragma mark Open methods

- (NSArray<SBQueueItem *> *)itemsFromURL:(NSURL *)URL
{
    NSMutableArray<SBQueueItem *> *items = [[NSMutableArray alloc] init];
    NSArray<NSString *> *supportedFileFormats = [MP42FileImporter supportedFileFormats];

    NSNumber *outValue = nil;
    [URL getResourceValue:&outValue forKey:NSURLIsDirectoryKey error:NULL];

    if (outValue.boolValue) {
        NSDirectoryEnumerator *directoryEnumerator =
        [NSFileManager.defaultManager enumeratorAtURL:URL
                           includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                              options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                         errorHandler:nil];
        for (NSURL *URLinDirectory in directoryEnumerator) {
            NSNumber *isDirectory = nil;
            [URLinDirectory getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

            if (isDirectory.boolValue == NO && [supportedFileFormats containsObject:URLinDirectory.pathExtension.lowercaseString]) {
                [items addObject:[self createItemWithURL:URLinDirectory]];
            }
        }
    }
    else if ([supportedFileFormats containsObject:URL.pathExtension.lowercaseString]) {
        [items addObject:[self createItemWithURL:URL]];
    }
    return items;
}

- (void)addItemsFromURLs:(NSArray<NSURL *> *)URLs atIndex:(NSInteger)index
{
    NSMutableArray<SBQueueItem *> *items = [[NSMutableArray alloc] init];
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];

    for (NSURL *URL in URLs) {
        NSArray<SBQueueItem *> *itemsFromURL = [self itemsFromURL:URL];

        for (SBQueueItem *item in itemsFromURL) {
            [items addObject:item];
            [indexes addIndex:index];
        }
    }

    [self addItems:items atIndexes:indexes];
    [self updateUI];
}

- (IBAction)open:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowedFileTypes = [MP42FileImporter supportedFileFormats];

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self addItemsFromURLs:panel.URLs atIndex:self.queue.count];
        }
    }];
}

#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return self.queue.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    NSTableCellView *cell = nil;
    SBQueueItem *item = [self.queue itemAtIndex:row];

    if ([tableColumn.identifier isEqualToString:@"nameColumn"]) {
        cell = [tableView makeViewWithIdentifier:@"nameColumn" owner:self];
        cell.textField.stringValue = item.fileURL.lastPathComponent;

        switch (item.status) {
            case SBQueueItemStatusCompleted:
                cell.imageView.image = [NSImage imageNamed:@"EncodeComplete"];
                [self setAccessiblityLabel:NSLocalizedString(@"Completed", nil)
                                      view:cell.imageView];
                break;
            case SBQueueItemStatusWorking:
                cell.imageView.image = [NSImage imageNamed:@"EncodeWorking"];
                [self setAccessiblityLabel:NSLocalizedString(@"Working", nil)
                                      view:cell.imageView];
                break;
            case SBQueueItemStatusEditing:
                cell.imageView.image = [NSImage imageNamed:@"EncodeWorking"];
                [self setAccessiblityLabel:NSLocalizedString(@"Editing", nil)
                                      view:cell.imageView];
                break;
            case SBQueueItemStatusFailed:
                cell.imageView.image = [NSImage imageNamed:@"EncodeCanceled"];
                [self setAccessiblityLabel:NSLocalizedString(@"Failed", nil)
                                      view:cell.imageView];
                break;
            case SBQueueItemStatusCancelled:
                cell.imageView.image = [NSImage imageNamed:@"EncodeCanceled"];
                [self setAccessiblityLabel:NSLocalizedString(@"Canceled", nil)
                                      view:cell.imageView];
                break;
            default:
                cell.imageView.image = _docImg;
                [self setAccessiblityLabel:@"" view:cell.imageView];
                break;
        }
    }

    return cell;
}

- (void)setAccessiblityLabel:(NSString *)label view:(NSView *)view
{
    static BOOL checked;
    static int available;
    if (!checked) {
        if ([[NSView class] respondsToSelector:@selector(setAccessibilityLabel:)]) {
            available = YES;
        }
        checked = YES;
    }

    if (available) {
        view.accessibilityLabel = label;
    }
}

- (void)_deleteSelectionFromTableView:(NSTableView *)aTableView {
    NSMutableIndexSet *rowIndexes = [aTableView.selectedRowIndexes mutableCopy];
    NSInteger clickedRow = aTableView.clickedRow;
    NSUInteger selectedIndex = -1;

    if (rowIndexes.count) {
         selectedIndex = rowIndexes.firstIndex;
    }

    if (clickedRow != -1 && ![rowIndexes containsIndex:clickedRow]) {
        [rowIndexes removeAllIndexes];
        [rowIndexes addIndex:clickedRow];
    }

    NSArray<SBQueueItem *> *array = [self.queue itemsAtIndexes:rowIndexes];

    // A item with a status of SBQueueItemStatusWorking can not be removed
    for (SBQueueItem *item in array) {
        if (item.status == SBQueueItemStatusWorking) {
            [rowIndexes removeIndex:[self.queue indexOfItem:item]];
        }
    }

    if (rowIndexes.count) {
        [aTableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationSlideUp];
        [self removeItems:array];
        [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];

        [self updateState];
    }
}

- (IBAction)edit:(id)sender {
    SBQueueItem *item = [self.queue itemAtIndex:self.table.clickedRow];
    [self editItem:item];
}

- (IBAction)showInFinder:(id)sender {
    SBQueueItem *item = [self.queue itemAtIndex:self.table.clickedRow];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[item.destURL]];
}

- (IBAction)removeSelectedItems:(id)sender {
    [self _deleteSelectionFromTableView:self.table];
}

- (IBAction)removeCompletedItems:(id)sender {
    NSIndexSet *indexes = [self.queue indexesOfItemsWithStatus:SBQueueItemStatusCompleted];

    if (indexes.count) {
        [self.table removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideUp];
        [self.queue removeItemsAtIndexes:indexes];

        [self updateState];
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

    if (self.table == [info draggingSource]) { // From self
        NSData *rowData = [pboard dataForType:SublerBatchTableViewDataType];
        NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
        NSUInteger i = [rowIndexes countOfIndexesInRange:NSMakeRange(0, row)];
        row -= i;

        NSArray<SBQueueItem *> *objects = [self.queue itemsAtIndexes:rowIndexes];
        [self.queue removeItemsAtIndexes:rowIndexes];

        for (id object in [objects reverseObjectEnumerator])
            [self.queue insertItem:object atIndex:row];

        NSIndexSet *selectionSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, rowIndexes.count)];

        [view reloadData];
        [view selectRowIndexes:selectionSet byExtendingSelection:NO];

        return YES;
    } else { // From other documents
        if ([pboard.types containsObject:NSURLPboardType] ) {

            NSArray *items = [pboard readObjectsForClasses:@[[NSURL class]] options: nil];
            [self addItemsFromURLs:items atIndex:row];

            return YES;
        }
    }

    return NO;
}

@end
