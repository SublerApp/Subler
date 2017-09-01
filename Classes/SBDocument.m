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
#import "SBCheckBoxCellView.h"
#import "SBPopUpCellView.h"

#import "SBEmptyViewController.h"
#import "SBMovieViewController.h"
#import "SBVideoViewController.h"
#import "SBSoundViewController.h"
#import "SBChapterViewController.h"
#import "SBMultiSelectViewController.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Languages.h>
#import <MP42Foundation/MP42Utilities.h>

#import <IOKit/pwr_mgt/IOPMLib.h>

#import "Subler-Swift.h"

#define SublerTableViewDataType @"SublerTableViewDataType"

@interface SBDocument () <NSTableViewDelegate, SBFileImportDelegate>
{
    IBOutlet NSSplitView    *splitView;

    NSSavePanel             *_currentSavePanel;
    IBOutlet NSView         *saveView;
    IBOutlet NSPopUpButton  *fileFormat;

    IBOutlet NSToolbarItem  *addTracks;
    IBOutlet NSToolbarItem  *deleteTrack;
    IBOutlet NSToolbarItem  *searchMetadata;
    IBOutlet NSToolbarItem  *searchChapters;
    IBOutlet NSToolbarItem  *sendToQueue;

    NSViewController        *propertyView;
    IBOutlet NSView         *targetView;

    IBOutlet NSWindow       *offsetWindow;
    IBOutlet NSTextField    *offset;

    IBOutlet NSButton *cancelSave;
    IBOutlet NSButton *_64bit_data;
    IBOutlet NSButton *_64bit_time;
    BOOL _optimize;
}

@property (nonatomic, weak) IBOutlet NSWindow *documentWindow;
@property (nonatomic, weak) IBOutlet SBTableView *tracksTable;

@property (nonatomic, weak) IBOutlet NSWindow *saveWindow;
@property (nonatomic, weak) IBOutlet NSTextField *saveOperationName;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressBar;

@property (nonatomic, strong) NSWindowController *sheetController;

@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSNumber *> *currentSaveAttributes;

@end

@implementation SBDocument

- (NSString *)windowNibName
{
    return @"SBDocument";
}

static NSMenu *_languagesMenu;
static NSDictionary *_detailMonospacedAttr;

