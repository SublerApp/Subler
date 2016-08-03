//
//  SBMetadataPrefsViewController.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataPrefsViewController.h"

#import "SBMetadataResultMap.h"
#import <MP42Foundation/MP42Metadata.h>

static void *SBMetadataPrefsViewControllerContex = &SBMetadataPrefsViewControllerContex;

@interface SBMetadataPrefsViewController () <NSTableViewDelegate, NSTokenFieldDelegate, NSTextFieldDelegate>

@property (nonatomic, weak) IBOutlet NSTokenField *builtInTokenField;
@property (nonatomic, weak) IBOutlet NSPopUpButton *addMetadataPopUpButton;
@property (nonatomic, weak) IBOutlet NSButton *removeMetadataButton;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;

@property (nonatomic, readwrite) NSArray<NSString *> *types;
@property (nonatomic) IBOutlet NSArrayController *typesController;
@property (nonatomic, weak) IBOutlet NSTableView *typesTableView;

@property (nonatomic, readonly) SBMetadataResultMap *movieMap;
@property (nonatomic, readonly) SBMetadataResultMap *tvShowMap;

@property (nonatomic) SBMetadataResultMap *map;
@property (nonatomic) IBOutlet NSArrayController *itemsController;

@property (nonatomic) NSArray<NSString *> *currentTokens;
@property (nonatomic) NSArray<NSString *> *matches;

@end

@implementation SBMetadataPrefsViewController

- (NSString *)nibName
{
    return @"SBMetadataPrefsViewController";
}

- (void)loadView
{
    [super loadView];

    [self.builtInTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"%"]];

    for (NSString *tag in [MP42Metadata writableMetadata]) {
        [self.addMetadataPopUpButton addItemWithTitle:tag];
    }

    // Load data from preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    SBMetadataResultMap *savedMovieMap = [defaults SB_resultMapForKey:@"SBMetadataMovieResultMap"];
    SBMetadataResultMap *savedTvShowMap = [defaults SB_resultMapForKey:@"SBMetadataTvShowResultMap"];

    _movieMap = savedMovieMap ? savedMovieMap :[SBMetadataResultMap movieDefaultMap];
    _tvShowMap = savedTvShowMap ? savedTvShowMap :[SBMetadataResultMap tvShowDefaultMap];

    // Set up the sort descriptor
    NSArray<NSString *> *context = [MP42Metadata availableMetadata];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"key"
                                                                   ascending:YES
                                                                  comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                                                                      NSInteger right = [context indexOfObject:obj2];
                                                                      NSInteger left = [context indexOfObject:obj1];
                                                                      return (right < left) ? NSOrderedDescending : NSOrderedAscending;
    }];

    [self.itemsController setSortDescriptors:@[sortDescriptor]];
    self.itemsController.selectionIndexes = [NSIndexSet indexSet];


    // Set types
    self.types = @[NSLocalizedString(@"Movie", nil), NSLocalizedString(@"TV Show", nil)];
    [self addObserver:self forKeyPath:@"self.typesController.selectionIndex"
              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
              context:SBMetadataPrefsViewControllerContex];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SBMetadataPrefsViewControllerContex) {
        if (self.typesController.selectionIndex) {
            self.currentTokens = [SBMetadataResultMap tvShowKeys];
            self.map = self.tvShowMap;
        }
        else {
            self.currentTokens = [SBMetadataResultMap movieKeys];
            self.map = self.movieMap;
        }
        self.itemsController.selectionIndexes = [NSIndexSet indexSet];
        self.builtInTokenField.stringValue = [self.currentTokens componentsJoinedByString:@"%"];

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)save
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults SB_setResultMap:self.movieMap forKey:@"SBMetadataMovieResultMap"];
    [defaults SB_setResultMap:self.tvShowMap forKey:@"SBMetadataTvShowResultMap"];
}

- (IBAction)addMetadataItem:(id)sender
{
    NSString *key = [sender selectedItem].title;
    if (key.length) {
        SBMetadataResultMapItem *item = [[SBMetadataResultMapItem alloc] initWithKey:key value:@[@""]];
        [self.itemsController addObject:item];
        [self.itemsController rearrangeObjects];
    }
    [self save];
}

- (IBAction)removeMetadata:(id)sender
{
    [self.itemsController removeObjects:self.itemsController.selectedObjects];
    [self save];
}

#pragma mark - Table View

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if (tableView == self.tableView) {
        NSTableCellView *view = [rowView viewAtColumn:1];
        NSTokenField *tokenField = view.subviews.firstObject;
        if ([tokenField isKindOfClass:[NSTokenField class]]) {
            tokenField.tokenizingCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"%"];
        }
    }
}

#pragma mark - Format Token Field Delegate

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    [self save];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0) {
        return [(NSString *)representedObject substringWithRange:NSMakeRange(1, [(NSString *)representedObject length]-2)];
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
    NSString *format = [objects componentsJoinedByString:@"%"];
    [pboard setString:format forType:NSPasteboardTypeString];

    return YES;
}

@end
