//
//  MetadataImportController.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBTableView;
@class SBArtworkSelector;
@class MP42Metadata;

@protocol SBMetadataSearchControllerDelegate
- (void)metadataImportDone:(MP42Metadata *)metadataToBeImported;
@end

@interface SBMetadataSearchController : NSWindowController <NSTableViewDelegate> {
    id                           delegate;
    NSDictionary                 *detailBoldAttr;

    IBOutlet NSTabView           *searchMode;
    
    IBOutlet NSTextField         *movieName;
    IBOutlet NSPopUpButton       *movieLanguage;
	IBOutlet NSPopUpButton       *movieMetadataProvider;
    
    IBOutlet NSComboBox          *tvSeriesName;
    NSMutableArray               *tvSeriesNameSearchArray;
    IBOutlet NSTextField         *tvSeasonNum;
    IBOutlet NSTextField         *tvEpisodeNum;
    IBOutlet NSPopUpButton       *tvLanguage;
	IBOutlet NSPopUpButton       *tvMetadataProvider;
    
    IBOutlet NSButton            *searchButton;
    id                            currentSearcher;

    NSArray                      *resultsArray;
    IBOutlet NSTableView         *resultsTable;
    MP42Metadata                 *selectedResult;
    NSDictionary                 *selectedResultTags;
    NSArray                      *selectedResultTagsArray;
    IBOutlet SBTableView         *metadataTable;

    IBOutlet NSButton            *addButton;

    id                           artworkSelectorWindow;

    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField         *progressText;
    
}

#pragma mark Initialization
- (instancetype)initWithDelegate:(id)del;

#pragma mark Metadata provider
- (void) createLanguageMenus;
- (void) metadataProvidersSelectDefaultLanguage;
- (IBAction) metadataProviderLanguageSelected:(id)sender;
- (IBAction) metadataProviderSelected:(id)sender;

#pragma mark Search input fields
- (void) updateSearchButtonVisibility;
- (void) searchTVSeriesNameDone:(NSMutableArray *)seriesArray;

#pragma mark Search for metadata
- (IBAction) searchForResults:(id)sender;
- (void) searchForResultsDone:(NSArray *)metadataArray;

#pragma mark Load additional metadata
- (IBAction) loadAdditionalMetadata:(id)sender;
- (void) loadAdditionalMetadataDone:(MP42Metadata *)metadata;

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

#pragma mark Static methods
+ (void) clearRecentSearches;
+ (void) deleteCachedMetadata;

@end
