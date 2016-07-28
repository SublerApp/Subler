//
//  SBMetadataPrefsViewController.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataPrefsViewController.h"

#import "SBMetadataDefaultItem.h"
#import <MP42Foundation/MP42Metadata.h>

@interface SBMetadataPrefsViewController () <NSTableViewDelegate>

@property (nonatomic, weak) IBOutlet NSTokenField *builtInTokenField;
@property (nonatomic, weak) IBOutlet NSPopUpButton *addMetadataPopUpButton;
@property (nonatomic, weak) IBOutlet NSButton *removeMetadataButton;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;

@property (nonatomic, readonly) NSArray<NSString *> *movieTokens;
@property (nonatomic, readonly) NSArray<NSString *> *tvShowTokens;

@property (nonatomic, readwrite) NSArray<NSString *> *currentTokens;

@property (nonatomic) NSArray<NSString *> *matches;

@property (nonatomic, readwrite) NSMutableArray<SBMetadataDefaultItem *> *items;
@property (nonatomic, strong) IBOutlet NSArrayController *itemsController;

@end

@implementation SBMetadataPrefsViewController

- (void)loadView
{
    [super loadView];

    for (NSString *tag in [MP42Metadata writableMetadata]) {
        [self.addMetadataPopUpButton addItemWithTitle:tag];
    }

    _items = [[NSMutableArray alloc] init];

    NSArray<NSString *> *context = [MP42Metadata availableMetadata];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"key"
                                                                   ascending:YES
                                                                  comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                                                                      NSInteger right = [context indexOfObject:obj2];
                                                                      NSInteger left = [context indexOfObject:obj1];
                                                                      return (right < left) ? NSOrderedDescending : NSOrderedAscending;
    }];

    [self.itemsController setSortDescriptors:@[sortDescriptor]];
    [self.itemsController addObjects:[self movieDefaults]];
    self.itemsController.selectionIndexes = [NSIndexSet indexSet];

    self.currentTokens = self.movieTokens;

    [self.builtInTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"%%"]];
    self.builtInTokenField.stringValue = [self.currentTokens componentsJoinedByString:@"%%"];
}

#pragma mark - Defaults

- (NSArray<NSString *> *)movieTokens
{
    return @[@"{Title}",
             @"{Composer}",
             @"{Genre}",
             @"{Release Date}",
             @"{Description}",
             @"{Long Description}",
             @"{Rating}",
             @"{Studio}",
             @"{Cast}",
             @"{Director}",
             @"{Producers}",
             @"{Screenwriters}",
             @"{Copyright}",
             @"{contentID}",
             @"{iTunes Country}",
             @"{Executive Producer}"];
}

- (NSArray<NSString *> *)tvShowTokens
{
    return @[@"{Episode Name}",
             @"{Series Name}",
             @"{Composer}",
             @"{Genre}",
             @"{Release Date}",

             @"{Track #}",
             @"{Disk #}",
             @"{TV Show}",
             @"{TV Episode #}",
             @"{TV Network}",
             @"{TV Episode ID}",
             @"{TV Season}",

             @"{Description}",
             @"{Long Description}",
             @"{Series Description}",

             @"{Rating}",
             @"{Studio}",
             @"{Cast}",
             @"{Director}",
             @"{Producers}",
             @"{Screenwriters}",
             @"{Copyright}",
             @"{contentID}",
             @"{artistID}",
             @"{playlistID}",
             @"{iTunes Country}",
             @"{Executive Producer}"];
}

- (NSArray<SBMetadataDefaultItem *> *)movieDefaults
{
    return @[
             [SBMetadataDefaultItem itemWithKey:@"Name"               value:@[@"{Title}"]],
             [SBMetadataDefaultItem itemWithKey:@"Artist"             value:@[@"{Director}"]],
             [SBMetadataDefaultItem itemWithKey:@"Composer"           value:@[@"{Composer}"]],
             [SBMetadataDefaultItem itemWithKey:@"Genre"              value:@[@"{Genre}"]],
             [SBMetadataDefaultItem itemWithKey:@"Release Date"       value:@[@"{Release Date}"]],
             [SBMetadataDefaultItem itemWithKey:@"Description"        value:@[@"{Description}"]],
             [SBMetadataDefaultItem itemWithKey:@"Long Description"   value:@[@"{Long Description}"]],
             [SBMetadataDefaultItem itemWithKey:@"Rating"             value:@[@"{Rating}"]],
             [SBMetadataDefaultItem itemWithKey:@"Studio"             value:@[@"{Studio}"]],
             [SBMetadataDefaultItem itemWithKey:@"Cast"               value:@[@"{Cast}"]],
             [SBMetadataDefaultItem itemWithKey:@"Director"           value:@[@"{Director}"]],
             [SBMetadataDefaultItem itemWithKey:@"Producers"          value:@[@"{Producers}"]],
             [SBMetadataDefaultItem itemWithKey:@"Screenwriters"      value:@[@"{Screenwriters}"]],
             [SBMetadataDefaultItem itemWithKey:@"Copyright"          value:@[@"{Copyright}"]],
             [SBMetadataDefaultItem itemWithKey:@"contentID"          value:@[@"{contentID}"]],
             [SBMetadataDefaultItem itemWithKey:@"iTunes Country"     value:@[@"{iTunes Country}"]],
             [SBMetadataDefaultItem itemWithKey:@"Executive Producer" value:@[@"{Executive Producer}"]],
             ];
}

