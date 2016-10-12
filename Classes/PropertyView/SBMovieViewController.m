//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

NSString *SublerMetadataPBoardType = @"SublerMetadataPBoardTypeV2";
NSString *SublerCoverArtPBoardType = @"SublerCoverArtPBoardType";

#import "SBMovieViewController.h"
#import "SBTableView.h"
#import "SBPresetManager.h"
#import "SBImageBrowserView.h"
#import "SBPopUpCellView.h"
#import "SBCheckBoxCellView.h"

#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/NSString+MP42Additions.h>

@interface SBMovieViewController () <NSTableViewDataSource, SBTableViewDelegate, SBImageBrowserViewDelegate>

// Metadata tab
@property (nonatomic) NSArray<MP42MetadataItem *> *tags;
@property (nonatomic) NSMutableArray<MP42MetadataItem *> *artworks;

@property (nonatomic) NSArray<NSString *> *ratings;

@property (nonatomic) NSTableCellView *dummyCell;
@property (nonatomic) NSLayoutConstraint *dummyCellWidth;
@property (nonatomic) NSTableColumn *column;
@property (nonatomic) CGFloat columnWidth;
@property (nonatomic) CGFloat previousColumnWidth;
@property (nonatomic) NSMutableDictionary<NSString *,NSNumber *> *rowHeights;

@property (nonatomic, weak) IBOutlet NSPopUpButton *tagsPopUp;
@property (nonatomic, weak) IBOutlet NSPopUpButton *setsPopUp;

@property (nonatomic, weak) IBOutlet NSButton *removeTagButton;
@property (nonatomic, weak) IBOutlet SBTableView *metadataTableView;

// Artwork tab
@property (nonatomic, weak) IBOutlet NSButton *removeArtworkButton;
@property (nonatomic, weak) IBOutlet SBImageBrowserView *artworksView;

// Set save window
@property (nonatomic, strong) IBOutlet NSWindow *saveSetWindow;
@property (nonatomic, weak) IBOutlet NSTextField *saveSetName;

@end

@implementation SBMovieViewController

static NSArray<NSArray *> *_contentRatings;
static NSArray<NSArray *> *_hdVideo;
static NSArray<NSArray *> *_mediaKinds;

+ (void)initialize
{
    if (self == [SBMovieViewController class]) {
        _contentRatings = @[@[NSLocalizedString(@"None", nil), @0], @[NSLocalizedString(@"Clean", nil), @2], @[NSLocalizedString(@"Explicit", nil), @4]];
        _mediaKinds = @[@[NSLocalizedString(@"Home Video", nil), @0], @[NSLocalizedString(@"Music", nil), @1], @[NSLocalizedString(@"Audiobook", nil), @2],
                        @[NSLocalizedString(@"Music Video", nil), @6], @[NSLocalizedString(@"Movie", nil), @9], @[NSLocalizedString(@"TV Show", nil), @10],
                        @[NSLocalizedString(@"Booklet", nil), @11], @[NSLocalizedString(@"Ringtone", nil), @14], @[NSLocalizedString(@"Podcast", nil), @21],
                        @[NSLocalizedString(@"iTunes U", nil), @23], @[NSLocalizedString(@"Alert Tone", nil), @27]];
        _hdVideo = @[@[NSLocalizedString(@"No", nil), @0], @[NSLocalizedString(@"720p", nil), @1], @[NSLocalizedString(@"1080p", nil), @2]];
    }
}

