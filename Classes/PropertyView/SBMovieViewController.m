//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

NSString *MetadataPBoardType = @"SublerMetadataPBoardType";

#import "SBMovieViewController.h"
#import "SBTableView.h"
#import "SBPresetManager.h"
#import "SBTableView.h"
#import "SBImageBrowserView.h"

#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42File.h>

@interface SBMovieViewController () <SBTableViewDelegate, SBImageBrowserViewDelegate>
{
    IBOutlet NSPopUpButton  *tagList;
    IBOutlet NSPopUpButton  *setList;

    IBOutlet SBTableView    *tagsTableView;

    IBOutlet NSPopUpButton  *mediaKind;
    IBOutlet NSPopUpButton  *contentRating;
    IBOutlet NSPopUpButton  *hdVideo;
    IBOutlet NSButton       *gapless;
    IBOutlet NSButton       *podcast;

    IBOutlet NSButton       *removeTag;

    IBOutlet NSWindow       *saveWindow;
    IBOutlet NSTextField    *presetName;

    NSPopUpButtonCell       *ratingCell;
    NSComboBoxCell          *genreCell;

    NSArray<NSString *> *_tagsArray;
    NSDictionary    *detailBoldAttr;

    NSMutableDictionary  *dct;
    NSTableColumn *tabCol;
    CGFloat width;

    IBOutlet SBImageBrowserView *imageBrowser;

    IBOutlet NSButton       *addArtwork;
    IBOutlet NSButton       *removeArtwork;
}

@property (nonatomic, strong) NSArray<NSString *> *tagsArray;

@end

@implementation SBMovieViewController

- (void)loadView
{
    [super loadView];

    [self updateSetsMenu:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSetsMenu:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];

    NSArray<NSString *> *tagsMenu = [self.metadata writableMetadata];
    for (NSString *tag in tagsMenu) {
        [tagList addItemWithTitle:tag];
    }

    ratingCell = [[NSPopUpButtonCell alloc] init];
    [ratingCell setAutoenablesItems:NO];
    ratingCell.font = [NSFont systemFontOfSize:11];
    ratingCell.controlSize = NSSmallControlSize;
    [ratingCell setBordered:NO];

	NSArray *ratings = [MP42Ratings defaultManager].ratings;
    for (NSString *rating in ratings) {
		[ratingCell.menu addItem:[[NSMenuItem alloc] initWithTitle:rating action:NULL keyEquivalent:@""]];
    }

    genreCell = [[NSComboBoxCell alloc] init];
    [genreCell setCompletes:YES];
    genreCell.font = [NSFont systemFontOfSize:11];
    [genreCell setDrawsBackground:NO];
    [genreCell setBezeled:NO];
    [genreCell setButtonBordered:NO];
    genreCell.controlSize = NSSmallControlSize;
    genreCell.intercellSpacing = NSMakeSize(1.0, 1.0);
    [genreCell setEditable:YES];
    [genreCell addItemsWithObjectValues:[self.metadata availableGenres]];

    NSMutableParagraphStyle * ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    ps.headIndent = -10.0;
    ps.alignment = NSRightTextAlignment;

    [mediaKind selectItemWithTag:self.metadata.mediaKind];
    [contentRating selectItemWithTag:self.metadata.contentRating];
    [hdVideo selectItemWithTag:self.metadata.hdVideo];
    gapless.state = self.metadata.gapless;
    podcast.state = self.metadata.podcast;

    tabCol = tagsTableView.tableColumns[1];
    width = tabCol.width;

    [self updateTagsArray];

    tagsTableView.doubleAction = @selector(doubleClickAction:);
    tagsTableView.target = self;
    tagsTableView.pasteboardTypes = @[MetadataPBoardType];
    [tagsTableView scrollRowToVisible:0];

    dct = [[NSMutableDictionary alloc] init];

    imageBrowser.pasteboardTypes = @[NSPasteboardTypeTIFF, NSPasteboardTypePNG];
    [imageBrowser setZoomValue:1.0];
    [imageBrowser reloadData];
}

- (void) updateTagsArray
{
    NSArray<NSString *> *context = [MP42Metadata availableMetadata];
    self.tagsArray = [self.metadata.tagsDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSInteger right = [context indexOfObject:obj2];
        NSInteger left = [context indexOfObject:obj1];
        
        if (right < left)
            return NSOrderedDescending;
        else
            return NSOrderedAscending;
    }];
}

