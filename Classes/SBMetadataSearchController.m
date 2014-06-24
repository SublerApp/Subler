//
//  MetadataImportController.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42Languages.h>

#import <MP42Foundation/RegexKitLite.h>

#import "SBMetadataSearchController.h"
#import "SBArtworkSelector.h"
#import "SBDocument.h"
#import "MetadataImporter.h"

@interface SBMetadataSearchController () <NSTableViewDelegate, SBArtworkSelectorDelegate>

@end

@implementation SBMetadataSearchController

#pragma mark Initialization

- (instancetype)initWithDelegate:(id <SBMetadataSearchControllerDelegate>)del
{
	if ((self = [super initWithWindowNibName:@"MetadataSearch"])) {        
		delegate = del;

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

    MP42File *mp4File = [((SBDocument *) delegate) mp4File];
	
    NSString *filename = nil;
    for (MP42Track *track in mp4File.tracks) {
        if (track.sourceURL) {
            filename = [track.sourceURL lastPathComponent];
            break;
        }
    }

    if (!filename) return;

    NSDictionary *parsed = [MetadataImporter parseFilename:filename];
    if (!parsed) return;
    
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
        [movieName setStringValue:[filename stringByDeletingPathExtension]];
    }
    [self updateSearchButtonVisibility];
    if ([searchButton isEnabled]) {
        [self searchForResults:nil];
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
    if (tvSeriesNameSearchArray)
        [tvSeriesNameSearchArray release];

    tvSeriesNameSearchArray = [seriesArray mutableCopy];
    [tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
    [tvSeriesName noteNumberOfItemsChanged];
    [tvSeriesName reloadData];

	currentSearcher = nil;
}

#pragma mark Search for results

- (IBAction) searchForResults: (id) sender {
    [addButton setEnabled:NO];

    if (currentSearcher) {
        [currentSearcher cancel];
        currentSearcher = nil;
    }

    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"] && [[movieName stringValue] length]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
		[progressText setStringValue:[NSString stringWithFormat:@"Searching %@ for movie information…",
                                      [[movieMetadataProvider selectedItem] title]]];
		[progressText setHidden:NO];
		currentSearcher = [MetadataImporter importerForProvider:[[movieMetadataProvider selectedItem] title]];
		[currentSearcher searchMovie:[movieName stringValue] language:[movieLanguage titleOfSelectedItem] callback:self];
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"] && [[tvSeriesName stringValue] length]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
		[progressText setStringValue:[NSString stringWithFormat:@"Searching %@ for episode information…",
                                      [[tvMetadataProvider selectedItem] title]]];
		[progressText setHidden:NO];
		currentSearcher = [MetadataImporter importerForProvider:[[tvMetadataProvider selectedItem] title]];
		[currentSearcher searchTVSeries:[tvSeriesName stringValue] language:[tvLanguage titleOfSelectedItem] seasonNum:[tvSeasonNum stringValue] episodeNum:[tvEpisodeNum stringValue] callback:self];
    }
    else {
        // Nothing to search, reset the table view
        [resultsArray release];
        resultsArray = nil;
        selectedResult = nil;
        [resultsTable reloadData];
        [metadataTable reloadData];
    }
}

- (void) searchForResultsDone:(NSArray *)_resultsArray {
    if (resultsArray)
        [resultsArray release];

    [progressText setHidden:YES];
    [progress setHidden:YES];
    [progress stopAnimation:self];
    resultsArray = [_resultsArray retain];
    selectedResult = nil;
    [resultsTable reloadData];
    [metadataTable reloadData];
    [self tableViewSelectionDidChange:[NSNotification notificationWithName:@"tableViewSelectionDidChange" object:resultsTable]];
    if ([resultsArray count])
        [[self window] makeFirstResponder:resultsTable];
	currentSearcher = nil;
}

#pragma mark Load additional metadata

- (IBAction) loadAdditionalMetadata:(id) sender {
    if (currentSearcher) {
        [currentSearcher cancel];
        currentSearcher = nil;
    }

    [addButton setEnabled:NO];
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Downloading additional movie metadata…"];
        [progressText setHidden:NO];
		currentSearcher = [MetadataImporter importerForProvider:[[movieMetadataProvider selectedItem] title]];
		[currentSearcher loadMovieMetadata:selectedResult language:[[movieLanguage selectedItem] title] callback:self];
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Downloading additional TV metadata…"];
        [progressText setHidden:NO];
		currentSearcher = [MetadataImporter importerForProvider:[[tvMetadataProvider selectedItem] title]];
		[currentSearcher loadTVMetadata:selectedResult language:[[tvLanguage selectedItem] title] callback:self];
    }
}