- (void)loadView
{
    [super loadView];

    _ratings = [MP42Ratings defaultManager].ratings;

    [self updateSetsMenu:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSetsMenu:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];

    NSArray<NSString *> *tagsMenu = [MP42Metadata writableMetadata];
    for (NSString *tag in tagsMenu) {
        [self.tagsPopUp addItemWithTitle:tag];
    }

    self.column = self.metadataTableView.tableColumns[1];
    self.columnWidth = self.column.width;
    _rowHeights = [[NSMutableDictionary alloc] init];

    [self updateMetadataArray];

    self.metadataTableView.doubleAction = @selector(doubleClickAction:);
    self.metadataTableView.target = self;
    self.metadataTableView.pasteboardTypes = @[SublerMetadataPBoardType];
    [self.metadataTableView scrollRowToVisible:0];

    self.artworksView.pasteboardTypes = @[SublerCoverArtPBoardType, NSPasteboardTypeTIFF, NSPasteboardTypePNG];
    [self.artworksView setZoomValue:1.0];
    [self.artworksView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_artworksView setDelegate:nil];
    [_artworksView setDataSource:nil];
    [_metadataTableView setDelegate:nil];
    [_metadataTableView setDataSource:nil];
}

- (void)setMetadata:(MP42Metadata *)metadata
{
    _metadata = metadata;

    [self updateMetadataArray];
    [self updateCoverArtArray];
}

#pragma mark - Metadata

- (void)updateMetadataArray
{
    NSArray<NSString *> *context = [MP42Metadata availableMetadata];

    MP42MetadataItemDataType dataTypes = MP42MetadataItemDataTypeString | MP42MetadataItemDataTypeStringArray |
                                         MP42MetadataItemDataTypeBool | MP42MetadataItemDataTypeInteger |
                                         MP42MetadataItemDataTypeIntegerArray | MP42MetadataItemDataTypeDate;
    self.tags = [self.metadata metadataItemsFilteredByDataType:dataTypes];

    self.tags = [self.tags sortedArrayUsingComparator:^NSComparisonResult(MP42MetadataItem *obj1, MP42MetadataItem *obj2) {
        NSInteger right = [context indexOfObject:obj2.identifier];
        NSInteger left = [context indexOfObject:obj1.identifier];
        return (right < left) ? NSOrderedDescending : NSOrderedAscending;
    }];
}

- (void)addMetadataItems:(NSArray<MP42MetadataItem *> *)items
{
    for (MP42MetadataItem *item in items) {
        [self.metadata addMetadataItem:item];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] removeMetadataItems:items];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Insert", @"Undo tag insert.")];
    }

    [self updateMetadataArray];
    [self.metadataTableView reloadData];
}

- (void)removeMetadataItems:(NSArray<MP42MetadataItem *> *)items
{
    for (MP42MetadataItem *item in items) {
        [self.metadata removeMetadataItem:item];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] addMetadataItems:items];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Delete", @"Undo tag delete")];
    }

    [self updateMetadataArray];
    [self.metadataTableView reloadData];
}

- (void)replaceMetadataItem:(MP42MetadataItem *)item withItem:(MP42MetadataItem *)newItem
{
    [self.metadata removeMetadataItem:item];
    [self.metadata addMetadataItem:newItem];

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] replaceMetadataItem:newItem withItem:item];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Editing", @"Undo tag editing")];
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];

    }
    else {
        [self.view.window.windowController.document updateChangeCount:NSChangeUndone];
    }

    [self updateMetadataArray];

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0];

    NSUInteger index = [self.tags indexOfObject:newItem];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    NSIndexSet *colIndexSet = [NSIndexSet indexSetWithIndex:1];

    [self.metadataTableView reloadDataForRowIndexes:indexSet columnIndexes:colIndexSet];
    [self.metadataTableView noteHeightOfRowsWithIndexesChanged:indexSet];

    [NSAnimationContext endGrouping];
}

- (IBAction)addTag:(id)sender
{
    NSString *identifier = [sender selectedItem].title;

    if (![self.metadata metadataItemsFilteredByIdentifier:identifier].count) {
        MP42MetadataItem *item = [MP42MetadataItem metadataItemWithIdentifier:identifier
                                                                        value:@""
                                                                     dataType:MP42MetadataItemDataTypeUnspecified
                                                          extendedLanguageTag:nil];
        [self addMetadataItems:@[item]];
    }
}

