//
//  MetadataImportController.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBMetadataSearchController.h"
#import "SBArtworkSelector.h"
#import "SBDocument.h"
#import "MetadataImporter.h"

@interface SBMetadataSearchController () <NSTableViewDelegate, SBArtworkSelectorDelegate>

@property (nonatomic, readwrite, retain) MetadataImporter *currentSearcher;
@property (nonatomic, readwrite, retain) NSArray<MP42Metadata *> *resultsArray;

@property (nonatomic, readwrite, retain) MP42Metadata *selectedResult;

@property (nonatomic, readwrite, retain) NSDictionary *selectedResultTags;
@property (nonatomic, readwrite, retain) NSArray<NSString *> *selectedResultTagsArray;

@property (nonatomic, readwrite, retain) NSMutableArray<NSString *> *tvSeriesNameSearchArray;

#pragma mark Metadata provider
- (void) createLanguageMenus;
- (void) metadataProvidersSelectDefaultLanguage;
- (IBAction) metadataProviderLanguageSelected:(id)sender;
- (IBAction) metadataProviderSelected:(id)sender;

#pragma mark Search input fields
- (void) updateSearchButtonVisibility;
- (void) searchTVSeriesNameDone:(NSArray *)seriesArray;

#pragma mark Search for metadata
- (IBAction) searchForResults:(id)sender;
- (void) searchForResultsDone:(NSArray *)metadataArray;

#pragma mark Load additional metadata
- (IBAction) loadAdditionalMetadata:(id)sender;

#pragma mark Select artwork
- (void) selectArtwork;
- (void) selectArtworkDone:(NSIndexSet *)indexes;

#pragma mark Load artwork
- (void) loadArtworks:(NSIndexSet *)indexes;

#pragma mark Finishing up
- (void) addMetadata;
- (IBAction) closeWindow: (id) sender;

#pragma mark Miscellaneous
- (NSAttributedString *) boldString: (NSString *) string;

@end

@implementation SBMetadataSearchController

@synthesize currentSearcher = _currentSearcher;
@synthesize resultsArray = _resultsArray;
@synthesize selectedResult = _selectedResult;
@synthesize selectedResultTags = _selectedResultTags;
@synthesize selectedResultTagsArray = _selectedResultTagsArray;
@synthesize tvSeriesNameSearchArray = _tvSeriesNameSearchArray;

#pragma mark Initialization

- (instancetype)initWithDelegate:(id <SBMetadataSearchControllerDelegate>)del searchString:(NSString *)searchString
{
	if ((self = [super initWithWindowNibName:@"MetadataSearch"])) {        
		delegate = del;
        _searchString = [searchString copy];

        NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [ps setHeadIndent: -10.0];
        [ps setAlignment:NSRightTextAlignment];
        detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                           [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
                           ps, NSParagraphStyleAttributeName,
                           [NSColor grayColor], NSForegroundColorAttributeName,
                           nil] retain];
    }

	return self;
}

- (void)windowDidLoad {
    
    [super windowDidLoad];

    [[self window] makeFirstResponder:movieName];

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
                if ([parsed valueForKey:@"title"]) [movieName setStringValue:[parsed valueForKey:@"title"]];
            } else if ([@"tv" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
                [searchMode selectTabViewItemAtIndex:1];
                [[self window] makeFirstResponder:tvSeriesName];
                if ([parsed valueForKey:@"seriesName"]) [((NSTextField *) tvSeriesName) setStringValue:[parsed valueForKey:@"seriesName"]];
                if ([parsed valueForKey:@"seasonNum"]) [tvSeasonNum setStringValue:[parsed valueForKey:@"seasonNum"]];
                if ([parsed valueForKey:@"episodeNum"]) [tvEpisodeNum setStringValue:[parsed valueForKey:@"episodeNum"]];
                // just in case this is actually a movie, set the text in the movie field for the user's convenience
                [movieName setStringValue:[_searchString stringByDeletingPathExtension]];
            }

            [self updateSearchButtonVisibility];

            if ([searchButton isEnabled]) {
                [self searchForResults:nil];
            }
        }
    }
    
    return;
}

#pragma mark Metadata provider

