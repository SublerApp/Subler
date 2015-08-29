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

@property (nonatomic, retain) NSArray<NSString *> *tagsArray;

- (void) updateSetsMenu: (id)sender;

@end

@implementation SBMovieViewController

@synthesize tagsArray = _tagsArray;

- (void)loadView
{
    [super loadView];

    [self updateSetsMenu:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSetsMenu:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];

    NSArray<NSString *> *tagsMenu = [metadata writableMetadata];
    for (NSString *tag in tagsMenu) {
        [tagList addItemWithTitle:tag];
    }

    ratingCell = [[NSPopUpButtonCell alloc] init];
    [ratingCell setAutoenablesItems:NO];
    [ratingCell setFont:[NSFont systemFontOfSize:11]];
    [ratingCell setControlSize:NSSmallControlSize];
    [ratingCell setBordered:NO];

	NSArray *ratings = [[MP42Ratings defaultManager] ratings];
    for (NSString *rating in ratings) {
		[[ratingCell menu] addItem:[[[NSMenuItem alloc] initWithTitle:rating action:NULL keyEquivalent:@""] autorelease]];
    }

    genreCell = [[NSComboBoxCell alloc] init];
    [genreCell setCompletes:YES];
    [genreCell setFont:[NSFont systemFontOfSize:11]];
    [genreCell setDrawsBackground:NO];
    [genreCell setBezeled:NO];
    [genreCell setButtonBordered:NO];
    [genreCell setControlSize:NSSmallControlSize];
    [genreCell setIntercellSpacing:NSMakeSize(1.0, 1.0)];
    [genreCell setEditable:YES];
    [genreCell addItemsWithObjectValues:[metadata availableGenres]];

    NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setHeadIndent: -10.0];
    [ps setAlignment:NSRightTextAlignment];

    [mediaKind selectItemWithTag:metadata.mediaKind];
    [contentRating selectItemWithTag:metadata.contentRating];
    [hdVideo selectItemWithTag:metadata.hdVideo];
    [gapless setState:metadata.gapless];
    [podcast setState:metadata.podcast];

    tabCol = [[[tagsTableView tableColumns] objectAtIndex:1] retain];
    width = [tabCol width];

    [self updateTagsArray];

    [tagsTableView setDoubleAction:@selector(doubleClickAction:)];
    [tagsTableView setTarget:self];
    tagsTableView.pasteboardTypes = @[MetadataPBoardType];
    [tagsTableView scrollRowToVisible:0];

    dct = [[NSMutableDictionary alloc] init];

    [imageBrowser setPasteboardTypes:[NSArray arrayWithObjects: NSPasteboardTypeTIFF, NSPasteboardTypePNG, nil]];
    [imageBrowser setZoomValue:1.0];
    [imageBrowser reloadData];
}

- (void)setFile:(MP42File *)file
{
    metadata = [file.metadata retain];
    tags = metadata.tagsDict;
}

- (void)setMetadata:(MP42Metadata *)data
{
    metadata = [data retain];
    tags = data.tagsDict;
}

- (void) updateTagsArray
{
    NSArray<NSString *> *context = [metadata availableMetadata];
    self.tagsArray = [[tags allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
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
    NSArray *metadataKeys = [data allKeys];

    for (NSString *key in metadataKeys) {
        [metadata setTag:[data valueForKey:key] forKey:key];
    }

    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] remove:data];

    if (![undo isUndoing]) {
        [undo setActionName:@"Insert"];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (void) remove:(NSDictionary *) data
{
    NSArray *metadataKeys = [data allKeys];

    for (NSString *key in metadataKeys) {
        [metadata removeTagForKey:key];
    }

    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] add:data];

    if (![undo isUndoing]) {
        [undo setActionName:@"Delete"];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [[sender selectedItem] title];

    if (![metadata.tagsDict valueForKey:tagName])
        [self add:[NSDictionary dictionaryWithObject:@"" forKey:tagName]];
}

- (IBAction) removeTag: (id) sender {
    NSIndexSet *rowIndexes = [tagsTableView selectedRowIndexes];
    NSUInteger current_index = [rowIndexes lastIndex];
    NSMutableDictionary *tagDict = [[[NSMutableDictionary alloc] init] autorelease];

    while (current_index != NSNotFound) {
        if ([tagsTableView editedRow] == -1) {
            NSString *tagName = [self.tagsArray objectAtIndex:current_index];
            [tagDict setObject:[metadata.tagsDict valueForKey:tagName] forKey:tagName];
        }
        current_index = [rowIndexes indexLessThanIndex: current_index];
    }
    [self remove:tagDict];
}

- (void) updateMetadata:(id)value forKey:(NSString *)key
{
    NSString *oldValue = [[[metadata tagsDict] valueForKey:key] retain];

    if ([metadata setTag:value forKey:key]) {

        [tagsTableView noteHeightOfRowsWithIndexesChanged:
            [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [tagsTableView numberOfRows])]];

        NSUndoManager *undo = [[self view] undoManager];
        [[undo prepareWithInvocationTarget:self] updateMetadata:oldValue
                                                      forKey:key];
        if (![undo isUndoing]) {
            [undo setActionName:@"Editing"];
        }
    }
    [oldValue release];
}