- (IBAction)removeTag:(id)sender
{
    NSArray<MP42MetadataItem *> *items = [self.tags objectsAtIndexes:self.metadataTableView.selectedRowIndexes];
    [self removeMetadataItems:items];
}

#pragma mark - Built In presets.

- (NSArray *)allSet
{
    return [MP42Metadata writableMetadata];
}

- (NSArray *)tvShowSet
{
    return @[MP42MetadataKeyName, MP42MetadataKeyArtist, MP42MetadataKeyAlbum, MP42MetadataKeyReleaseDate, MP42MetadataKeyTrackNumber, MP42MetadataKeyDiscNumber, MP42MetadataKeyTVShow, MP42MetadataKeyTVEpisodeNumber, MP42MetadataKeyTVNetwork, MP42MetadataKeyTVEpisodeID, MP42MetadataKeyTVSeason, MP42MetadataKeyUserGenre, MP42MetadataKeyDescription, MP42MetadataKeyLongDescription];
}

- (NSArray *)movieSet
{
    return @[MP42MetadataKeyName, MP42MetadataKeyArtist, MP42MetadataKeyAlbum, MP42MetadataKeyUserGenre, MP42MetadataKeyReleaseDate, MP42MetadataKeyTrackNumber, MP42MetadataKeyDiscNumber, MP42MetadataKeyCast, MP42MetadataKeyDirector, MP42MetadataKeyScreenwriters, MP42MetadataKeyUserGenre, MP42MetadataKeyDescription, MP42MetadataKeyLongDescription, MP42MetadataKeyRating, MP42MetadataKeyCopyright];
}

#pragma mark - Presets management

- (IBAction)addMetadataSet:(id)sender
{
    NSArray *identifiers = nil;
    NSMutableArray *itemsToBeAdded = [NSMutableArray array];

    if ([sender tag] == 0) {
        identifiers = [self allSet];
    }
    else if ([sender tag] == 1) {
        identifiers = [self movieSet];
        MP42MetadataItem *mediaKind = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyMediaKind
                                                                             value:@9
                                                                          dataType:MP42MetadataItemDataTypeInteger
                                                               extendedLanguageTag:nil];
        [itemsToBeAdded addObject:mediaKind];
    }
    else if ([sender tag] == 2) {
        identifiers = [self tvShowSet];
        MP42MetadataItem *mediaKind = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyMediaKind
                                                                             value:@10
                                                                          dataType:MP42MetadataItemDataTypeInteger
                                                               extendedLanguageTag:nil];
        [itemsToBeAdded addObject:mediaKind];
    }

    NSMutableSet *existingIdentifiers = [NSMutableSet set];

    for (MP42MetadataItem *item in self.tags) {
        [existingIdentifiers addObject:item.identifier];
    }

    for (NSString *identifier in identifiers) {
        if (![existingIdentifiers containsObject:identifier]) {
            MP42MetadataItem *item = [MP42MetadataItem metadataItemWithIdentifier:identifier
                                                                            value:@""
                                                                         dataType:MP42MetadataItemDataTypeUnspecified
                                                              extendedLanguageTag:nil];
            [itemsToBeAdded addObject:item];
        }
    }

    [self addMetadataItems:itemsToBeAdded];
}

- (void)applySet:(id)sender
{
    NSInteger tag = [sender tag];
    MP42Metadata *preset = [SBPresetManager sharedManager].presets[tag];

    MP42MetadataItemDataType dataTypes = MP42MetadataItemDataTypeString | MP42MetadataItemDataTypeStringArray |
                                         MP42MetadataItemDataTypeBool | MP42MetadataItemDataTypeInteger |
                                         MP42MetadataItemDataTypeIntegerArray | MP42MetadataItemDataTypeDate;
    NSArray<MP42MetadataItem *> *items = [preset metadataItemsFilteredByDataType:dataTypes];

    if (items) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (MP42MetadataItem *item in items) {
            [identifiers addObject:item.identifier];
        }
        [self removeMetadataItems:[self.metadata metadataItemsFilteredByIdentifiers:identifiers]];
        [self addMetadataItems:items];
    }

    items = [preset metadataItemsFilteredByIdentifier:MP42MetadataKeyCoverArt];

    if (items) {
        [self removeMetadataCoverArtItems:[self.metadata metadataItemsFilteredByIdentifier:MP42MetadataKeyCoverArt]];
        [self addMetadataCoverArtItems:items];
    }
}

