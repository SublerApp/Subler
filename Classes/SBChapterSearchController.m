//
//  SBChapterSearchController.m
//  Subler
//
//  Created by Michael Hueber on 20.11.15.
//
//

#import "SBChapterSearchController.h"

#import <MP42Foundation/MP42Utilities.h>

#import "SBTableView.h"
#import "SBChapterImporter.h"
#import "SBChapterResult.h"

@interface SBChapterSearchController () <NSTableViewDelegate>
{
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

@property (nonatomic, readwrite, strong) SBChapterImporter *currentSearcher;
@property (nonatomic, readwrite, strong) NSArray<SBChapterResult *> *resultsArray;
@property (nonatomic, readwrite, strong) NSArray<MP42TextSample *> *selectedChaptersArray;

@end

@implementation SBChapterSearchController

- (instancetype)initWithDelegate:(id <SBChapterSearchControllerDelegate>)del searchTitle:(NSString *)title andDuration:(NSUInteger)duration
{
    self = [super initWithWindowNibName:@"SBChapterSearch"];

    if (self) {
        delegate = del;
        _searchString = [title copy];
        _searchDuration = duration;

        [self setupFontAttributes];

        [self updateSearchButtonVisibility];

        if (searchButton.enabled) {
            [self searchForResults:nil];
        }
    }

    return self;
}

- (void)setupFontAttributes
{
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    ps.headIndent = -10.0;
    ps.alignment = NSTextAlignmentRight;

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        _detailBoldMonospacedAttr = @{NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightBold],
                                       NSParagraphStyleAttributeName: ps,
                                       NSForegroundColorAttributeName: [NSColor grayColor]};
    }
    else {
        _detailBoldMonospacedAttr = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]],
                                       NSParagraphStyleAttributeName: ps,
                                       NSForegroundColorAttributeName: [NSColor grayColor]};
    }

    NSMutableParagraphStyle *psL = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    psL.headIndent = -10.0;
    psL.alignment = NSTextAlignmentLeft;

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        _detailBoldAttr = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightBold],
                             NSParagraphStyleAttributeName: psL,
                             NSForegroundColorAttributeName: [NSColor grayColor]};
    }
    else {
        _detailBoldAttr = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]],
                                       NSParagraphStyleAttributeName: ps,
                                       NSForegroundColorAttributeName: [NSColor grayColor]};
    }

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        _detailMonospacedAttr = @{NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightRegular],
                                   NSParagraphStyleAttributeName: ps};
    }
    else {
        _detailMonospacedAttr = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]],
                                   NSParagraphStyleAttributeName: ps};
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.window makeFirstResponder:searchTitle];

    if (_searchString) {
        NSDictionary<NSString *, NSString *>  *parsed = [SBMetadataHelper parseFilename:_searchString];
        if (parsed) {
            if ([@"movie" isEqualToString:parsed[@"type"]]) {
                if (parsed[@"title"]) {
                    searchTitle.stringValue = [parsed valueForKey:@"title"];
                }
            }
            else if ([@"tv" isEqualToString:parsed[@"type"]]) {
                searchTitle.stringValue = _searchString.stringByDeletingPathExtension;
            }

            [self updateSearchButtonVisibility];

            if (searchButton.enabled) {
                [self searchForResults:nil];
            }
        }
    }
}


#pragma mark - Search for results

- (IBAction)searchForResults:(id)sender
{
    [addButton setEnabled:NO];

    if (self.currentSearcher) {
        [self.currentSearcher cancel];
    }

    if (searchTitle.stringValue.length) {

        [self startProgressReportWithString:[NSString stringWithFormat:@"Searching %@ for chapter information…", @"ChapterDB"]];

        self.currentSearcher = [SBChapterImporter importerForProvider:[SBChapterImporter defaultProvider]];

        [self.currentSearcher searchTitle:searchTitle.stringValue
                                 language:nil
                                 duration:_searchDuration
                        completionHandler:^(NSArray<SBChapterResult *> *results) {
                            [self searchForResultsDone:results];
                        }];

    }
    else {
        // Nothing to search, reset the table view
        self.resultsArray = nil;
        self.selectedChaptersArray = nil;
        [resultsTable reloadData];
        [chapterTable reloadData];
    }
}

- (void)searchForResultsDone:(NSArray<SBChapterResult *> *)results
{
    self.resultsArray = nil;

    [self stopProgressReport];

    self.resultsArray = results;
    self.selectedChaptersArray = nil;

    [resultsTable reloadData];
    [chapterTable reloadData];

    [self tableViewSelectionDidChange:[NSNotification notificationWithName:@"tableViewSelectionDidChange" object:resultsTable]];

    if (self.resultsArray.count) {
        [self.window makeFirstResponder:resultsTable];
    }
}