- (void) createLanguageMenus {
	[movieLanguage removeAllItems];
	NSArray *langs = [MetadataImporter languagesForProvider:[[movieMetadataProvider selectedItem] title]];
	for (NSString *lang in langs) {
		[movieLanguage addItemWithTitle:lang];
	}

	[tvLanguage removeAllItems];
	langs = [MetadataImporter languagesForProvider:[[tvMetadataProvider selectedItem] title]];
	for (NSString *lang in langs) {
		[tvLanguage addItemWithTitle:lang];
	}
}

- (void) metadataProvidersSelectDefaultLanguage {
	[movieLanguage selectItemWithTitle:[[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [[movieMetadataProvider selectedItem] title]]]];
	[tvLanguage selectItemWithTitle:[[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [[tvMetadataProvider selectedItem] title]]]];
}

- (IBAction) metadataProviderLanguageSelected:(id)sender {
	if (sender == movieLanguage) {
		[[NSUserDefaults standardUserDefaults] setValue:[[movieLanguage selectedItem] title] forKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [[movieMetadataProvider selectedItem] title]]];
	} else if (sender == tvLanguage) {
		[[NSUserDefaults standardUserDefaults] setValue:[[tvLanguage selectedItem] title] forKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [[tvMetadataProvider selectedItem] title]]];
	}
}

- (IBAction) metadataProviderSelected:(id)sender {
	if (sender == movieMetadataProvider) {
		[[NSUserDefaults standardUserDefaults] setValue:[[movieMetadataProvider selectedItem] title] forKey:@"SBMetadataPreference|Movie"];
	} else if (sender == tvMetadataProvider) {
		[[NSUserDefaults standardUserDefaults] setValue:[[tvMetadataProvider selectedItem] title] forKey:@"SBMetadataPreference|TV"];
	}

	[self createLanguageMenus];
	[self metadataProvidersSelectDefaultLanguage];
    [self searchForResults:nil];
}

#pragma mark Search input fields

- (void)updateSearchButtonVisibility {
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"]) {
        if ([[movieName stringValue] length] > 0) {
            [searchButton setEnabled:YES];
            return;
        }
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        if ([[tvSeriesName stringValue] length] > 0) {
            if (([[tvSeasonNum stringValue] length] == 0) && ([[tvEpisodeNum stringValue] length] > 0)) {
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
    [addButton setKeyEquivalent:@""];
    [searchButton setKeyEquivalent:@"\r"];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self updateSearchButtonVisibility];
}

- (void)searchTVSeriesNameDone:(NSArray *)seriesArray {
    self.tvSeriesNameSearchArray = [[seriesArray mutableCopy] autorelease];
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

    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"] && [[movieName stringValue] length]) {

        [self startProgressReportWithString:[NSString stringWithFormat:@"Searching %@ for movie information…",
                                             [[movieMetadataProvider selectedItem] title]]];

		self.currentSearcher = [MetadataImporter importerForProvider:[[movieMetadataProvider selectedItem] title]];
		[self.currentSearcher searchMovie:[movieName stringValue]
                            language:[movieLanguage titleOfSelectedItem]
                   completionHandler:^(NSArray *results) {
                       [self searchForResultsDone:results];
                   }];

    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"] && [[tvSeriesName stringValue] length]) {

        [self startProgressReportWithString:[NSString stringWithFormat:@"Searching %@ for episode information…",
                                             [[tvMetadataProvider selectedItem] title]]];

		self.currentSearcher = [MetadataImporter importerForProvider:[[tvMetadataProvider selectedItem] title]];
		[self.currentSearcher searchTVSeries:[tvSeriesName stringValue]
                               language:[tvLanguage titleOfSelectedItem]
                              seasonNum:[tvSeasonNum stringValue]
                             episodeNum:[tvEpisodeNum stringValue]
                      completionHandler:^(NSArray *results) {
                          [self searchForResultsDone:results];
                      }];

    } else {

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

    if ([self.resultsArray count])
        [[self window] makeFirstResponder:resultsTable];
}

#pragma mark Load additional metadata

- (void)startProgressReportWithString:(NSString *)progressString
{
    [progress startAnimation:self];
    [progress setHidden:NO];
    [progressText setStringValue:progressString];
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
        [self startProgressReportWithString:@"Downloading additional movie metadata…"];
		self.currentSearcher = [MetadataImporter importerForProvider:[[movieMetadataProvider selectedItem] title]];
    } else if (self.selectedResult.mediaKind == 10) {
        [self startProgressReportWithString:@"Downloading additional TV metadata…"];
		self.currentSearcher = [MetadataImporter importerForProvider:[[tvMetadataProvider selectedItem] title]];
    }

    [self.currentSearcher loadFullMetadata:self.selectedResult language:[[movieLanguage selectedItem] title] completionHandler:^(MP42Metadata *metadata) {
        [self stopProgressReport];

        self.selectedResult = metadata;
        [self selectArtwork];
    }];

}