- (void)updateSetsMenu:(id)sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    NSMenu *setListMenu = self.setsPopUp.menu;

    while (setListMenu.numberOfItems > 1) {
        [setListMenu removeItemAtIndex: 1];
    }
    
    NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Save Set", @"Set menu")
                                                     action:@selector(showSaveSet:) keyEquivalent:@""];
    newItem.target = self;
    [setListMenu addItem:newItem];

    [setListMenu addItem:[NSMenuItem separatorItem]];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"All", @"Set menu All set")
                                         action:@selector(addMetadataSet:) keyEquivalent:@""];
    newItem.target = self;
    newItem.tag = 0;
    [setListMenu addItem:newItem];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Movie", @"Set menu Movie set")
                                         action:@selector(addMetadataSet:) keyEquivalent:@""];
    newItem.target = self;
    newItem.tag = 1;
    [setListMenu addItem:newItem];

    newItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"TV Show", @"Set menu TV Show Set")
                                         action:@selector(addMetadataSet:) keyEquivalent:@""];
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

- (IBAction)showSaveSet:(id)sender
{
    [self.view.window beginCriticalSheet:self.saveSetWindow completionHandler:NULL];
}

- (IBAction)saveSet:(id)sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];

    self.metadata.presetName = self.saveSetName.stringValue;
    [presetManager newSetFromExistingMetadata: self.metadata];

    [self.view.window endSheet:self.saveSetWindow];
}

- (IBAction)closeSaveSheet:(id)sender
{
    [self.view.window endSheet:self.saveSetWindow];
}

#pragma mark - TableView data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return self.tags.count;
}

- (NSTableCellView *)boolCellWithState:(BOOL)state tableView:(NSTableView *)tableView
{
    SBCheckBoxCellView *cell = [tableView makeViewWithIdentifier:@"BoolCell" owner:self];
    cell.checkboxButton.state = state;
    return cell;
}

- (NSTableCellView *)textCellWithString:(NSString *)text tableView:(NSTableView *)tableView
{
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"TextCell" owner:self];
    cell.textField.stringValue = text ? text : @"";
    return cell;
}