- (void) add:(NSDictionary *) data
{
    NSArray *metadataKeys = data.allKeys;

    for (NSString *key in metadataKeys) {
        [self.metadata setTag:[data valueForKey:key] forKey:key];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] remove:data];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Insert", @"Undo tag insert.")];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (void) remove:(NSDictionary *) data
{
    NSArray *metadataKeys = data.allKeys;

    for (NSString *key in metadataKeys) {
        [self.metadata removeTagForKey:key];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] add:data];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Delete", @"Undo tag delete")];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [sender selectedItem].title;

    if (![self.metadata.tagsDict valueForKey:tagName])
        [self add:@{tagName: @""}];
}

- (IBAction) removeTag: (id) sender {
    NSIndexSet *rowIndexes = tagsTableView.selectedRowIndexes;
    NSUInteger current_index = rowIndexes.lastIndex;
    NSMutableDictionary *tagDict = [[NSMutableDictionary alloc] init];

    while (current_index != NSNotFound) {
        if (tagsTableView.editedRow == -1) {
            NSString *tagName = (self.tagsArray)[current_index];
            tagDict[tagName] = [self.metadata.tagsDict valueForKey:tagName];
        }
        current_index = [rowIndexes indexLessThanIndex: current_index];
    }
    [self remove:tagDict];
}

- (void) updateMetadata:(id)value forKey:(NSString *)key
{
    NSString *oldValue = [self.metadata.tagsDict valueForKey:key];

    if ([self.metadata setTag:value forKey:key]) {

        [tagsTableView noteHeightOfRowsWithIndexesChanged:
            [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, tagsTableView.numberOfRows)]];

        NSUndoManager *undo = self.view.undoManager;
        [[undo prepareWithInvocationTarget:self] updateMetadata:oldValue
                                                      forKey:key];
        if (!undo.undoing) {
            [undo setActionName:NSLocalizedString(@"Editing", @"Undo tag editing.")];
        }
    }
}

- (NSArray *) allSet
{
    return [self.metadata writableMetadata];
}

- (NSArray *) tvShowSet
{
    return @[@"Name", @"Artist", @"Album", @"Release Date", @"Track #", @"Disk #", @"TV Show", @"TV Episode #", @"TV Network", @"TV Episode ID", @"TV Season", @"Genre", @"Description", @"Long Description"];
}

- (NSArray *) movieSet
{
    return @[@"Name", @"Artist", @"Album", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Cast", @"Director", @"Screenwriters", @"Genre", @"Description", @"Long Description", @"Rating", @"Copyright"];
}

- (IBAction) addMetadataSet: (id)sender
{
    NSArray *metadataKeys = nil;
    if ([sender tag] == 0) {
        metadataKeys = [self allSet];
    }
    else if ([sender tag] == 1) {
        metadataKeys = [self movieSet];
        self.metadata.mediaKind = 9;
        [mediaKind selectItemWithTag:self.metadata.mediaKind];
    }
    else if ([sender tag] == 2) {
        metadataKeys = [self tvShowSet];
        self.metadata.mediaKind = 10;
        [mediaKind selectItemWithTag:self.metadata.mediaKind];
    }

    NSMutableDictionary *tagDict = [[NSMutableDictionary alloc] init];
    for (NSString *key in metadataKeys) {
        if (![self.metadata.tagsDict valueForKey:key])
            [tagDict setValue:@"" forKey:key];
    }

    [self add:tagDict];
}

- (void) applySet: (id)sender
{
    NSInteger tag = [sender tag];
    SBPresetManager *presetManager = [SBPresetManager sharedManager];

    MP42Metadata *newTags = presetManager.presets[tag];

    NSArray *metadataKeys = newTags.tagsDict.allKeys;

    NSMutableDictionary *tagDict = [[NSMutableDictionary alloc] init];
    for (NSString *key in metadataKeys) {
        [tagDict setValue:[newTags.tagsDict valueForKey:key] forKey:key];
    }

    [self.metadata.artworks addObjectsFromArray:newTags.artworks];
    [self.metadata setIsArtworkEdited:YES];
    [imageBrowser reloadData];

    self.metadata.mediaKind = newTags.mediaKind;
    [mediaKind selectItemWithTag:self.metadata.mediaKind];

    self.metadata.hdVideo = newTags.hdVideo;
    [hdVideo selectItemWithTag:self.metadata.hdVideo];

    self.metadata.gapless = newTags.gapless;
    gapless.state = self.metadata.gapless;

    self.metadata.podcast = newTags.podcast;
    podcast.state = self.metadata.podcast;

    self.metadata.contentRating = newTags.contentRating;
    [contentRating selectItemWithTag:self.metadata.contentRating];

    [self add:tagDict];
}

- (void) updateSetsMenu: (id)sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    NSMenu * setListMenu = setList.menu;

    while (setListMenu.numberOfItems > 1) {
        [setListMenu removeItemAtIndex: 1];
    }
    
    NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Save Set", @"Set menu") action:@selector(showSaveSet:) keyEquivalent:@""];
    newItem.target = self;
    [setListMenu addItem:newItem];

    [setListMenu addItem:[NSMenuItem separatorItem]];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"All", @"Set menu All set") action:@selector(addMetadataSet:) keyEquivalent:@""];
    newItem.target = self;
    newItem.tag = 0;
    [setListMenu addItem:newItem];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Movie", @"Set menu Movie set") action:@selector(addMetadataSet:) keyEquivalent:@""];
    newItem.target = self;
    newItem.tag = 1;
    [setListMenu addItem:newItem];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"TV Show", @"Set menu TV Show Set") action:@selector(addMetadataSet:) keyEquivalent:@""];
    newItem.target = self;
    newItem.tag = 2;
    [setListMenu addItem:newItem];

    if (presetManager.presets.count) {
        [setListMenu addItem:[NSMenuItem separatorItem]];
    }

    NSUInteger i = 0;
    for (MP42Metadata *set in presetManager.presets) {
        newItem = [[NSMenuItem alloc] initWithTitle:set.presetName action:@selector(applySet:) keyEquivalent:@""];
        if (i < 9) {
            newItem.keyEquivalent = [NSString stringWithFormat:@"%lu", (unsigned long)i+1];
        }

        newItem.target = self;
        newItem.tag = i++;

        [setListMenu addItem:newItem];
    }
}