#pragma mark Select artwork

- (void) selectArtwork {
    if (self.selectedResult.artworkThumbURLs && [self.selectedResult.artworkThumbURLs count]) {
        if ([self.selectedResult.artworkThumbURLs count] == 1) {
            [self loadArtworks:[NSIndexSet indexSetWithIndex:0]];
        } else {
            artworkSelectorWindow = [[SBArtworkSelector alloc] initWithDelegate:self
                                                                      imageURLs:self.selectedResult.artworkThumbURLs
                                                           artworkProviderNames:self.selectedResult.artworkProviderNames];
            [NSApp beginSheet:[artworkSelectorWindow window] modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:nil];
        }
    } else {
        [self addMetadata];
    }
}

- (void) selectArtworkDone:(NSIndexSet *)indexes {
    [NSApp endSheet:[artworkSelectorWindow window]];
    [[artworkSelectorWindow window] orderOut:self];
    [artworkSelectorWindow autorelease]; artworkSelectorWindow = nil;

    [self loadArtworks:indexes];
}

#pragma mark Load artwork

- (void) loadArtworks:(NSIndexSet *)indexes {
    if (indexes.count) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Downloading artwork…"];
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
                NSData *artworkData = [SBMetadataHelper downloadDataFromURL:URLs[idx] withCachePolicy:SBDefaultPolicy];

                // Hack, download smaller iTunes version if big iTunes version is not available
                if (!artworkData) {
                    NSString *provider = providerNames[idx];
                    if ([provider isEqualToString:@"iTunes"]) {
                        NSURL *url = URLs[idx];
                        url = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"600x600bb.jpg"];
                        artworkData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
                    }
                }

                // Add artwork to metadata object
                if (artworkData && artworkData.length) {
                    MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
                    [self.selectedResult.artworks addObject:artwork];
                    [artwork release];
                }
            }];

            dispatch_sync(dispatch_get_main_queue(), ^{
                [self addMetadata];
            });
        });

        [URLs release];
        [providerNames release];

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
        NSString *formattedTVshowName = [self.selectedResultTags objectForKey:@"TV Show"];

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

    [NSApp endSheet:[self window] returnCode:1];
}

- (IBAction) closeWindow: (id) sender
{
    [self.currentSearcher cancel];
    self.currentSearcher = nil;

    [metadataTable setDelegate:nil];
    [metadataTable setDataSource:nil];
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];

    [NSApp endSheet:[self window] returnCode:0];
}

- (void) dealloc
{
    [self.currentSearcher cancel];
    self.currentSearcher = nil;

    self.resultsArray = nil;
    self.selectedResult = nil;

    self.selectedResultTags = nil;
    self.selectedResultTagsArray = nil;

    self.tvSeriesNameSearchArray = nil;

    [detailBoldAttr release];

    [super dealloc];
}

#pragma mark -

#pragma mark Privacy

+ (void) clearRecentSearches {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Previously used TV series"];
}

+ (void) deleteCachedMetadata {
	NSString *path = nil;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	if ([paths count]) {
		NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
		path = [[paths firstObject] stringByAppendingPathComponent:bundleName];
	}
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	for (NSString *filename in contents) {
		[[NSFileManager defaultManager] removeItemAtPath:[path stringByAppendingPathComponent:filename] error:nil];
	}
}

#pragma mark Miscellaneous