- (NSTableCellView *)popUpCellWithContents:(NSArray<NSString *> *)contents index:(NSInteger)index tableView:(NSTableView *)tableView
{
    SBPopUpCellView *popUpCell =  [tableView makeViewWithIdentifier:@"PopUpCell" owner:self];
    [popUpCell.popUpButton removeAllItems];
    for (NSString *title in contents) {
        [popUpCell.popUpButton.menu addItem:[[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""]];
    }
    [popUpCell.popUpButton selectItemAtIndex:index];
    return popUpCell;
}

- (NSTableCellView *)popUpCellWithArrayContents:(NSArray<NSArray *> *)contents value:(NSNumber *)value tableView:(NSTableView *)tableView
{
    NSInteger index = 0;
    SBPopUpCellView *popUpCell =  [tableView makeViewWithIdentifier:@"PopUpCell" owner:self];
    [popUpCell.popUpButton removeAllItems];
    for (NSArray *array in contents) {
        [popUpCell.popUpButton.menu addItem:[[NSMenuItem alloc] initWithTitle:array.firstObject action:NULL keyEquivalent:@""]];
        if ([array[1] isEqualToNumber:value]) {
            [popUpCell.popUpButton selectItemAtIndex:index];
        }
        index++;
    }
    return popUpCell;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *cell = nil;
    MP42MetadataItem *item = [self.tags objectAtIndex:row];

    if ([tableColumn.identifier isEqualToString:@"key"]) {
        cell = [tableView makeViewWithIdentifier:@"NameTextCell" owner:self];
        cell.textField.stringValue = item.identifier;
    }
    else if ([tableColumn.identifier isEqualToString:@"value"]) {
        switch (item.dataType) {
            case MP42MetadataItemDataTypeString:
            {
                if ([item.identifier isEqualToString:MP42MetadataKeyUserGenre]) {
                    cell = [self textCellWithString:item.stringValue tableView:tableView];
                    //cell = [tableView makeViewWithIdentifier:@"ComboCell" owner:self];
                    break;
                 }
                 else if ([item.identifier isEqualToString:MP42MetadataKeyRating]) {
                     NSInteger index = [[MP42Ratings defaultManager] ratingIndexForiTunesCode:item.stringValue];
                     cell = [self popUpCellWithContents:self.ratings index:index tableView:tableView];
                     break;
                 }
            }
            case MP42MetadataItemDataTypeStringArray:
            case MP42MetadataItemDataTypeInteger:
            {
                if ([item.identifier isEqualToString:MP42MetadataKeyContentRating]) {
                    cell = [self popUpCellWithArrayContents:_contentRatings value:item.numberValue tableView:tableView];
                    break;
                }
                else if ([item.identifier isEqualToString:MP42MetadataKeyMediaKind]) {
                    cell = [self popUpCellWithArrayContents:_mediaKinds value:item.numberValue tableView:tableView];
                    break;
                }
                else if ([item.identifier isEqualToString:MP42MetadataKeyHDVideo]) {
                    cell = [self popUpCellWithArrayContents:_hdVideo value:item.numberValue tableView:tableView];
                    break;
                }
            }
            case MP42MetadataItemDataTypeIntegerArray:
            case MP42MetadataItemDataTypeDate:
                cell = [self textCellWithString:item.stringValue tableView:tableView];
                break;
            case MP42MetadataItemDataTypeBool:
                cell = [self boolCellWithState:item.numberValue.boolValue tableView:tableView];
                break;
            default:
                break;
        }
    }

    return cell;
}

#pragma mark - TableView editing

- (NSArray<NSString *> *)stringsArrayFromString:(NSString *)string
{
    NSString *splitElements  = @",\\s*+";
    NSArray *stringArray = [string MP42_componentsSeparatedByRegex:splitElements];

    NSMutableArray<NSString *> *arrayElements = [NSMutableArray array];

    for (NSString *element in stringArray) {
        [arrayElements addObject:element];
    }

    return arrayElements;
}

- (NSArray<NSNumber *> *)numbersArrayFromString:(NSString *)string
{
    int index = 0, count = 0;
    char separator[3];

    sscanf(string.UTF8String,"%u%[/- ]%u", &index, separator, &count);

    return @[@(index), @(count)];
}

- (IBAction)setMetadataStringValue:(NSTextField *)sender
{
    NSInteger row = [self.metadataTableView rowForView:sender];
    MP42MetadataItem *item = self.tags[row];

    if ([sender.stringValue isEqualToString:item.stringValue]) {
        return;
    }

    id value;
    switch (item.dataType) {
        case MP42MetadataItemDataTypeString:
            value = sender.stringValue;
            break;
        case MP42MetadataItemDataTypeStringArray:
            value = [self stringsArrayFromString:sender.stringValue];
            break;
        case MP42MetadataItemDataTypeInteger:
            value = @(sender.integerValue);
            break;
        case MP42MetadataItemDataTypeIntegerArray:
            value = [self numbersArrayFromString:sender.stringValue];
            break;
        case MP42MetadataItemDataTypeDate:
            value = [NSDate dateWithString:sender.stringValue];
            break;
        case MP42MetadataItemDataTypeBool:
            value = @((BOOL)sender.integerValue);
            break;

        default:
            break;
    }

    MP42MetadataItem *editedItem = [MP42MetadataItem metadataItemWithIdentifier:item.identifier
                                                                          value:value
                                                                       dataType:item.dataType
                                                            extendedLanguageTag:item.extendedLanguageTag];
    [self replaceMetadataItem:item withItem:editedItem];
}

- (IBAction)setMetadataBoolValue:(NSButton *)sender {
    NSInteger row = [self.metadataTableView rowForView:sender];
    MP42MetadataItem *item = self.tags[row];

    MP42MetadataItem *editedItem = [MP42MetadataItem metadataItemWithIdentifier:item.identifier
                                                                          value:@(sender.state)
                                                                       dataType:item.dataType
                                                            extendedLanguageTag:item.extendedLanguageTag];
    [self replaceMetadataItem:item withItem:editedItem];
}

- (IBAction)setMetadataIntValue:(NSPopUpButton *)sender
{
    NSInteger row = [self.metadataTableView rowForView:sender];
    MP42MetadataItem *item = self.tags[row];

    NSInteger index = sender.indexOfSelectedItem;

    id value;
    switch (item.dataType) {
        case MP42MetadataItemDataTypeString:
            if ([item.identifier isEqualToString:MP42MetadataKeyRating]) {
                NSArray<NSString *> *ratings = [[MP42Ratings defaultManager] iTunesCodes];
                value = ratings[index];
            }
            break;
        case MP42MetadataItemDataTypeInteger:
            if ([item.identifier isEqualToString:MP42MetadataKeyContentRating]) {
                value = _contentRatings[index][1];
            }
            else if ([item.identifier isEqualToString:MP42MetadataKeyMediaKind]) {
                value = _mediaKinds[index][1];
            }
            else if ([item.identifier isEqualToString:MP42MetadataKeyHDVideo]) {
                value = _hdVideo[index][1];
            }
            break;
        default:
            break;
    }

    MP42MetadataItem *editedItem = [MP42MetadataItem metadataItemWithIdentifier:item.identifier
                                                                          value:value
                                                                       dataType:item.dataType
                                                            extendedLanguageTag:item.extendedLanguageTag];
    [self replaceMetadataItem:item withItem:editedItem];
}

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
    NSIndexSet *rowIndexes = tableView.selectedRowIndexes;
    NSArray<MP42MetadataItem *> *items = [self.tags objectsAtIndexes:rowIndexes];

    NSMutableString *string = [NSMutableString string];

    for (MP42MetadataItem *item in items) {
        [string appendFormat:@"%@: %@\n", item.identifier, item.stringValue];
    }

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:@[SublerMetadataPBoardType, NSStringPboardType] owner:nil];
    [pb setString:string forType: NSStringPboardType];
    [pb setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:SublerMetadataPBoardType];
}

- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
{
    [self _copySelectionFromTableView:tableView];
    [self removeTag:tableView];
}

- (void)_pasteToTableView:(NSTableView *)tableView
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSData *archivedData = [pb dataForType:SublerMetadataPBoardType];
    NSArray<MP42MetadataItem *> *data = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];

    [self addMetadataItems:data];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
    return @"";
}

- (NSTableCellView *)dummyCell
{
    if (!_dummyCell) {
        _dummyCell = [self.metadataTableView makeViewWithIdentifier:@"TextCellForSizing" owner: self];
        _dummyCellWidth = [NSLayoutConstraint constraintWithItem:_dummyCell
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                                 multiplier:1.0f
                                                                   constant:500];
        [_dummyCell addConstraint:_dummyCellWidth];
    }
    return _dummyCell;
}

#define MIN_HEIGHT 14.0f

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
{
    MP42MetadataItem *item = self.tags[row];
    BOOL calculateHeight = NO;
    CGFloat height = 0;

    // Height calculation is slow, so calculate only if stricly necessary.
    switch (item.dataType) {
        case MP42MetadataItemDataTypeString:
        case MP42MetadataItemDataTypeStringArray:
        case MP42MetadataItemDataTypeDate:
            calculateHeight = YES;
            break;
        default:
            calculateHeight = NO;
            break;
    }

    if (calculateHeight && !(height = self.rowHeights[item.identifier].floatValue)) {
        // Set the width in the dummy cell, and let autolayout calculate the height.
        self.dummyCellWidth.constant = self.columnWidth;
        self.dummyCell.textField.preferredMaxLayoutWidth = self.columnWidth;
        NSString *stringValue = item.stringValue;
        if (stringValue) {
            self.dummyCell.textField.stringValue = item.stringValue;
        }

        height = self.dummyCell.fittingSize.height;
        self.rowHeights[item.identifier] = @(height);
    }

    return (height < MIN_HEIGHT) ? MIN_HEIGHT : height;
}