- (IBAction) showSaveSet: (id)sender
{
    [NSApp beginSheet:saveWindow modalForWindow:self.view.window
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) saveSet: (id) sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];

    self.metadata.presetName = presetName.stringValue;
    [presetManager newSetFromExistingMetadata: self.metadata];
    
    [NSApp endSheet: saveWindow];
    [saveWindow orderOut:self];
}

- (IBAction) closeSaveSheet: (id) sender
{
    [NSApp endSheet: saveWindow];
    [saveWindow orderOut:self];
}

/* NSTableView additions for copy & paste and more */

#pragma mark - Table View delegate

- (IBAction)doubleClickAction:(id)sender
{
    // make sure they clicked a real cell and not a header or empty row
    if ([sender clickedRow] != -1 && [sender clickedColumn] == 1) { 
        // edit the cell
        [sender editColumn:[sender clickedColumn] 
                       row:[sender clickedRow]
                 withEvent:nil
                    select:YES];
    }
}

- (void)_deleteSelectionFromTableView:(NSTableView *)tableView;
{
    [self removeTag:tableView];
}

- (void)_copySelectionFromTableView:(NSTableView *)tableView;
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSIndexSet *rowIndexes = tableView.selectedRowIndexes;
    NSUInteger current_index = rowIndexes.lastIndex;
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    NSString *string = @"";

    while (current_index != NSNotFound) {
        NSString *tagName = (self.tagsArray)[current_index];
        NSString *tagValue = self.metadata.tagsDict[tagName];
        string = [string stringByAppendingFormat:@"%@: %@\n",tagName, tagValue];
        [data setValue:tagValue forKey:tagName];

        current_index = [rowIndexes indexLessThanIndex: current_index];
    }

    NSArray *types = @[MetadataPBoardType, NSStringPboardType];
    [pb declareTypes:types owner:nil];
    [pb setString:string forType: NSStringPboardType];
    [pb setData:[NSArchiver archivedDataWithRootObject:data] forType:MetadataPBoardType];
}

- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
{
    [self _copySelectionFromTableView:tableView];
    [self removeTag:tableView];
}

- (void)_pasteToTableView:(NSTableView *)tableView
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSData *archivedData = [pb dataForType:MetadataPBoardType];
    NSMutableDictionary *data = [NSUnarchiver unarchiveObjectWithData:archivedData];

    [self add:data];
}

- (void)_pasteToImageBrowserView:(IKImageBrowserView *)ImageBrowserView
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

    NSArray *classes = @[[NSURL class], [NSImage class]];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes]};
    NSArray *copiedItems = [pasteboard readObjectsForClasses:classes options:options];

    if (copiedItems != nil) {
        for (id item in copiedItems) {
            [self addArtwork:item];
        }

        self.metadata.isArtworkEdited = YES;
        self.metadata.isEdited = YES;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        [imageBrowser reloadData];
    }
}

