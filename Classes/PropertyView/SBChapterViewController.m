//
//  ChapterViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBChapterViewController.h"
#import "SBTableView.h"

#import <MP42Foundation/MP42Utilities.h>

@implementation SBChapterViewController
{
    NSDictionary *detailBoldAttr;

    IBOutlet SBTableView    *chapterTableView;
    IBOutlet NSButton       *removeChapter;
}

- (void)loadView
{
    [super loadView];

    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    ps.headIndent = -10.0;
    ps.alignment = NSTextAlignmentRight;

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        detailBoldAttr = @{ NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightBold],
                             NSParagraphStyleAttributeName: ps,
                             NSForegroundColorAttributeName: [NSColor grayColor] };
    }
    else {
        detailBoldAttr = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]],
                             NSParagraphStyleAttributeName: ps,
                             NSForegroundColorAttributeName: [NSColor grayColor] };
    }

    chapterTableView.defaultEditingColumn = 1;
}

- (NSAttributedString *)boldString:(NSString *)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)t
{
    return [self.track chapterCount];
}

- (id)              tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)rowIndex
{
    MP42TextSample *chapter = [self.track chapterAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"time"]) {
        return [self boldString:StringFromTime(chapter.timestamp, 1000)];
    }

    if ([tableColumn.identifier isEqualToString:@"title"]) {
        return chapter.title;
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    MP42TextSample *chapter = [self.track chapterAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"title"]) {
        if (![chapter.title isEqualToString:anObject]) {
            [self.track setTitle:anObject forChapter:chapter];

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"time"]) {
        MP42Duration timestamp = TimeFromString(anObject, 1000);
        if (!(chapter.timestamp == timestamp)) {
            [self.track setTimestamp:timestamp forChapter:chapter];
            [chapterTableView reloadData];

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (chapterTableView.selectedRow != -1) {
        [removeChapter setEnabled:YES];
    }
    else {
        [removeChapter setEnabled:NO];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"time"]) {
        if ([tableView.selectedRowIndexes containsIndex:rowIndex]) {
            // Without this, the color won't change because
            // we are using a attributed string.
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedStringValue]];
            [highlightedString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, highlightedString.length)];
            [cell setAttributedStringValue:highlightedString];

            [cell setTextColor:[NSColor blackColor]];
        }
        else {
            [cell setTextColor:[NSColor grayColor]];
        }
    }
}

- (IBAction)removeChapter:(id)sender {
    NSInteger current_index = chapterTableView.selectedRow;
    if (current_index < [self.track chapterCount]) {
        [self.track removeChapterAtIndex:current_index];

        [chapterTableView reloadData];
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)addChapter:(id)sender {
    [self.track addChapter:@"Chapter" duration:0];

    [chapterTableView reloadData];
    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

- (IBAction)renameChapters:(id)sender {
    [self.track.chapters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *title = [NSString stringWithFormat:@"Chapter %lu", (unsigned long) idx + 1];
        [self.track setTitle:title forChapter:(MP42TextSample *)obj];
    }];

    [chapterTableView reloadData];
    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}


@end
