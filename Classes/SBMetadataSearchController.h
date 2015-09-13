//
//  MetadataImportController.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class SBTableView;

@class MP42Metadata;
@class MetadataImporter;

@protocol SBMetadataSearchControllerDelegate
- (void)metadataImportDone:(MP42Metadata *)metadataToBeImported;
@end

@interface SBMetadataSearchController : NSWindowController {
@private
    id <SBMetadataSearchControllerDelegate> delegate;

    NSString    *_searchString;

    NSDictionary                 *detailBoldAttr;

    IBOutlet NSTabView           *searchMode;
    
    IBOutlet NSTextField         *movieName;
    IBOutlet NSPopUpButton       *movieLanguage;
	IBOutlet NSPopUpButton       *movieMetadataProvider;
    
    IBOutlet NSComboBox          *tvSeriesName;
    NSMutableArray               *_tvSeriesNameSearchArray;
    IBOutlet NSTextField         *tvSeasonNum;
    IBOutlet NSTextField         *tvEpisodeNum;
    IBOutlet NSPopUpButton       *tvLanguage;
	IBOutlet NSPopUpButton       *tvMetadataProvider;
    
    IBOutlet NSButton            *searchButton;
    MetadataImporter             *_currentSearcher;

    NSArray                      *_resultsArray;
    IBOutlet NSTableView         *resultsTable;
    MP42Metadata                 *_selectedResult;
    NSDictionary                 *_selectedResultTags;
    NSArray                      *_selectedResultTagsArray;
    IBOutlet SBTableView         *metadataTable;

    IBOutlet NSButton            *addButton;

    id                           artworkSelectorWindow;

    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField         *progressText;
    
}

#pragma mark Initialization
- (instancetype)initWithDelegate:(id <SBMetadataSearchControllerDelegate>)del searchString:(NSString *)searchString;

#pragma mark Static methods
+ (void) clearRecentSearches;
+ (void) deleteCachedMetadata;

@end

NS_ASSUME_NONNULL_END