- (void)tableViewColumnDidResize:(NSNotification *)notification
{
    self.previousColumnWidth = self.columnWidth;
    self.columnWidth = self.column.width;

    if (self.columnWidth > self.previousColumnWidth) {
        NSMutableArray<NSString *> *keysToRemove = [NSMutableArray array];
        [self.rowHeights enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj.floatValue > MIN_HEIGHT) {
                [keysToRemove addObject:key];
            }
        }];
        [self.rowHeights removeObjectsForKeys:keysToRemove];
    }
    else {
        [self.rowHeights removeAllObjects];
    }

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0];
    [self.metadataTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, self.metadataTableView.numberOfRows)]];
    [NSAnimationContext endGrouping];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    BOOL enabled = self.metadataTableView.selectedRow != -1 ? YES : NO;
    self.removeTagButton.enabled = enabled;
}

#pragma mark - Cover Art

- (void)updateCoverArtArray
{
    self.artworks = [[self.metadata metadataItemsFilteredByIdentifier:MP42MetadataKeyCoverArt] mutableCopy];
}

- (void)addMetadataCoverArtItems:(NSArray<MP42MetadataItem *> *)items
{
    for (MP42MetadataItem *item in items) {
        [self.metadata addMetadataItem:item];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] removeMetadataCoverArtItems:items];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Insert", @"Undo cover art insert.")];
    }

    [self updateCoverArtArray];
    [self.artworksView reloadData];
}

- (void)removeMetadataCoverArtItems:(NSArray<MP42MetadataItem *> *)items
{
    for (MP42MetadataItem *item in items) {
        [self.metadata removeMetadataItem:item];
    }

    NSUndoManager *undo = self.view.undoManager;
    [[undo prepareWithInvocationTarget:self] addMetadataCoverArtItems:items];

    if (!undo.undoing) {
        [undo setActionName:NSLocalizedString(@"Delete", @"Undo cover art delete")];
    }

    [self updateCoverArtArray];
    [self.artworksView reloadData];
}

- (IBAction)removeArtwork:(id)sender
{
    [self imageBrowser:self.artworksView removeItemsAtIndexes:[self.artworksView selectionIndexes]];
    [self.artworksView reloadData];
}

- (BOOL)addArtworks:(NSArray *)items
{
    NSMutableArray<MP42MetadataItem *> *itemsToAdd = [NSMutableArray array];

    for (id item in items) {
        MP42Image *artwork = nil;

        if ([item isKindOfClass:[NSURL class]]) {
            NSString *type;
            if ([item getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL]) {
                if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)@"public.jpeg")) {
                    artwork = [[MP42Image alloc] initWithData:[NSData dataWithContentsOfURL:item] type:MP42_ART_JPEG];
                } else {
                    NSImage *artworkImage = [[NSImage alloc] initWithContentsOfURL:item];
                    artwork = [[MP42Image alloc] initWithImage:artworkImage];
                }
            }
        }
        else if ([item isKindOfClass:[NSImage class]]) {
            artwork = [[MP42Image alloc] initWithImage:item];
        }
        else if ([item isKindOfClass:[MP42Image class]]) {
            artwork = item;
        }

        if (artwork) {
            MP42MetadataItem *metadataItem = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyCoverArt
                                                                                    value:artwork
                                                                                 dataType:MP42MetadataItemDataTypeImage
                                                                      extendedLanguageTag:nil];
            [itemsToAdd addObject:metadataItem];
        }
    }

    if (itemsToAdd.count) {
        [self addMetadataCoverArtItems:itemsToAdd];
    }

    return itemsToAdd.count;
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
            [self addArtworks:panel.URLs];
        }
    }];
}