- (NSArray *) allSet
{
    return [metadata writableMetadata];
}

- (NSArray *) tvShowSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album", @"Release Date", @"Track #", @"Disk #", @"TV Show", @"TV Episode #", @"TV Network", @"TV Episode ID", @"TV Season", @"Genre", @"Description", @"Long Description", nil];
}

- (NSArray *) movieSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Cast", @"Director", @"Screenwriters", @"Genre", @"Description", @"Long Description", @"Rating", @"Copyright", nil];
}

- (IBAction) addMetadataSet: (id)sender
{
    NSArray *metadataKeys = nil;
    if ([sender tag] == 0) {
        metadataKeys = [self allSet];
    }
    else if ([sender tag] == 1) {
        metadataKeys = [self movieSet];
        metadata.mediaKind = 9;
        [mediaKind selectItemWithTag:metadata.mediaKind];
    }
    else if ([sender tag] == 2) {
        metadataKeys = [self tvShowSet];
        metadata.mediaKind = 10;
        [mediaKind selectItemWithTag:metadata.mediaKind];
    }

    NSMutableDictionary *tagDict = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *key in metadataKeys) {
        if (![[metadata tagsDict] valueForKey:key])
            [tagDict setValue:@"" forKey:key];
    }

    [self add:tagDict];
}

- (void) applySet: (id)sender
{
    NSInteger tag = [sender tag];
    SBPresetManager *presetManager = [SBPresetManager sharedManager];

    MP42Metadata *newTags = [[presetManager presets] objectAtIndex:tag];

    NSArray *metadataKeys = [[newTags tagsDict] allKeys];

    NSMutableDictionary *tagDict = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *key in metadataKeys) {
            [tagDict setValue:[[newTags tagsDict] valueForKey:key] forKey:key];
    }

    [metadata.artworks addObjectsFromArray:newTags.artworks];
    [metadata setIsArtworkEdited:YES];
    [imageBrowser reloadData];

    metadata.mediaKind = newTags.mediaKind;
    [mediaKind selectItemWithTag:metadata.mediaKind];

    metadata.hdVideo = newTags.hdVideo;
    [hdVideo selectItemWithTag:metadata.hdVideo];

    metadata.gapless = newTags.gapless;
    [gapless setState:metadata.gapless];

    metadata.podcast = newTags.podcast;
    [podcast setState:metadata.podcast];

    metadata.contentRating = newTags.contentRating;
    [contentRating selectItemWithTag:metadata.contentRating];

    [self add:tagDict];
}

- (void) updateSetsMenu: (id)sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    NSMenu * setListMenu = [setList menu];

    while ([setListMenu numberOfItems] > 1) {
        [setListMenu removeItemAtIndex: 1];
    }
    
    NSMenuItem *newItem = [[[NSMenuItem alloc] initWithTitle:@"Save Set" action:@selector(showSaveSet:) keyEquivalent:@""] autorelease];
    [newItem setTarget:self];
    [setListMenu addItem:newItem];

    [setListMenu addItem:[NSMenuItem separatorItem]];

    newItem = [[[NSMenuItem alloc] initWithTitle:@"All" action:@selector(addMetadataSet:) keyEquivalent:@""] autorelease];
    [newItem setTarget:self];
    [newItem setTag: 0];
    [setListMenu addItem:newItem];

    newItem = [[[NSMenuItem alloc] initWithTitle:@"Movie" action:@selector(addMetadataSet:) keyEquivalent:@""] autorelease];
    [newItem setTarget:self];
    [newItem setTag: 1];
    [setListMenu addItem:newItem];

    newItem = [[[NSMenuItem alloc] initWithTitle:@"TV Show" action:@selector(addMetadataSet:) keyEquivalent:@""] autorelease];
    [newItem setTarget:self];
    [newItem setTag: 2];
    [setListMenu addItem:newItem];

    if (presetManager.presets.count) {
        [setListMenu addItem:[NSMenuItem separatorItem]];
    }

    NSUInteger i = 0;
    for (MP42Metadata *set in presetManager.presets) {
        newItem = [[NSMenuItem alloc] initWithTitle:[set presetName] action:@selector(applySet:) keyEquivalent:@""];
        if (i < 9) {
            [newItem setKeyEquivalent:[NSString stringWithFormat:@"%lu", (unsigned long)i+1]];
        }

        [newItem setTarget:self];
        [newItem setTag:i++];

        [setListMenu addItem:newItem];
        [newItem release];
    }
}

