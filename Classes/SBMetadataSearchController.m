//
//  MetadataImportController.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Languages.h>
#import <MP42Foundation/MP42Metadata.h>

#import "SBMetadataSearchController.h"
#import "SBTableView.h"
#import "SBArtworkSelector.h"
#import "SBDocument.h"
#import "SBMetadataImporter.h"

@interface SBMetadataSearchController () <NSTableViewDelegate, NSComboBoxDelegate, SBArtworkSelectorDelegate>
{
@private
    id <SBMetadataSearchControllerDelegate> delegate;

    NSString    *_searchString;

    NSDictionary                 *detailBoldAttr;

    IBOutlet NSTabView           *searchMode;

    IBOutlet NSTextField         *movieName;
    IBOutlet NSPopUpButton       *movieLanguage;
    IBOutlet NSPopUpButton       *movieMetadataProvider;

    IBOutlet NSComboBox          *tvSeriesName;
    IBOutlet NSTextField         *tvSeasonNum;
    IBOutlet NSTextField         *tvEpisodeNum;
    IBOutlet NSPopUpButton       *tvLanguage;
    IBOutlet NSPopUpButton       *tvMetadataProvider;

    IBOutlet NSButton            *searchButton;

    IBOutlet NSTableView         *resultsTable;
    IBOutlet SBTableView         *metadataTable;

    IBOutlet NSButton            *addButton;

    SBArtworkSelector            *artworkSelectorWindow;

    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField         *progressText;
}

@property (nonatomic, weak) IBOutlet NSTabViewItem *movieTab;
@property (nonatomic, weak) IBOutlet NSTabViewItem *tvEpisodeTab;

@property (nonatomic, readwrite, strong) SBMetadataImporter *currentSearcher;
@property (nonatomic, readwrite, strong) NSArray<SBMetadataResult *> *resultsArray;

@property (nonatomic, readwrite, strong) SBMetadataResult *selectedResult;

@property (nonatomic, readwrite, strong) NSDictionary *selectedResultTags;
@property (nonatomic, readwrite, strong) NSArray<NSString *> *selectedResultTagsArray;

@property (nonatomic, readwrite, strong) NSMutableArray<NSString *> *tvSeriesNameSearchArray;

@end

@implementation SBMetadataSearchController

#pragma mark Initialization

- (instancetype)initWithDelegate:(id <SBMetadataSearchControllerDelegate>)del searchString:(NSString *)searchString
{
	if ((self = [super initWithWindowNibName:@"MetadataSearch"])) {        
		delegate = del;
        _searchString = [searchString copy];

        NSMutableParagraphStyle * ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        ps.headIndent = -10.0;
        ps.alignment = NSTextAlignmentRight;
        detailBoldAttr = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]],
                           NSParagraphStyleAttributeName: ps,
                           NSForegroundColorAttributeName: [NSColor grayColor]};
    }

	return self;
}