#pragma mark - IKImageBrowserDataSource

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return self.artworks.count;
}

- (id)imageBrowser:(IKImageBrowserView *)aBrowser itemAtIndex:(NSUInteger)index
{
    return self.artworks[index].imageValue;
}

- (BOOL)imageBrowser:(IKImageBrowserView *)aBrowser moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex
{
    destinationIndex -= [indexes countOfIndexesInRange:NSMakeRange(0, destinationIndex)];;

    NSArray *objects = [self.artworks objectsAtIndexes:indexes];
    [self.artworks removeObjectsAtIndexes:indexes];

    for (id object in objects.reverseObjectEnumerator) {
        [self.artworks insertObject:object atIndex:destinationIndex];
    }

    for (MP42MetadataItem *item in self.artworks) {
        [self.metadata removeMetadataItem:item];
    }
    for (MP42MetadataItem *item in self.artworks) {
        [self.metadata addMetadataItem:item];
    }

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];

    return YES;
}

- (NSUInteger)imageBrowser:(IKImageBrowserView *)aBrowser writeItemsAtIndexes:(NSIndexSet *)itemIndexes toPasteboard:(NSPasteboard *)pasteboard
{
    [pasteboard declareTypes:@[SublerCoverArtPBoardType, NSPasteboardTypePNG] owner:nil];

    for (MP42MetadataItem *item in [self.artworks objectsAtIndexes:itemIndexes]) {
        MP42Image *image = item.imageValue;
        if (image) {
            NSArray *representations = image.image.representations;
            if (representations) {
                NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations usingType:NSBitmapImageFileTypePNG properties:@{}];
                [pasteboard setData:bitmapData forType:NSPasteboardTypePNG];
            }
            [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:image] forType:SublerCoverArtPBoardType];
        }
    }

    return itemIndexes.count;
}

- (void)_pasteToImageBrowserView:(IKImageBrowserView *)ImageBrowserView
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *items = nil;

    NSData *archivedImageData = [pasteboard dataForType:SublerCoverArtPBoardType];
    if (archivedImageData) {
        MP42Image *image = [NSKeyedUnarchiver unarchiveObjectWithData:archivedImageData];
        if (image) {
            items = @[image];
        }
    }
    else {
        NSArray *classes = @[[NSURL class], [NSImage class]];
        NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes]};
        items = [pasteboard readObjectsForClasses:classes options:options];
    }

    [self addArtworks:items];
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser removeItemsAtIndexes:(NSIndexSet *)indexes
{
    NSArray<MP42MetadataItem *> *items = [self.artworks objectsAtIndexes:indexes];
    [self removeMetadataCoverArtItems:items];
}

#pragma mark - IKImageBrowserDelegate

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)aBrowser
{
    NSIndexSet *rowIndexes = [aBrowser selectionIndexes];

    if (rowIndexes.count) {
        [self.removeArtworkButton setEnabled:YES];
    }
    else {
        [self.removeArtworkButton setEnabled:NO];
    }
}

- (IBAction)zoomSliderDidChange:(id)sender
{
    [self.artworksView setZoomValue:[sender floatValue]];
}

#pragma mark - Cover Art drag & drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];

    NSArray *classes = @[[NSURL class], [NSImage class]];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes]};
    NSArray *draggedItems = [pasteboard readObjectsForClasses:classes options:options];

    return [self addArtworks:draggedItems];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {}

@end