- (void) loadAdditionalMetadataDone:(MP42Metadata *)metadata {
    [progress setHidden:YES];
    [progressText setHidden:YES];
    [progress stopAnimation:self];
    selectedResult = metadata;
    [self selectArtwork];
	currentSearcher = nil;
}

#pragma mark Select artwork

- (void) selectArtwork {
    if (selectedResult.artworkThumbURLs && [selectedResult.artworkThumbURLs count]) {
        if ([selectedResult.artworkThumbURLs count] == 1) {
            [self loadArtworks:[NSIndexSet indexSetWithIndex:0]];
        } else {
            artworkSelectorWindow = [[SBArtworkSelector alloc] initWithDelegate:self imageURLs:selectedResult.artworkThumbURLs artworkProviderNames:selectedResult.artworkProviderNames];
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
    if (indexes) {
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

        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            dispatch_group_t group = dispatch_group_create();

            [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
                    NSData *artworkData = [MetadataImporter downloadDataFromURL:[selectedResult.artworkFullsizeURLs objectAtIndex:idx] withCachePolicy:SBDefaultPolicy];

                    // Hack, download smaller iTunes version if big iTunes version is not available
                    if (!artworkData) {
                        NSString *provider = [selectedResult.artworkProviderNames objectAtIndex:idx];
                        if ([provider isEqualToString:@"iTunes"]) {
                            NSURL *url = [selectedResult.artworkFullsizeURLs objectAtIndex:idx];
                            url = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"600x600-75.jpg"];
                            artworkData = [MetadataImporter downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
                        }
                    }

                    // Add artwork to metadata object
                    if (artworkData && [artworkData length]) {
                        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            [selectedResult.artworks addObject:artwork];
                        });
                        [artwork release];
                    }
                });
            }];

            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            dispatch_release(group);
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self addMetadata];
            });
        });
    }
    else {
        [self addMetadata];
    }
}

#pragma mark Finishing up