- (NSAttributedString *) boldString: (NSString *) string {
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
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
    if ([notification object] == tvSeriesName) {
        if ([[tvSeriesName stringValue] length] == 0) {
            self.tvSeriesNameSearchArray = [[[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"]] autorelease];
            [self.tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
            [tvSeriesName reloadData];
        } else if ([[tvSeriesName stringValue] length] > 3) {
            self.tvSeriesNameSearchArray = [NSMutableArray array];
            [self.tvSeriesNameSearchArray addObject:@"searching…"];

            [tvSeriesName reloadData];
            [self.currentSearcher cancel];

            self.currentSearcher = [MetadataImporter defaultTVProvider];
			[self.currentSearcher searchTVSeries:[tvSeriesName stringValue] language:[[tvLanguage selectedItem] title] completionHandler:^(NSArray *results) {
                self.tvSeriesNameSearchArray = [[results mutableCopy] autorelease];
                [self.tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
                [tvSeriesName noteNumberOfItemsChanged];
                [tvSeriesName reloadData];
            }];
        } else {
            self.tvSeriesNameSearchArray = nil;
            [tvSeriesName reloadData];
        }
    }
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == tvSeriesName) {
        return self.tvSeriesNameSearchArray.count;
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == tvSeriesName) {
        return [self.tvSeriesNameSearchArray objectAtIndex:index];
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
            MP42Metadata *result = [self.resultsArray objectAtIndex:rowIndex];
            if ((result.mediaKind == 10) && ([self.resultsArray count] > 1)) { // TV show
                return [NSString stringWithFormat:@"%@x%@ - %@", [result.tagsDict valueForKey:@"TV Season"], [result.tagsDict valueForKey:@"TV Episode #"], [result.tagsDict valueForKey:@"Name"]];
            } else {
                return [result.tagsDict valueForKey:@"Name"];
            }
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (self.selectedResult != nil) {
            if ([tableColumn.identifier isEqualToString:@"name"]) {
                return [self boldString:[self.selectedResultTagsArray objectAtIndex:rowIndex]];
            }
            if ([tableColumn.identifier isEqualToString:@"value"]) {
                return [self.selectedResultTags objectForKey:[self.selectedResultTagsArray objectAtIndex:rowIndex]];
            }
        }
    }
    return nil;
}

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;
    
    NSInteger right = [(NSArray*) context indexOfObject:rdict];
    NSInteger left = [(NSArray*) context indexOfObject:ldict];
    
    if (right < left) {
        rc = NSOrderedDescending;
    }
    else {
        rc = NSOrderedAscending;
    }
    
    return rc;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([aNotification object] == resultsTable || [aNotification object] ==  metadataTable) {
        if (self.resultsArray && [self.resultsArray count] > 0 && [resultsTable selectedRow] > -1) {
            self.selectedResult = [self.resultsArray objectAtIndex:[resultsTable selectedRow]];
            self.selectedResultTags = self.selectedResult.tagsDict;
            self.selectedResultTagsArray = [[self.selectedResultTags allKeys] sortedArrayUsingFunction:sortFunction context:[self.selectedResult availableMetadata]];
            [metadataTable reloadData];
            [addButton setEnabled:YES];
            [addButton setKeyEquivalent:@"\r"];
            [searchButton setKeyEquivalent:@""];
        }
    } else {
        [addButton setEnabled:NO];
        [addButton setKeyEquivalent:@""];
        [searchButton setKeyEquivalent:@"\r"];
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != (NSTableView *) metadataTable) return [tableView rowHeight];
    
    // It is important to use a constant value when calculating the height. Querying the tableColumn width will not work, since it dynamically changes as the user resizes -- however, we don't get a notification that the user "did resize" it until after the mouse is let go. We use the latter as a hook for telling the table that the heights changed. We must return the same height from this method every time, until we tell the table the heights have changed. Not doing so will quicly cause drawing problems.
    NSTableColumn *tableColumnToWrap = (NSTableColumn *) [[tableView tableColumns] objectAtIndex:1];
    NSInteger columnToWrap = [tableView.tableColumns indexOfObject:tableColumnToWrap];
    
    // Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
    NSCell *cell = [tableView preparedCellAtColumn:columnToWrap row:row];
    
    // See how tall it naturally would want to be if given a restricted with, but unbound height
    NSRect constrainedBounds = NSMakeRect(0, 0, [tableColumnToWrap width], CGFLOAT_MAX);
    NSSize naturalSize = [cell cellSizeForBounds:constrainedBounds];
    
    // Make sure we have a minimum height -- use the table's set height as the minimum.
    if (naturalSize.height > [tableView rowHeight]) {
        return naturalSize.height;
    } else {
        return [tableView rowHeight];
    }
}

@end
