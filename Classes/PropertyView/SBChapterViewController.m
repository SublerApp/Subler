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

- (void)loadView
{
    [super loadView];

    NSMutableParagraphStyle *ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setHeadIndent: -10.0];
    [ps setAlignment:NSRightTextAlignment];

    detailBoldAttr = [@{ NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightBold],
                        NSParagraphStyleAttributeName: ps,
                        NSForegroundColorAttributeName: [NSColor grayColor] } retain];

    chapterTableView.defaultEditingColumn = 1;
}

- (void)setTrack:(MP42ChapterTrack *)chapterTrack
{
    track = [chapterTrack retain];
}

- (NSAttributedString *)boldString:(NSString *)string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)t
{
    return [track chapterCount];
}

- (id)              tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)rowIndex
{
    MP42TextSample *chapter = [track chapterAtIndex:rowIndex];

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
    MP42TextSample * chapter = [track chapterAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"title"]) {
        if (![chapter.title isEqualToString:anObject]) {
            [track setTitle:anObject forChapter:chapter];

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"time"]) {
        MP42Duration timestamp = TimeFromString(anObject, 1000);
        if (!(chapter.timestamp == timestamp)) {
            [track setTimestamp:timestamp forChapter:chapter];
            [chapterTableView reloadData];

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([chapterTableView selectedRow] != -1) {
        [removeChapter setEnabled:YES];
    }
    else {
        [removeChapter setEnabled:NO];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"time"]) {
        if ([[tableView selectedRowIndexes] containsIndex:rowIndex]) {
            // Without this, the color won't change because
            // we are using a attributed string.
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:[cell attributedStringValue]];
            [highlightedString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [highlightedString length])];
            [cell setAttributedStringValue:highlightedString];
            [highlightedString release];

            [cell setTextColor:[NSColor blackColor]];
        }
        else {
            [cell setTextColor:[NSColor grayColor]];
        }
    }
}

- (IBAction)removeChapter:(id)sender {
    NSInteger current_index = [chapterTableView selectedRow];
    if (current_index < [track chapterCount]) {
        [track removeChapterAtIndex:current_index];

        [chapterTableView reloadData];
        [[[[[self view] window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction)addChapter:(id)sender {
    [track addChapter:@"Chapter" duration:0];

    [chapterTableView reloadData];
    [[[[[self view] window] windowController] document] updateChangeCount:NSChangeDone];
}

- (IBAction)renameChapters:(id)sender {
    [track.chapters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *title = [NSString stringWithFormat:@"Chapter %lu", (unsigned long) idx + 1];
        [track setTitle:title forChapter:(MP42TextSample *)obj];
    }];

    [chapterTableView reloadData];
    [[[[[self view] window] windowController] document] updateChangeCount:NSChangeDone];
}

- (void)dealloc
{
    [track release];
    [detailBoldAttr release];

    [super dealloc];
}

@end