- (IBAction) showSaveSet: (id)sender
{
    [NSApp beginSheet:saveWindow modalForWindow:[[self view]window]
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) saveSet: (id) sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];

    [metadata setPresetName:[presetName stringValue]];
    [presetManager newSetFromExistingMetadata: metadata];
    
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
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    NSUInteger current_index = [rowIndexes lastIndex];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    NSString *string = @"";

    while (current_index != NSNotFound) {
        NSString *tagName = [self.tagsArray objectAtIndex:current_index];
        NSString *tagValue = [tags objectForKey:tagName];
        string = [string stringByAppendingFormat:@"%@: %@\n",tagName, tagValue];
        [data setValue:tagValue forKey:tagName];

        current_index = [rowIndexes indexLessThanIndex: current_index];
    }

    NSArray *types = @[MetadataPBoardType, NSStringPboardType];
    [pb declareTypes:types owner:nil];
    [pb setString:string forType: NSStringPboardType];
    [pb setData:[NSArchiver archivedDataWithRootObject:data] forType:MetadataPBoardType];
    [data release];
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

    NSArray *classes = [NSArray arrayWithObjects:[NSURL class], [NSImage class], nil];
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSImage imageTypes]
                                                        forKey:NSPasteboardURLReadingContentsConformToTypesKey];
    NSArray *copiedItems = [pasteboard readObjectsForClasses:classes options:options];

    if (copiedItems != nil) {
        for (id item in copiedItems) {
            [self addArtwork:item];
        }

        metadata.isArtworkEdited = YES;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        [imageBrowser reloadData];
    }
}

/* TableView delegate methods */

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[metadata tagsDict] count];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSCell *cell = nil;
    NSString *tagName = nil;

    if (tableColumn != nil)
        tagName = [self.tagsArray objectAtIndex:row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
        cell = [tableColumn dataCell];
    }
    else if ([tableColumn.identifier isEqualToString:@"value"]) {
        if ([tagName isEqualToString:@"Rating"]) {
            cell = ratingCell;
        }
        else if ([tagName isEqualToString:@"Genre"]) {
            cell = genreCell;
        }
        else {
            cell = [tableColumn dataCell];
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
        return tags[self.tagsArray[rowIndex]];
    }

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    NSString *tagName = [self.tagsArray objectAtIndex:rowIndex];
    [dct removeAllObjects];

    if ([tableColumn.identifier isEqualToString:@"value"]) {
		[self updateMetadata:anObject forKey:tagName];
	}
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    NSString *key = [self.tagsArray objectAtIndex:rowIndex];
    CGFloat height;

    if (!(height = [[dct objectForKey:key] floatValue])) {
        //calculate new row height
        NSRect r = NSMakeRect(0,0,width,1000.0);
        NSTextFieldCell *cell = [tabCol dataCellForRow:rowIndex];
        [cell setObjectValue:[tags objectForKey:[self.tagsArray objectAtIndex:rowIndex]]];
        height = [cell cellSizeForBounds:r].height; // Slow, but we cache it.
        [dct setObject:@(height) forKey:key];
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
        if ([[tableView selectedRowIndexes] containsIndex:rowIndex]) {
            [cell setTextColor:[NSColor blackColor]];
        } else {
            [cell setTextColor:[NSColor grayColor]];
        }
    }
}

- (void)tableViewColumnDidResize: (NSNotification* )notification
{
    [dct removeAllObjects];
    width = [tabCol width];
    [tagsTableView noteHeightOfRowsWithIndexesChanged:
     [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [tagsTableView numberOfRows])]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([tagsTableView selectedRow] != -1)
        [removeTag setEnabled:YES];
    else
        [removeTag setEnabled:NO];
}

#pragma mark - Other options