- (void)windowDidLoad {
    
    [super windowDidLoad];

    [self.window makeFirstResponder:movieName];

	// metadata provider preferences
	[movieMetadataProvider selectItemWithTitle:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
	[tvMetadataProvider selectItemWithTitle:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
	[self metadataProviderSelected:movieMetadataProvider];
	[self metadataProviderSelected:tvMetadataProvider];

    if (_searchString) {
        NSDictionary *parsed = [SBMetadataHelper parseFilename:_searchString];
        if (parsed) {

            if ([@"movie" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
                [searchMode selectTabViewItemAtIndex:0];
                if ([parsed valueForKey:@"title"]) movieName.stringValue = [parsed valueForKey:@"title"];
            } else if ([@"tv" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
                [searchMode selectTabViewItemAtIndex:1];
                [self.window makeFirstResponder:tvSeriesName];
                if ([parsed valueForKey:@"seriesName"]) ((NSTextField *) tvSeriesName).stringValue = [parsed valueForKey:@"seriesName"];
                if ([parsed valueForKey:@"seasonNum"]) tvSeasonNum.stringValue = [parsed valueForKey:@"seasonNum"];
                if ([parsed valueForKey:@"episodeNum"]) tvEpisodeNum.stringValue = [parsed valueForKey:@"episodeNum"];
                // just in case this is actually a movie, set the text in the movie field for the user's convenience
                movieName.stringValue = _searchString.stringByDeletingPathExtension;
            }

            [self updateSearchButtonVisibility];

            if (searchButton.enabled) {
                [self searchForResults:nil];
            }
        }
    }
    
    return;
}

#pragma mark Metadata provider

- (NSString *)displayLanguageForLang:(NSString *)lang type:(SBMetadataImporterLanguageType)type
{
    if (type == SBMetadataImporterLanguageTypeISO) {
        return [MP42Languages.defaultManager localizedLangForExtendedTag:lang];
    }
    else {
        return lang;
    }
}

- (void)createLanguageMenusForProvider:(NSString *)providerName popUp:(NSPopUpButton *)popUp {
	NSArray *langs = [SBMetadataImporter languagesForProvider:providerName];
    SBMetadataImporterLanguageType type = [SBMetadataImporter languageTypeForProvider:providerName];

    [popUp removeAllItems];
	for (NSString *lang in langs) {
        [popUp addItemWithTitle:[self displayLanguageForLang:lang type:type]];
	}
}

- (void)metadataProvidersSelectDefaultLanguage {
    SBMetadataImporterLanguageType type = [SBMetadataImporter languageTypeForProvider:movieMetadataProvider.selectedItem.title];
    NSString *defaultLanguage = [[NSUserDefaults standardUserDefaults]
                                 valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", movieMetadataProvider.selectedItem.title]];
    [movieLanguage selectItemWithTitle:[self displayLanguageForLang:defaultLanguage type:type]];
    if (movieLanguage.indexOfSelectedItem == -1) {
        [movieLanguage selectItemWithTitle:[self displayLanguageForLang:[SBMetadataImporter defaultLanguageForProvider:movieMetadataProvider.selectedItem.title]
                                                                   type:type]];
    }

    type = [SBMetadataImporter languageTypeForProvider:tvMetadataProvider.selectedItem.title];
    defaultLanguage = [[NSUserDefaults standardUserDefaults]
                       valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", tvMetadataProvider.selectedItem.title]];
	[tvLanguage selectItemWithTitle:[self displayLanguageForLang:defaultLanguage type:type]];
    if (tvLanguage.indexOfSelectedItem == -1) {
        [tvLanguage selectItemWithTitle:[self displayLanguageForLang:[SBMetadataImporter defaultLanguageForProvider:tvMetadataProvider.selectedItem.title]
                                                                type:type]];
    }
}

- (IBAction)metadataProviderLanguageSelected:(id)sender {
	if (sender == movieLanguage) {
        SBMetadataImporterLanguageType type = [SBMetadataImporter languageTypeForProvider:movieMetadataProvider.selectedItem.title];
        NSString *defaultLanguage = movieLanguage.selectedItem.title;

        if (type == SBMetadataImporterLanguageTypeISO) {
            defaultLanguage = [MP42Languages.defaultManager extendedTagForLocalizedLang:defaultLanguage];
        }

		[[NSUserDefaults standardUserDefaults] setValue:defaultLanguage forKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", movieMetadataProvider.selectedItem.title]];
	}
    else if (sender == tvLanguage) {
        SBMetadataImporterLanguageType type = [SBMetadataImporter languageTypeForProvider:tvMetadataProvider.selectedItem.title];
        NSString *defaultLanguage = tvLanguage.selectedItem.title;

        if (type == SBMetadataImporterLanguageTypeISO) {
            defaultLanguage = [MP42Languages.defaultManager extendedTagForLocalizedLang:defaultLanguage];
        }

		[[NSUserDefaults standardUserDefaults] setValue:defaultLanguage forKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", tvMetadataProvider.selectedItem.title]];
	}
}

- (IBAction)metadataProviderSelected:(id)sender {
	if (sender == movieMetadataProvider) {
		[[NSUserDefaults standardUserDefaults] setValue:movieMetadataProvider.selectedItem.title forKey:@"SBMetadataPreference|Movie"];
	}
    else if (sender == tvMetadataProvider) {
		[[NSUserDefaults standardUserDefaults] setValue:tvMetadataProvider.selectedItem.title forKey:@"SBMetadataPreference|TV"];
	}

	[self createLanguageMenusForProvider:movieMetadataProvider.selectedItem.title popUp:movieLanguage];
    [self createLanguageMenusForProvider:tvMetadataProvider.selectedItem.title popUp:tvLanguage];

	[self metadataProvidersSelectDefaultLanguage];

    [self searchForResults:nil];
}

#pragma mark Search input fields

- (void)updateSearchButtonVisibility {
    if (searchMode.selectedTabViewItem == self.movieTab) {
        if (movieName.stringValue.length > 0) {
            [searchButton setEnabled:YES];
            return;
        }
    } else if (searchMode.selectedTabViewItem == self.tvEpisodeTab) {
        if (tvSeriesName.stringValue.length > 0) {
            if ((tvSeasonNum.stringValue.length == 0) && (tvEpisodeNum.stringValue.length > 0)) {
                [searchButton setEnabled:NO];
                return;
            } else {
                [searchButton setEnabled:YES];
                return;
            }
        }
    }
    [searchButton setEnabled:NO];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self updateSearchButtonVisibility];
    addButton.keyEquivalent = @"";
    searchButton.keyEquivalent = @"\r";
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self updateSearchButtonVisibility];
}

- (void)searchTVSeriesNameDone:(NSArray *)seriesArray {
    self.tvSeriesNameSearchArray = [seriesArray mutableCopy];
    [self.tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
    [tvSeriesName noteNumberOfItemsChanged];
    [tvSeriesName reloadData];
}

#pragma mark Search for results

- (IBAction) searchForResults: (id) sender {
    [addButton setEnabled:NO];

    if (self.currentSearcher) {
        [self.currentSearcher cancel];
    }

    if (searchMode.selectedTabViewItem == self.movieTab && movieName.stringValue.length) {

        [self startProgressReportWithString:[NSString stringWithFormat:NSLocalizedString(@"Searching %@ for movie information…", nil),
                                             movieMetadataProvider.selectedItem.title]];

		self.currentSearcher = [SBMetadataImporter importerForProvider:movieMetadataProvider.selectedItem.title];


        NSString *language = movieLanguage.titleOfSelectedItem;
        if (self.currentSearcher.languageType == SBMetadataImporterLanguageTypeISO) {
            language = [MP42Languages.defaultManager extendedTagForLocalizedLang:language];

        }

		[self.currentSearcher searchMovie:movieName.stringValue
                            language:language
                   completionHandler:^(NSArray *results) {
                       [self searchForResultsDone:results];
                   }];

    }
    else if (searchMode.selectedTabViewItem == self.tvEpisodeTab && tvSeriesName.stringValue.length) {

        [self startProgressReportWithString:[NSString stringWithFormat:NSLocalizedString(@"Searching %@ for episode information…", nil),
                                             tvMetadataProvider.selectedItem.title]];

		self.currentSearcher = [SBMetadataImporter importerForProvider:tvMetadataProvider.selectedItem.title];

        NSString *language = tvLanguage.titleOfSelectedItem;
        if (self.currentSearcher.languageType == SBMetadataImporterLanguageTypeISO) {
            language = [MP42Languages.defaultManager extendedTagForLocalizedLang:language];

        }

		[self.currentSearcher searchTVSeries:tvSeriesName.stringValue
                               language:language
                              seasonNum:tvSeasonNum.stringValue
                             episodeNum:tvEpisodeNum.stringValue
                      completionHandler:^(NSArray *results) {
                          [self searchForResultsDone:results];
                      }];

    }
    else {

        // Nothing to search, reset the table view
        self.resultsArray = nil;
        self.selectedResult = nil;
        [resultsTable reloadData];
        [metadataTable reloadData];
    }
}

- (void) searchForResultsDone:(NSArray *)results {
    self.resultsArray = nil;

    [self stopProgressReport];

    self.resultsArray = results;
    self.selectedResult = nil;

    [resultsTable reloadData];
    [metadataTable reloadData];

    [self tableViewSelectionDidChange:[NSNotification notificationWithName:@"tableViewSelectionDidChange" object:resultsTable]];

    if (self.resultsArray.count) {
        [self.window makeFirstResponder:resultsTable];
    }
}

#pragma mark Load additional metadata

- (void)startProgressReportWithString:(NSString *)progressString
{
    [progress startAnimation:self];
    [progress setHidden:NO];
    progressText.stringValue = progressString;
    [progressText setHidden:NO];

    [resultsTable setEnabled:NO];
    [metadataTable setEnabled:NO];
}

- (void)stopProgressReport
{
    [progress setHidden:YES];
    [progressText setHidden:YES];
    [progress stopAnimation:self];

    [resultsTable setEnabled:YES];
    [metadataTable setEnabled:YES];
}

- (IBAction) loadAdditionalMetadata:(id) sender {
    if (self.currentSearcher) {
        [self.currentSearcher cancel];
    }

    [addButton setEnabled:NO];
    if (self.selectedResult.mediaKind == 9) {
        [self startProgressReportWithString:NSLocalizedString(@"Downloading additional movie metadata…", nil)];
		self.currentSearcher = [SBMetadataImporter importerForProvider:movieMetadataProvider.selectedItem.title];
    } else if (self.selectedResult.mediaKind == 10) {
        [self startProgressReportWithString:NSLocalizedString(@"Downloading additional TV metadata…", nil)];
		self.currentSearcher = [SBMetadataImporter importerForProvider:tvMetadataProvider.selectedItem.title];
    }

    NSString *language = movieLanguage.selectedItem.title;

    if (self.currentSearcher.languageType== SBMetadataImporterLanguageTypeISO) {
        language = [MP42Languages.defaultManager extendedTagForLocalizedLang:language];
    }

    [self.currentSearcher loadFullMetadata:self.selectedResult language:language completionHandler:^(SBMetadataResult *metadata) {
        [self stopProgressReport];

        self.selectedResult = metadata;
        [self selectArtwork];
    }];

}

#pragma mark Select artwork

- (void) selectArtwork {
    if (self.selectedResult.artworkThumbURLs && (self.selectedResult.artworkThumbURLs).count) {
        if ((self.selectedResult.artworkThumbURLs).count == 1) {
            [self loadArtworks:[NSIndexSet indexSetWithIndex:0]];
        } else {
            artworkSelectorWindow = [[SBArtworkSelector alloc] initWithDelegate:self
                                                                      imageURLs:self.selectedResult.artworkThumbURLs
                                                           artworkProviderNames:self.selectedResult.artworkProviderNames];
            [self.window beginSheet:artworkSelectorWindow.window completionHandler:NULL];
        }
    } else {
        [self addMetadata];
    }
}

- (void) selectArtworkDone:(NSIndexSet *)indexes {
    [self.window endSheet:artworkSelectorWindow.window];
    artworkSelectorWindow = nil;

    [self loadArtworks:indexes];
}

#pragma mark Load artwork

- (void) loadArtworks:(NSIndexSet *)indexes {
    if (indexes.count) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:NSLocalizedString(@"Downloading artwork…", nil)];
        [progressText setHidden:NO];
        [tvSeriesName setEnabled:NO];
        [tvSeasonNum setEnabled:NO];
        [tvEpisodeNum setEnabled:NO];
        [movieName setEnabled:NO];
        [searchButton setEnabled:NO];
        [resultsTable setEnabled:NO];
        [metadataTable setEnabled:NO];

        NSArray<NSURL *> *URLs = [self.selectedResult.artworkFullsizeURLs copy];
        NSArray<NSString *> *providerNames = [self.selectedResult.artworkProviderNames copy];

        dispatch_async(dispatch_get_global_queue(0, 0), ^{

            [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                NSData *artworkData = [SBMetadataHelper downloadDataFromURL:URLs[idx] cachePolicy:SBDefaultPolicy];

                // Hack, download smaller iTunes version if big iTunes version is not available
                if (!artworkData) {
                    NSString *provider = providerNames[idx];
                    if ([provider isEqualToString:@"iTunes"]) {
                        NSURL *url = URLs[idx];
                        url = [url.URLByDeletingPathExtension URLByAppendingPathExtension:@"600x600bb.jpg"];
                        artworkData = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBDefaultPolicy];
                    }
                }

                // Add artwork to metadata object
                if (artworkData && artworkData.length) {
                    MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
                    [self.selectedResult.artworks addObject:artwork];
                }
            }];

            dispatch_sync(dispatch_get_main_queue(), ^{
                [self addMetadata];
            });
        });


    } else {
        [self addMetadata];
    }
}

#pragma mark Finishing up

- (void) addMetadata {
    // save TV series name in user preferences
    if (self.selectedResult.mediaKind == 10) {
        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        NSMutableArray *newTVseries;
        NSString *formattedTVshowName = self.selectedResultTags[SBMetadataResultSeriesName];

        if (previousTVseries == nil) {
            newTVseries = [NSMutableArray array];
            [newTVseries addObject:formattedTVshowName];
            [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
        } else if ([previousTVseries indexOfObject:formattedTVshowName] == NSNotFound) {
            newTVseries = [NSMutableArray arrayWithArray:previousTVseries];
            [newTVseries addObject:formattedTVshowName];
            [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
        }
    }
    [delegate metadataImportDone:self.selectedResult];

    [metadataTable setDelegate:nil];
    [metadataTable setDataSource:nil];
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction) closeWindow: (id) sender
{
    [self.currentSearcher cancel];
    self.currentSearcher = nil;

    [metadataTable setDelegate:nil];
    [metadataTable setDataSource:nil];
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void) dealloc
{
    [self.currentSearcher cancel];
}

#pragma mark -

#pragma mark Privacy

+ (void) clearRecentSearches {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Previously used TV series"];
}

+ (void) deleteCachedMetadata {
	NSString *path = nil;
	NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

	if (paths.count) {
		NSString *bundleName = [NSBundle mainBundle].infoDictionary[@"CFBundleIdentifier"];
		path = [paths.firstObject stringByAppendingPathComponent:bundleName];

        NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
        for (NSString *filename in contents) {
            [[NSFileManager defaultManager] removeItemAtPath:[path stringByAppendingPathComponent:filename] error:nil];
        }
	}
}

#pragma mark Miscellaneous

- (NSAttributedString *) boldString: (NSString *) string {
    return [[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr];
}

#pragma mark -

#pragma mark NSComboBox delegates and protocols

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString {

    if (uncompletedString.length < 1) {
        return nil;
    }

    if (comboBox == tvSeriesName) {

        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        if (previousTVseries == nil) { return nil; }

        for (NSString *s in previousTVseries) {
            if ([s.lowercaseString hasPrefix:uncompletedString.lowercaseString]) {
                return s;
            }
        }
    }
    return nil;
}

- (void)comboBoxWillPopUp:(NSNotification *)notification {
    if (notification.object == tvSeriesName) {
        if (tvSeriesName.stringValue.length == 0) {
            self.tvSeriesNameSearchArray = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"]];
            [self.tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
            [tvSeriesName reloadData];
        } else if (tvSeriesName.stringValue.length > 3) {
            self.tvSeriesNameSearchArray = [NSMutableArray array];
            [self.tvSeriesNameSearchArray addObject:NSLocalizedString(@"searching…", nil)];

            [tvSeriesName reloadData];
            [self.currentSearcher cancel];

            self.currentSearcher = [SBMetadataImporter defaultTVProvider];
			[self.currentSearcher searchTVSeries:tvSeriesName.stringValue language:tvLanguage.selectedItem.title completionHandler:^(NSArray *results) {
                self.tvSeriesNameSearchArray = [results mutableCopy];
                [self.tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
                [self->tvSeriesName noteNumberOfItemsChanged];
                [self->tvSeriesName reloadData];
            }];
        } else {
            self.tvSeriesNameSearchArray = nil;
            [tvSeriesName reloadData];
        }
    }
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    if (notification.object == tvSeriesName) {
        tvSeriesName.stringValue = [self selectedTvShowName];
        [self updateSearchButtonVisibility];
    }
}

- (NSString *)selectedTvShowName {
    NSString *name = @"";
    NSComboBox *comboBox = tvSeriesName;
    NSInteger selectedIndex = comboBox.indexOfSelectedItem;
    if (selectedIndex > -1) {
        id<NSComboBoxDataSource> dataSource = tvSeriesName.dataSource;
        name = [dataSource comboBox:tvSeriesName objectValueForItemAtIndex:selectedIndex];
    }
    return name;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == tvSeriesName) {
        return self.tvSeriesNameSearchArray.count;
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == tvSeriesName) {
        return (self.tvSeriesNameSearchArray)[index];
    }
    return nil;
}

#pragma mark -

#pragma mark NSTableView delegates and protocols

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == resultsTable) {
            return self.resultsArray.count;
    } else if (tableView == (NSTableView *) metadataTable) {
            return self.selectedResultTagsArray.count;
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == resultsTable) {
        if (self.resultsArray != nil) {
            SBMetadataResult *result = (self.resultsArray)[rowIndex];
            if ((result.mediaKind == 10) && ((self.resultsArray).count > 1)) { // TV show
                return [NSString stringWithFormat:@"%@x%@ - %@", result[SBMetadataResultSeason], result[SBMetadataResultEpisodeNumber], result[SBMetadataResultName]];
            } else {
                return result[SBMetadataResultName];
            }
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (self.selectedResult != nil) {
            if ([tableColumn.identifier isEqualToString:@"name"]) {
                return [self boldString:[SBMetadataResult localizedDisplayNameForKey:self.selectedResultTagsArray[rowIndex]]];
            }
            if ([tableColumn.identifier isEqualToString:@"value"]) {
                return (self.selectedResultTags)[(self.selectedResultTagsArray)[rowIndex]];
            }
        }
    }
    return nil;
}

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;
    
    NSInteger right = [(__bridge NSArray*) context indexOfObject:rdict];
    NSInteger left = [(__bridge NSArray*) context indexOfObject:ldict];
    
    if (right < left) {
        rc = NSOrderedDescending;
    }
    else {
        rc = NSOrderedAscending;
    }
    
    return rc;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if (aNotification.object == resultsTable || aNotification.object ==  metadataTable) {
        if (self.resultsArray && (self.resultsArray).count > 0 && resultsTable.selectedRow > -1) {
            self.selectedResult = (self.resultsArray)[resultsTable.selectedRow];
            self.selectedResultTags = self.selectedResult.tags;
            NSArray<NSString *> *sortKeys = self.selectedResult.mediaKind == 9 ? [SBMetadataResult movieKeys] : [SBMetadataResult tvShowKeys];
            self.selectedResultTagsArray = [self.selectedResultTags.allKeys sortedArrayUsingFunction:sortFunction
                                                                                            context:(__bridge void * _Nullable)sortKeys];

            [metadataTable reloadData];
            [addButton setEnabled:YES];
            addButton.keyEquivalent = @"\r";
            searchButton.keyEquivalent = @"";
        }
    } else {
        [addButton setEnabled:NO];
        addButton.keyEquivalent = @"";
        searchButton.keyEquivalent = @"\r";
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != (NSTableView *) metadataTable) return tableView.rowHeight;
    
    // It is important to use a constant value when calculating the height. Querying the tableColumn width will not work, since it dynamically changes as the user resizes -- however, we don't get a notification that the user "did resize" it until after the mouse is let go. We use the latter as a hook for telling the table that the heights changed. We must return the same height from this method every time, until we tell the table the heights have changed. Not doing so will quicly cause drawing problems.
    NSTableColumn *tableColumnToWrap = (NSTableColumn *) tableView.tableColumns[1];
    NSInteger columnToWrap = [tableView.tableColumns indexOfObject:tableColumnToWrap];
    
    // Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
    NSCell *cell = [tableView preparedCellAtColumn:columnToWrap row:row];
    
    // See how tall it naturally would want to be if given a restricted with, but unbound height
    NSRect constrainedBounds = NSMakeRect(0, 0, tableColumnToWrap.width, CGFLOAT_MAX);
    NSSize naturalSize = [cell cellSizeForBounds:constrainedBounds];
    
    // Make sure we have a minimum height -- use the table's set height as the minimum.
    if (naturalSize.height > tableView.rowHeight) {
        return naturalSize.height;
    } else {
        return tableView.rowHeight;
    }
}

@end