- (NSArray<SBMetadataDefaultItem *> *)tvShowDefaults
{
    return @[
             [SBMetadataDefaultItem itemWithKey:@"Name"         value:@[@"{Episode Name}"]],
             [SBMetadataDefaultItem itemWithKey:@"Artist"       value:@[@"{Series Name}"]],
             [SBMetadataDefaultItem itemWithKey:@"Album Artist" value:@[@"{Series Name}"]],
             [SBMetadataDefaultItem itemWithKey:@"Album"        value:@[@"{Series Name}"]],
             [SBMetadataDefaultItem itemWithKey:@"Composer"     value:@[@"{Composer}"]],
             [SBMetadataDefaultItem itemWithKey:@"Genre"        value:@[@"{Genre}"]],
             [SBMetadataDefaultItem itemWithKey:@"Release Date" value:@[@"{Release Date}"]],

             [SBMetadataDefaultItem itemWithKey:@"Track #"          value:@[@"{Track #}"]],
             [SBMetadataDefaultItem itemWithKey:@"Disk #"           value:@[@"{Disk #}"]],
             [SBMetadataDefaultItem itemWithKey:@"TV Show"          value:@[@"{TV Show}"]],
             [SBMetadataDefaultItem itemWithKey:@"TV Episode #"     value:@[@"{TV Episode #}"]],
             [SBMetadataDefaultItem itemWithKey:@"TV Network"       value:@[@"{TV Network}"]],
             [SBMetadataDefaultItem itemWithKey:@"TV Episode ID"    value:@[@"{TV Episode ID}"]],
             [SBMetadataDefaultItem itemWithKey:@"TV Season"        value:@[@"{TV Season}"]],

             [SBMetadataDefaultItem itemWithKey:@"Description"          value:@[@"{Description}"]],
             [SBMetadataDefaultItem itemWithKey:@"Long Description"     value:@[@"{Long Description}"]],
             [SBMetadataDefaultItem itemWithKey:@"Series Description"   value:@[@"{Series Description}"]],

             [SBMetadataDefaultItem itemWithKey:@"Rating"               value:@[@"{Rating}"]],
             [SBMetadataDefaultItem itemWithKey:@"Studio"               value:@[@"{Studio}"]],
             [SBMetadataDefaultItem itemWithKey:@"Cast"                 value:@[@"{Cast}"]],
             [SBMetadataDefaultItem itemWithKey:@"Director"             value:@[@"{Director}"]],
             [SBMetadataDefaultItem itemWithKey:@"Producers"            value:@[@"{Producers}"]],
             [SBMetadataDefaultItem itemWithKey:@"Screenwriters"        value:@[@"{Screenwriters}"]],
             [SBMetadataDefaultItem itemWithKey:@"Executive Producer"   value:@[@"{Executive Producer}"]],
             [SBMetadataDefaultItem itemWithKey:@"Copyright"            value:@[@"{Copyright}"]],
             [SBMetadataDefaultItem itemWithKey:@"contentID"            value:@[@"{contentID}"]],
             [SBMetadataDefaultItem itemWithKey:@"artistID"             value:@[@"{artistID}"]],
             [SBMetadataDefaultItem itemWithKey:@"playlistID"           value:@[@"{playlistID}"]],
             [SBMetadataDefaultItem itemWithKey:@"iTunes Country"       value:@[@"{iTunes Country}"]],
             [SBMetadataDefaultItem itemWithKey:@"Sort Album"           value:@[@"{Series Name}", @", Season ", @"{TV Season}"]],
             ];
}

- (IBAction)addMetadataItem:(id)sender
{
    NSString *key = [sender selectedItem].title;
    if (key.length) {
        SBMetadataDefaultItem *item = [[SBMetadataDefaultItem alloc] initWithKey:key value:@[@""]];
        [self.itemsController addObject:item];
        [self.itemsController rearrangeObjects];
    }
}

#pragma mark - Type selector

- (IBAction)setType:(NSPopUpButton *)sender
{
    if (sender.selectedTag) {
        self.currentTokens = self.tvShowTokens;
        self.items = [[self tvShowDefaults] mutableCopy];
    }
    else {
        self.currentTokens = self.movieTokens;
        self.items = [[self movieDefaults] mutableCopy];
    }
    self.itemsController.selectionIndexes = [NSIndexSet indexSet];
    self.builtInTokenField.stringValue = [self.currentTokens componentsJoinedByString:@"%%"];
}

#pragma mark - Table View

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    NSTableCellView *view = [rowView viewAtColumn:1];
    NSTokenField *tokenField = view.subviews.firstObject;
    if ([tokenField isKindOfClass:[NSTokenField class]]) {
        tokenField.tokenizingCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"%%"];
    }
}

#pragma mark - Format Token Field Delegate

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0) {
        return [(NSString *)representedObject substringWithRange:NSMakeRange(1, [(NSString*)representedObject length]-2)];
    }

    return representedObject;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0) {
        return NSRoundedTokenStyle;
    }
    else {
        return NSPlainTextTokenStyle;
    }
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
    return editingString;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex
    indexOfSelectedItem:(NSInteger *)selectedIndex
{
    self.matches = [self.currentTokens filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", substring]];
    return self.matches;
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0)  {
        return [NSString stringWithFormat:@"%%%@%%", representedObject];
    }
    else {
        return representedObject;
    }
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    return tokens;
}

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard
{
    NSString *format = [objects componentsJoinedByString:@"%%"];
    [pboard setString:format forType:NSPasteboardTypeString];

    return YES;
}

@end