#pragma mark - Search input fields

- (void)updateSearchButtonVisibility
{
    if (searchTitle.stringValue.length > 0) {
        [searchButton setEnabled:YES];
        return;
    }

    [searchButton setEnabled:NO];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    [self updateSearchButtonVisibility];
    addButton.keyEquivalent = @"";
    searchButton.keyEquivalent = @"\r";
}

#pragma mark - Finishing up

- (IBAction)addChapter:(id)sender
{
    [self addChapterTrack];
}

- (void) addChapterTrack
{
    [delegate chapterImportDone:self.selectedChaptersArray];

    [chapterTable setDelegate:nil];
    [chapterTable setDataSource:nil];
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];

    [NSApp endSheet:self.window returnCode:1];
}


- (IBAction)closeWindow:(id)sender
{
    [resultsTable setDelegate:nil];
    [resultsTable setDataSource:nil];

    [NSApp endSheet:self.window returnCode:0];
}

#pragma mark - Progress

- (void)startProgressReportWithString:(NSString *)progressString
{
    [progress startAnimation:self];
    [progress setHidden:NO];
    progressText.stringValue = progressString;
    [progressText setHidden:NO];

    [resultsTable setEnabled:NO];
    [chapterTable setEnabled:NO];
}

- (void)stopProgressReport
{
    [progress setHidden:YES];
    [progressText setHidden:YES];
    [progress stopAnimation:self];

    [resultsTable setEnabled:YES];
    [chapterTable setEnabled:YES];
}


#pragma mark - Miscellaneous

- (NSAttributedString *)boldString:(NSString *)string monospaced:(BOOL)monospaced
{
    if (monospaced) {
        return [[NSAttributedString alloc] initWithString:string attributes:_detailBoldMonospacedAttr];
    }
    return [[NSAttributedString alloc] initWithString:string attributes:_detailBoldAttr];
}

- (NSAttributedString *)monospacedString:(NSString *)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:_detailMonospacedAttr];

}

#pragma mark -

#pragma mark NSTableView delegates and protocols

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == resultsTable) {
        return self.resultsArray.count;
    }
    else if (tableView == (NSTableView *) chapterTable) {
        return self.selectedChaptersArray.count;
    }
    return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if (tableView == resultsTable) {
        if (self.resultsArray != nil) {
            SBChapterResult *result = self.resultsArray[rowIndex];

            if ([tableColumn.identifier isEqualToString:@"title"]) {
                return result.title;
            }
            else if ([tableColumn.identifier isEqualToString:@"chaptercount"]) {
                return [self monospacedString:@(result.chapters.count).stringValue];
            }
            else if ([tableColumn.identifier isEqualToString:@"duration"]) {
                return [self monospacedString:StringFromTime(result.duration, 1000)];
            }
            else if ([tableColumn.identifier isEqualToString:@"confirmations"]) {
                return @(result.confirmations);
            }
        }
    }
    else if (tableView == (NSTableView *)chapterTable) {
        if (self.selectedChaptersArray != nil) {
            MP42TextSample *chapter = (self.selectedChaptersArray)[rowIndex];

            if ([tableColumn.identifier isEqualToString:@"time"]) {
                return [self boldString:StringFromTime(chapter.timestamp, 1000) monospaced:YES];
            }
            else if ([tableColumn.identifier isEqualToString:@"name"]) {
                return chapter.title;
            }
        }
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if (aNotification.object == resultsTable || aNotification.object ==  chapterTable) {
        if (self.resultsArray && (self.resultsArray).count > 0 && resultsTable.selectedRow > -1) {

            self.selectedChaptersArray = self.resultsArray[resultsTable.selectedRow].chapters;

            [chapterTable reloadData];
            [addButton setEnabled:YES];
            addButton.keyEquivalent = @"\r";
            searchButton.keyEquivalent = @"";
        }
    }
    else {
        [addButton setEnabled:NO];
        addButton.keyEquivalent = @"";
        searchButton.keyEquivalent = @"\r";
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"time"]) {
        if ([tableView.selectedRowIndexes containsIndex:rowIndex]) {

            // Without this, the color won't change ...
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedStringValue]];
            [highlightedString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, highlightedString.length)];
            [cell setAttributedStringValue:highlightedString];

            [cell setTextColor:[NSColor blackColor]];
        } else {
            [cell setTextColor:[NSColor grayColor]];
        }
    }
}

@end