- (IBAction) changeMediaKind: (id) sender
{
    uint8_t tagName = (uint8_t)[[sender selectedItem] tag];

    if (metadata.mediaKind != tagName) {
        metadata.mediaKind = tagName;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changecContentRating: (id) sender
{
    uint8_t tagName = (uint8_t)[[sender selectedItem] tag];

    if (metadata.contentRating != tagName) {
        metadata.contentRating = tagName;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changeGapless: (id) sender
{
    uint8_t newValue;
    if (sender == gapless) {
        newValue = (uint8_t)[gapless state];
    }
    else {
        newValue = ![gapless state];
        [gapless setState:newValue];
    }
    
    if (metadata.gapless != newValue) {
        metadata.gapless = newValue;
        metadata.isEdited = YES;
    }
    
    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] changeGapless: self];
    
    if (![undo isUndoing]) {
        [undo setActionName:@"Check Gapless"];
    }
}

- (IBAction) changePodcast: (id) sender
{
    uint8_t newValue;
    if (sender == podcast) {
        newValue = (uint8_t)[podcast state];
    } else {
        newValue = ![podcast state];
        [podcast setState:newValue];
    }
    
    if (metadata.podcast != newValue) {
        metadata.podcast = newValue;
        metadata.isEdited = YES;
    }
    
    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] changePodcast: self];
    
    if (![undo isUndoing]) {
        [undo setActionName:@"Check Podast"];
    }
}

- (IBAction) changehdVideo: (id) sender
{
    uint8_t tagName = (uint8_t)[[sender selectedItem] tag];
    
    if (metadata.hdVideo != tagName) {
        metadata.hdVideo = tagName;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

#pragma mark -
#pragma mark IKImageBrowserDataSource

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return [metadata.artworks count];
}

- (id)imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index
{
    return [metadata.artworks objectAtIndex:index];
}

- (BOOL)imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex
{
    destinationIndex -= [indexes countOfIndexesInRange:NSMakeRange(0, destinationIndex)];;

    NSArray *objects = [metadata.artworks objectsAtIndexes:indexes];
    [metadata.artworks removeObjectsAtIndexes:indexes];

    for (id object in objects.reverseObjectEnumerator) {
        [metadata.artworks insertObject:object atIndex:destinationIndex];
    }

    metadata.isEdited = YES;
    metadata.isArtworkEdited = YES;
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];

    return YES;
}

- (NSUInteger)imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard
{
    NSInteger index;
    [pasteboard declareTypes:@[NSTIFFPboardType] owner:nil];

    for (index = [itemIndexes lastIndex]; index != NSNotFound; index = [itemIndexes indexLessThanIndex:index]) {
        NSArray *representations = [[[metadata.artworks objectAtIndex:index] image] representations];
        if (representations) {
            NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations
                                                                          usingType:NSTIFFFileType properties:@{}];
            [pasteboard setData:bitmapData forType:NSTIFFPboardType];
        }
    }

    return [itemIndexes count];
}

- (void)imageBrowser:(IKImageBrowserView *) aBrowser removeItemsAtIndexes:(NSIndexSet *) indexes
{
    [metadata.artworks removeObjectsAtIndexes:indexes];

    metadata.isEdited = YES;
    metadata.isArtworkEdited = YES;

    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
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

- (IBAction)zoomSliderDidChange:(id)sender {
    [imageBrowser setZoomValue:[sender floatValue]];
}

- (IBAction)removeArtwork:(id)sender {
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
                [metadata.artworks addObject:artwork];
                [artwork release];
            } else {
                NSImage *artworkImage = [[NSImage alloc] initWithContentsOfURL:item];
                MP42Image *artwork = [[MP42Image alloc] initWithImage:artworkImage];
                [metadata.artworks addObject:artwork];
                [artwork release];
                [artworkImage release];
            }
            return YES;
        }
    } else if ([item isKindOfClass:[NSImage class]]) {
        MP42Image *artwork = [[MP42Image alloc] initWithImage:item];
        [metadata.artworks addObject:artwork];
        [artwork release];
        return YES;
    } else if ([item isKindOfClass:[MP42Image class]]) {
        [metadata.artworks addObject:item];
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

            metadata.isArtworkEdited = YES;
            metadata.isEdited = YES;
            [[[[[self view] window] windowController] document] updateChangeCount:NSChangeDone];
            [imageBrowser reloadData];
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
            metadata.isArtworkEdited = YES;
            metadata.isEdited = YES;
            [[[[[self view] window] windowController] document] updateChangeCount:NSChangeDone];
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

    [_tagsArray release];
    [tabCol release];
    [ratingCell release];
    [genreCell release];
    [dct release];

    [metadata release];

    [super dealloc];
}

@end
