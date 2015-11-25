//
//  SBChapterSearchController.h
//  Subler
//
//  Created by Michael Hueber on 20.11.15.
//
//

#import <Cocoa/Cocoa.h>
#import <MP42Foundation/MP42TextSample.h>

NS_ASSUME_NONNULL_BEGIN

@class SBTableView;
@class SBChapterResult;
@class SBChapterImporter;

@protocol SBChapterSearchControllerDelegate

- (void)chapterImportDone:(NSArray<MP42TextSample *> *)chaptersToBeImported;

@end

@interface SBChapterSearchController : NSWindowController {
@private
    id <SBChapterSearchControllerDelegate> delegate;
    
    NSString    *_searchString;
    NSUInteger  _searchDuration;
    
    NSDictionary                 *_detailBoldAttr;
    NSDictionary                 *_detailBoldMonospacedAttr;
    NSDictionary                 *_detailMonospacedAttr;
    
    IBOutlet NSTextField         *searchTitle;
    
    NSArray<SBChapterResult *>   *_resultsArray;
    IBOutlet NSTableView         *resultsTable;
    NSArray                      *_selectedChaptersArray;
    IBOutlet SBTableView         *chapterTable;
    
    
    IBOutlet NSButton            *searchButton;
    IBOutlet NSButton            *addButton;
    
    SBChapterImporter             *_currentSearcher;
    
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField         *progressText;
}

- (instancetype)initWithDelegate:(id <SBChapterSearchControllerDelegate>)del searchTitle:(NSString *)title andDuration:(NSUInteger)duration; 

@end

NS_ASSUME_NONNULL_END