- (void) addMetadata {
    // save TV series name in user preferences
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        NSMutableArray *newTVseries;
        NSString *formattedTVshowName = [selectedResultTags objectForKey:@"TV Show"];
        if (previousTVseries == nil) {
            newTVseries = [NSMutableArray arrayWithCapacity:1];
            [newTVseries addObject:formattedTVshowName];
            [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            if ([previousTVseries indexOfObject:formattedTVshowName] == NSNotFound) {
                newTVseries = [NSMutableArray arrayWithArray:previousTVseries];
                [newTVseries addObject:formattedTVshowName];
                [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
    [delegate metadataImportDone:selectedResult];
}

- (IBAction) closeWindow: (id) sender
{
	if (currentSearcher)
		[currentSearcher cancel];

    [delegate metadataImportDone:nil];
}

- (void) dealloc
{
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];
    [metadataTable setDelegate:nil];
    [metadataTable setDataSource:nil];

    [detailBoldAttr release];

    [selectedResultTagsArray release];
    [tvSeriesNameSearchArray release];
    [resultsArray release];

	if (currentSearcher) {
		[currentSearcher cancel];
    }

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
    if (!uncompletedString || ([uncompletedString length] < 1)) return nil;
    if (comboBox == tvSeriesName) {
        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        if (previousTVseries == nil) return nil;
        NSEnumerator *previousTVseriesEnum = [previousTVseries objectEnumerator];
        NSString *s;
        while ((s = (NSString *) [previousTVseriesEnum nextObject])) {
            if ([[s lowercaseString] hasPrefix:[uncompletedString lowercaseString]]) {
                return s;
            }
        }
        return nil;
    }
    return nil;
}

- (void)comboBoxWillPopUp:(NSNotification *)notification {
    if ([notification object] == tvSeriesName) {
        if ([[tvSeriesName stringValue] length] == 0) {
            [tvSeriesNameSearchArray release];
            tvSeriesNameSearchArray = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"]];
            [tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
            [tvSeriesName reloadData];
        } else if ([[tvSeriesName stringValue] length] > 3) {
            [tvSeriesNameSearchArray release];
            tvSeriesNameSearchArray = [[NSMutableArray alloc] initWithCapacity:1];
            [tvSeriesNameSearchArray addObject:@"searching…"];
            [tvSeriesName reloadData];
            [currentSearcher cancel];
            currentSearcher = [MetadataImporter defaultTVProvider];
			[currentSearcher searchTVSeries:[tvSeriesName stringValue] language:[[tvLanguage selectedItem] title] callback:self];
        } else {
            tvSeriesNameSearchArray = nil;
            [tvSeriesName reloadData];
        }
    }
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    // for some unknown reason, the number of items displayed won't be correct unless these member variables get accessed
    // bug to fix!
    //NSLog(@"in numberOfItemsInComboBox; box numberOfVisibleItems = %d, cell numberOfVisibleItems = %d", (int) [comboBox numberOfVisibleItems], (int) [[comboBox cell] numberOfVisibleItems]);
    if (comboBox == tvSeriesName) {
        if (tvSeriesNameSearchArray != nil) {
            return [tvSeriesNameSearchArray count];
        }
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == tvSeriesName) {
        if (tvSeriesNameSearchArray != nil) {
            return [tvSeriesNameSearchArray objectAtIndex:index];
        }
    }
    return nil;
}

#pragma mark -

#pragma mark NSTableView delegates and protocols

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == resultsTable) {
        if (resultsArray != nil) {
            return [resultsArray count];
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (selectedResult != nil) {
            return [selectedResultTagsArray count];
        }
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == resultsTable) {
        if (resultsArray != nil) {
            MP42Metadata *result = [resultsArray objectAtIndex:rowIndex];
            if ((result.mediaKind == 10) && ([resultsArray count] > 1)) { // TV show
                return [NSString stringWithFormat:@"%@x%@ - %@", [result.tagsDict valueForKey:@"TV Season"], [result.tagsDict valueForKey:@"TV Episode #"], [result.tagsDict valueForKey:@"Name"]];
            } else {
                return [result.tagsDict valueForKey:@"Name"];
            }
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (selectedResult != nil) {
            if ([tableColumn.identifier isEqualToString:@"name"]) {
                return [self boldString:[selectedResultTagsArray objectAtIndex:rowIndex]];
            }
            if ([tableColumn.identifier isEqualToString:@"value"]) {
                return [selectedResultTags objectForKey:[selectedResultTagsArray objectAtIndex:rowIndex]];
            }
        }
    }
    return nil;
}

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;
    
    NSInteger right = [(NSArray*) context indexOfObject:rdict];
    NSInteger left = [(NSArray*) context indexOfObject:ldict];
    
    if (right < left)
        rc = NSOrderedDescending;
    else
        rc = NSOrderedAscending;
    
    return rc;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([aNotification object] == resultsTable || [aNotification object] ==  metadataTable) {
        if (/*resultsArray && */[resultsArray count] > 0) {
            selectedResult = [resultsArray objectAtIndex:[resultsTable selectedRow]];
            selectedResultTags = selectedResult.tagsDict;
            if (selectedResultTagsArray) [selectedResultTagsArray release];
            selectedResultTagsArray = [[[selectedResultTags allKeys] sortedArrayUsingFunction:sortFunction context:[selectedResult availableMetadata]] retain];
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