/* TableView delegate methods */

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return self.metadata.tagsDict.count;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSCell *cell = nil;
    NSString *tagName = nil;

    if (tableColumn != nil)
        tagName = (self.tagsArray)[row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
        cell = tableColumn.dataCell;
    }
    else if ([tableColumn.identifier isEqualToString:@"value"]) {
        if ([tagName isEqualToString:@"Rating"]) {
            cell = ratingCell;
        }
        else if ([tagName isEqualToString:@"Genre"]) {
            cell = genreCell;
        }
        else {
            cell = tableColumn.dataCell;
        }
    }
    else {
        cell = nil;
    }

    return cell;
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        return self.tagsArray[rowIndex];
    }

    if ([tableColumn.identifier isEqualToString:@"value"]) {
        return self.metadata.tagsDict[self.tagsArray[rowIndex]];
    }

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    NSString *tagName = (self.tagsArray)[rowIndex];
    [dct removeAllObjects];

    if ([tableColumn.identifier isEqualToString:@"value"]) {
		[self updateMetadata:anObject forKey:tagName];
	}
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    NSString *key = (self.tagsArray)[rowIndex];
    CGFloat height;

    if (!(height = [dct[key] floatValue])) {
        //calculate new row height
        NSRect r = NSMakeRect(0,0,width,1000.0);
        NSTextFieldCell *cell = [tabCol dataCellForRow:rowIndex];
        cell.objectValue = self.metadata.tagsDict[(self.tagsArray)[rowIndex]];
        height = [cell cellSizeForBounds:r].height; // Slow, but we cache it.
        dct[key] = @(height);
    }

    if (height < 14.0) {
        return 14.0;
    }
    else {
        return height;
    }
}

- (NSString *) tableView: (NSTableView *) aTableView
          toolTipForCell: (NSCell *) aCell 
                    rect: (NSRectPointer) rect 
             tableColumn: (NSTableColumn *) aTableColumn
                     row: (NSInteger) row
           mouseLocation: (NSPoint) mouseLocation
{
    return nil;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        if ([tableView.selectedRowIndexes containsIndex:rowIndex]) {
            [cell setTextColor:[NSColor blackColor]];
        } else {
            [cell setTextColor:[NSColor grayColor]];
        }
    }
}

- (void)tableViewColumnDidResize: (NSNotification* )notification
{
    [dct removeAllObjects];
    width = tabCol.width;
    [tagsTableView noteHeightOfRowsWithIndexesChanged:
     [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, tagsTableView.numberOfRows)]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (tagsTableView.selectedRow != -1)
        [removeTag setEnabled:YES];
    else
        [removeTag setEnabled:NO];
}

#pragma mark - Other options

- (IBAction) changeMediaKind: (id) sender
{
    uint8_t tagName = (uint8_t)[sender selectedItem].tag;

    if (self.metadata.mediaKind != tagName) {
        self.metadata.mediaKind = tagName;
        self.metadata.isEdited = YES;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changecContentRating: (id) sender
{
    uint8_t tagName = (uint8_t)[sender selectedItem].tag;

    if (self.metadata.contentRating != tagName) {
        self.metadata.contentRating = tagName;
        self.metadata.isEdited = YES;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changeGapless: (id) sender
{
    uint8_t newValue;
    if (sender == gapless) {
        newValue = (uint8_t)gapless.state;
    }
    else {
        newValue = !gapless.state;
        gapless.state = newValue;
    }
    
    if (self.metadata.gapless != newValue) {
        self.metadata.gapless = newValue;
        self.metadata.isEdited = YES;
    }
    
    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] changeGapless: self];
    
    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Check Gapless", @"Undo check gapless")];
    }
}

- (IBAction) changePodcast: (id) sender
{
    uint8_t newValue;
    if (sender == podcast) {
        newValue = (uint8_t)podcast.state;
    } else {
        newValue = !podcast.state;
        podcast.state = newValue;
    }
    
    if (self.metadata.podcast != newValue) {
        self.metadata.podcast = newValue;
        self.metadata.isEdited = YES;
    }
    
    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] changePodcast: self];
    
    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Check Podast", @"Undo check podcast")];
    }
}