+ (void)initialize
{
    if (self == [SBDocument class]) {
        _languagesMenu = [[NSMenu alloc] init];
        _languagesMenu.autoenablesItems = NO;

        for (NSString *title in MP42Languages.defaultManager.localizedExtendedLanguages) {
            [_languagesMenu addItemWithTitle:title action:NULL keyEquivalent:@""];
        }

        if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
            NSFont *font = [NSFont monospacedDigitSystemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular];
            NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            ps.alignment = NSTextAlignmentRight;

            _detailMonospacedAttr = @{NSFontAttributeName: font,
                                      NSParagraphStyleAttributeName: ps};
            
        }
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

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

    self.tracksTable.doubleAction = @selector(doubleClickAction:);
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

#pragma mark - Restorable state

- (void)restoreDocumentWindowWithIdentifier:(NSString *)identifier
                                      state:(NSCoder *)state
                          completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if (!self.windowControllers.count) {
        [self makeWindowControllers];
    }

    completionHandler(self.windowControllers.firstObject.window, nil);
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeInteger:self.tracksTable.selectedRow forKey:@"selectedRow"];
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    [super restoreStateWithCoder:coder];

    NSInteger selectedRow = [coder decodeIntegerForKey:@"selectedRow"];
    if (selectedRow <= self.mp4.tracks.count) {
        [self.tracksTable selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
    }
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

    self.currentSaveAttributes = [self saveAttributes];
    [self showProgressSheet];
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:modifiedCompletionhandler];
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError * _Nullable *)outError
{
    [self unblockUserInteraction];

    IOPMAssertionID assertionID;
    // Enable sleep assertion
    CFStringRef reasonForActivity= CFSTR("Subler Save Operation");
    IOReturn io_success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep,
                                                      kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
    BOOL result = NO;

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
            result = [self.mp4 updateMP4FileWithOptions:self.currentSaveAttributes error:outError];
            break;

        case NSSaveAsOperation:
            // movie does not exist, create a new one from scratch.
            result = [self.mp4 writeToUrl:url options:self.currentSaveAttributes error:outError];
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
        NSString *formatName = CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef _Nonnull)(format)));

        if (formatName == nil) {
            formatName = format;
        }
        [fileFormat addItemWithTitle:formatName];
    }

    [fileFormat selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] valueForKey:@"defaultSaveFormat"] integerValue]];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]) {
        _currentSavePanel.allowedFileTypes = @[[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]];
    }

    NSString *filename = nil;
    for (MP42Track *track in self.mp4.tracks) {
        if (track.URL) {
            filename = track.URL.lastPathComponent.stringByDeletingPathExtension;
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
            requiredFileType = MP42FileTypeM4B;
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
        attributes[MP42ChaptersPreviewPosition] = [NSNumber numberWithFloat:[[NSUserDefaults standardUserDefaults] floatForKey:@"SBChaptersPreviewPosition"]];
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
        if (!self.documentEdited && self.mp4.hasFileRepresentation)
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

    if (action == @selector(showTrackOffsetSheet:) && self.tracksTable.selectedRowIndexes.count == 1
        && self.tracksTable.selectedRow != -1 && self.tracksTable.selectedRow != 0)
        return YES;

    if (action == @selector(addChaptersEvery:))
        return YES;
    
    if (action == @selector(iTunesFriendlyTrackGroups:))
        return YES;

    if (action == @selector(clearTracksNames:))
        return YES;

    if (action == @selector(fixAudioFallbacks:))
        return YES;

	if (action == @selector(export:) && self.tracksTable.selectedRowIndexes.count == 1 && self.tracksTable.selectedRow != -1)
		if ([[self trackAtAtTableRow:self.tracksTable.selectedRow] respondsToSelector:@selector(exportToURL:error:)] &&
            [self trackAtAtTableRow:self.tracksTable.selectedRow].muxed)
			return YES;

    return NO;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    if (toolbarItem == addTracks) {
        return YES;
    }

    if (toolbarItem == deleteTrack) {
        NSIndexSet *indexes = self.tracksTable.selectedRowIndexes;
        return (indexes.count && ![self.tracksTable.selectedRowIndexes containsIndex:0] && NSApp.isActive);
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
    return self.mp4.tracks.count + 1;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *cell = nil;
    if (row) {
        MP42Track *track = [self trackAtAtTableRow:row];

        if (track) {
            if ([tableColumn.identifier isEqualToString:@"trackId"]) {
                cell = [tableView makeViewWithIdentifier:@"IdCell" owner:self];
                cell.textField.stringValue = (track.trackId == 0) ? NSLocalizedString(@"na", nil) : [NSString stringWithFormat:@"%d", track.trackId];
            }
            else if ([tableColumn.identifier isEqualToString:@"trackName"]) {
                cell = [tableView makeViewWithIdentifier:@"NameCell" owner:self];
                cell.textField.stringValue = track.name;
            }
            else if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
                cell = [tableView makeViewWithIdentifier:@"FormatCell" owner:self];
                cell.textField.stringValue = track.formatSummary;
            }
            else if ([tableColumn.identifier isEqualToString:@"trackEnabled"]) {
                SBCheckBoxCellView *checkCell = [tableView makeViewWithIdentifier:@"CheckCell" owner:self];
                checkCell.checkboxButton.state = track.isEnabled;
                cell = checkCell;
            }
            else if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {
                cell = [tableView makeViewWithIdentifier:@"DurationCell" owner:self];

                if (_detailMonospacedAttr) {
                    cell.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:track.timeString attributes:_detailMonospacedAttr];
                }
                else {
                    cell.textField.stringValue = track.timeString;
                }
            }
            else if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
                SBPopUpCellView *popUpCell = [tableView makeViewWithIdentifier:@"PopUpCell" owner:self];

                if (popUpCell.popUpButton.numberOfItems == 0) {
                    popUpCell.popUpButton.menu = [_languagesMenu copy];
                }
                [popUpCell.popUpButton selectItemWithTitle:[MP42Languages.defaultManager localizedLangForExtendedTag:track.language]];
                if (popUpCell.popUpButton.indexOfSelectedItem == -1) {
                    [popUpCell.popUpButton addItemWithTitle:track.language];
                    [popUpCell.popUpButton selectItemWithTitle:track.language];
                }
                cell = popUpCell;
            }
        }
    }
    else {
        if ([tableColumn.identifier isEqualToString:@"trackId"]) {
            cell = [tableView makeViewWithIdentifier:@"disabledIdCell" owner:self];
            cell.textField.stringValue = @"-";
        }
        else if ([tableColumn.identifier isEqualToString:@"trackName"]) {
            cell = [tableView makeViewWithIdentifier:@"IdCell" owner:self];
            cell.textField.stringValue = NSLocalizedString(@"Metadata", nil);
        }
        else if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {
            cell = [tableView makeViewWithIdentifier:@"DurationCell" owner:self];

            NSString *timeString = StringFromTime(self.mp4.duration, 1000);

            if (_detailMonospacedAttr) {
                cell.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:timeString attributes:_detailMonospacedAttr];
            }
            else {
                cell.textField.stringValue = timeString;
            }
        }
        else if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
            cell = [tableView makeViewWithIdentifier:@"DisabledFormatCell" owner:self];
            cell.textField.stringValue = NSLocalizedString(@"-NA-", nil);
        }
        else if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
            cell = [tableView makeViewWithIdentifier:@"DisabledFormatCell" owner:self];
            cell.textField.stringValue = NSLocalizedString(@"-NA-", nil);
        }
    }
    return cell;
}