- (IBAction) changehdVideo: (id) sender
{
    uint8_t tagName = (uint8_t)[sender selectedItem].tag;
    
    if (self.metadata.hdVideo != tagName) {
        self.metadata.hdVideo = tagName;
        self.metadata.isEdited = YES;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

#pragma mark -
#pragma mark IKImageBrowserDataSource

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return (self.metadata.artworks).count;
}

- (id)imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index
{
    return (self.metadata.artworks)[index];
}

- (BOOL)imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex
{
    destinationIndex -= [indexes countOfIndexesInRange:NSMakeRange(0, destinationIndex)];;

    NSArray *objects = [self.metadata.artworks objectsAtIndexes:indexes];
    [self.metadata.artworks removeObjectsAtIndexes:indexes];

    for (id object in objects.reverseObjectEnumerator) {
        [self.metadata.artworks insertObject:object atIndex:destinationIndex];
    }

    self.metadata.isEdited = YES;
    self.metadata.isArtworkEdited = YES;
    [self.view.window.windowController.document updateChangeCount:NSChangeDone];

    return YES;
}

- (NSUInteger)imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard
{
    NSInteger index;
    [pasteboard declareTypes:@[NSTIFFPboardType] owner:nil];

    for (index = itemIndexes.lastIndex; index != NSNotFound; index = [itemIndexes indexLessThanIndex:index]) {
        NSArray *representations = (self.metadata.artworks)[index].image.representations;
        if (representations) {
            NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations
                                                                          usingType:NSTIFFFileType properties:@{}];
            [pasteboard setData:bitmapData forType:NSTIFFPboardType];
        }
    }

    return itemIndexes.count;
}

- (void)imageBrowser:(IKImageBrowserView *) aBrowser removeItemsAtIndexes:(NSIndexSet *) indexes
{
    [self.metadata.artworks removeObjectsAtIndexes:indexes];

    self.metadata.isEdited = YES;
    self.metadata.isArtworkEdited = YES;

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

#pragma mark -
#pragma mark IKImageBrowserDelegate

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)aBrowser
{
    NSIndexSet *rowIndexes = [aBrowser selectionIndexes];

    if (rowIndexes.count) {
        [removeArtwork setEnabled:YES];
    }
    else {
        [removeArtwork setEnabled:NO];
    }
}

- (IBAction)zoomSliderDidChange:(id)sender
{
    [imageBrowser setZoomValue:[sender floatValue]];
}

- (IBAction)removeArtwork:(id)sender
{
    [self imageBrowser:imageBrowser removeItemsAtIndexes:[imageBrowser selectionIndexes]];
    [imageBrowser reloadData];
}

- (BOOL)addArtwork:(id)item
{
    NSString *type;
    NSError *error;

    if ([item isKindOfClass:[NSURL class]]) {
        if ([item getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error]) {
            if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)@"public.jpeg")) {
                MP42Image *artwork = [[MP42Image alloc] initWithData:[NSData dataWithContentsOfURL:item] type:MP42_ART_JPEG];
                [self.metadata.artworks addObject:artwork];
            } else {
                NSImage *artworkImage = [[NSImage alloc] initWithContentsOfURL:item];
                MP42Image *artwork = [[MP42Image alloc] initWithImage:artworkImage];
                [self.metadata.artworks addObject:artwork];
            }
            return YES;
        }
    } else if ([item isKindOfClass:[NSImage class]]) {
        MP42Image *artwork = [[MP42Image alloc] initWithImage:item];
        [self.metadata.artworks addObject:artwork];
        return YES;
    } else if ([item isKindOfClass:[MP42Image class]]) {
        [self.metadata.artworks addObject:item];
        return YES;
    }

    return NO;
}

- (IBAction)selectArtwork:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowedFileTypes = @[@"public.image"];

    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {

            for (NSURL *url in panel.URLs) {
                [self addArtwork:url];
            }

            self.metadata.isArtworkEdited = YES;
            self.metadata.isEdited = YES;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            [self->imageBrowser reloadData];
        }
    }];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    return NSDragOperationGeneric;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id)sender
{
    BOOL edited = NO;
    NSPasteboard *pasteboard = [sender draggingPasteboard];

    NSArray *classes = @[[NSURL class], [NSImage class]];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes]};
    NSArray *draggedItems = [pasteboard readObjectsForClasses:classes options:options];

    if (draggedItems) {
        for (id dragItem in draggedItems) {
            edited = [self addArtwork:dragItem];
        }

        if (edited) {
            self.metadata.isArtworkEdited = YES;
            self.metadata.isEdited = YES;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
            [imageBrowser reloadData];

            return YES;
        }
    }

	return NO;
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
	[imageBrowser reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [imageBrowser setDelegate:nil];
    [imageBrowser setDataSource:nil];
    [tagsTableView setDelegate:nil];
    [tagsTableView setDataSource:nil];
}

@end