- (IBAction)doubleClickAction:(id)sender
{
    // make sure they clicked a real cell and not a header or empty row
    if ([sender clickedRow] >= 1) {
        NSTableColumn *column = self.tracksTable.tableColumns[[sender clickedColumn]];
        if ([column.identifier isEqualToString:@"trackName"]) {
            // edit the cell
            [sender editColumn:[sender clickedColumn]
                        row:[sender clickedRow]
                    withEvent:nil
                        select:YES];
        }
    }
}

- (void)reload {
    [self.tracksTable reloadData];
    [self reloadPropertyView];
}

- (IBAction)setTrackName:(NSTextField *)sender {
    NSInteger row = [self.tracksTable rowForView:sender];
    MP42Track *track = [self trackAtAtTableRow:row];

    if (track && ![sender.stringValue isEqualToString:track.name]) {
        track.name = sender.stringValue;
        [self updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setTrackEnabled:(NSButton *)sender {
    NSInteger row = [self.tracksTable rowForView:sender];
    MP42Track *track = [self trackAtAtTableRow:row];
    if (track) {
        track.enabled = sender.state;
        [self updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setTrackLanguage:(NSPopUpButton *)sender {
    NSInteger row = [self.tracksTable rowForView:sender];
    MP42Track *track = [self trackAtAtTableRow:row];

    NSString *localizedLanguage = [MP42Languages.defaultManager.localizedExtendedLanguages objectAtIndex:sender.indexOfSelectedItem];
    NSString *language = [MP42Languages.defaultManager extendedTagForLocalizedLang:localizedLanguage];

    if (track && ![language isEqualToString:track.language]) {
        track.language = language;
        [self updateChangeCount:NSChangeDone];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    [self reloadPropertyView];
}

- (NSInteger)trackIndexAtAtTableRow:(NSUInteger)row
{
    return row - 1;
}

- (MP42Track *)trackAtAtTableRow:(NSInteger)row
{
    if (row <= 0) {
        return nil;
    }
    else {
        return [self.mp4 trackAtIndex:row - 1];
    }
}

- (void)reloadPropertyView
{
    if (propertyView.view != nil) {
        // remove the undo items from the dealloced view
        [self.undoManager removeAllActionsWithTarget:propertyView];

        // remove the current view
		[propertyView.view removeFromSuperview];
    }

    NSInteger row = self.tracksTable.selectedRow;
    NSUInteger numberOfSelectedRows = [self.tracksTable numberOfSelectedRows];

    id controller = nil;
    BOOL metadataRow = (row == -1 || row == 0);
    id track = !metadataRow && numberOfSelectedRows == 1 ? [self trackAtAtTableRow:row] : nil;
    
    if (numberOfSelectedRows > 1) {
        controller = [[SBMultiSelectViewController alloc] initWithNibName:@"MultiSelectView" bundle:nil];
        [(SBMultiSelectViewController *)controller setNumberOfTracks:numberOfSelectedRows];
    } else if (metadataRow) {
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
    propertyView.view.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    // Copy the row numbers to the pasteboard.
    MP42Track *track = [self trackAtAtTableRow:rowIndexes.firstIndex];
    if (!track || track.muxed) {
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
    NSDragOperation result = NSDragOperationNone;
    NSUInteger count = self.mp4.tracks.count + 1;

    if (op == NSTableViewDropAbove && row < count && row != 0) {
        if (![self trackAtAtTableRow:row].muxed) {
            result =  NSDragOperationEvery;
        }
    }
    else if (op == NSTableViewDropAbove && row == count) {
        result = NSDragOperationEvery;
    }

    return result;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSData *rowData = [pboard dataForType:SublerTableViewDataType];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSInteger dragRow = rowIndexes.firstIndex;

    [self.mp4 moveTrackAtIndex:[self trackIndexAtAtTableRow:dragRow]
                       toIndex:[self trackIndexAtAtTableRow:row]];

    [self.tracksTable reloadData];
    return YES;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
    return YES;
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

- (NSURL *)sourceFilename {
    for (MP42Track *track in self.mp4.tracks) {
        if (track.URL) {
            return track.URL;
        }
    }
    return nil;
}

- (IBAction)searchMetadata:(id)sender
{
    NSURL *url = [self sourceFilename];

    if (!url) {
        url = self.fileURL;
    }

    self.sheetController = [[SBMetadataSearchController alloc] initWithDelegate:self url:url];
    [self.documentWindow beginSheet:self.sheetController.window completionHandler:^(NSModalResponse returnCode) {
        self.sheetController = nil;
    }];
}

#pragma mark - Chapters search

- (IBAction)searchChapters:(id)sender
{
    NSString *title = [self.mp4.metadata metadataItemsFilteredByIdentifier:MP42MetadataKeyName].firstObject.stringValue;

    if (title.length == 0) {
        title = [self sourceFilename].lastPathComponent;
    }

    NSUInteger duration = self.mp4.duration;

    self.sheetController = [[SBChapterSearchController alloc] initWithDelegate:self title:title duration:duration];
    [self.documentWindow beginSheet:self.sheetController.window completionHandler:^(NSModalResponse returnCode) {
        self.sheetController = nil;
    }];
}

- (IBAction)showTrackOffsetSheet:(id)sender
{
    offset.doubleValue = [self trackAtAtTableRow:self.tracksTable.selectedRow].startOffset;
    [self.documentWindow beginSheet:offsetWindow completionHandler:NULL];
}

- (IBAction)setTrackOffset:(id)sender
{
    MP42Track *selectedTrack = [self trackAtAtTableRow:self.tracksTable.selectedRow];
    selectedTrack.startOffset = offset.doubleValue;
    [self updateChangeCount:NSChangeDone];

    [self.documentWindow endSheet:offsetWindow];
}

- (IBAction)closeOffsetSheet:(id)sender
{
    [self.documentWindow endSheet:offsetWindow];
}

- (IBAction)deleteTrack:(id)sender
{
    NSMutableIndexSet *trackIndexes = [NSMutableIndexSet indexSet];
    
    if (self.tracksTable.selectedRow == -1  || self.tracksTable.editedRow != -1) {
        return;
    }

    [self.tracksTable.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        if (index > 0) {
            [trackIndexes addIndex:[self trackIndexAtAtTableRow:index]];
        }
    }];
    
    [self.mp4 removeTracksAtIndexes:trackIndexes];
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
        MP42Metadata *xmlMetadata = [[MP42Metadata alloc] initWithURL:URL];
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

    if (row != -1 && [[self trackAtAtTableRow:row] isKindOfClass:[MP42SubtitleTrack class]]) {
        panel.allowedFileTypes = @[@"srt"];
        filename = [filename stringByAppendingFormat:@".%@", [self trackAtAtTableRow:row].language];
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
            id track = [self trackAtAtTableRow:row];

            if (![track exportToURL:panel.URL error:&error]) {

                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle: NSLocalizedString(@"OK", "Export alert panel -> button")];
                [alert setMessageText: NSLocalizedString(@"File Could Not Be Saved", "Export alert panel -> title")];
                alert.informativeText = [NSString stringWithFormat:
                                            NSLocalizedString(@"There was a problem creating the file \"%@\".",
                                                              "Export alert panel -> message"), panel.URL.lastPathComponent];
                alert.alertStyle = NSAlertStyleWarning;
                
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

- (IBAction)clearTracksNames:(id)sender
{
    for (MP42Track *track in self.mp4.tracks) {
        track.name = @"";
    }
    [self.tracksTable reloadData];
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
