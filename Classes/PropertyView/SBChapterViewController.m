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

- (void)awakeFromNib
{
    NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setHeadIndent: -10.0];
    [ps setAlignment:NSRightTextAlignment];
    
    detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                       [NSFont boldSystemFontOfSize:11.0], NSFontAttributeName,
                       ps, NSParagraphStyleAttributeName,
                       [NSColor grayColor], NSForegroundColorAttributeName,
                       nil] retain];

    chapterTableView.defaultEditingColumn = 1;
}

- (void)setTrack:(MP42ChapterTrack *)chapterTrack
{
    track = chapterTrack;
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
    MP42TextSample * chapter = [track chapterAtIndex:rowIndex];
    if ([tableColumn.identifier isEqualToString:@"time"])
        return [self boldString:SMPTEStringFromTime(chapter.timestamp, 1000)];  

    if ([tableColumn.identifier isEqualToString:@"title"])
        return chapter.title;

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
        MP42Duration timestamp = TimeFromSMPTEString(anObject, 1000);
        if (!(chapter.timestamp == timestamp)) {
            [track setTimestamp:timestamp forChapter:chapter];

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([chapterTableView selectedRow] != -1)
        [removeChapter setEnabled:YES];
    else
        [removeChapter setEnabled:NO];
}

- (IBAction)removeChapter:(id)sender {
    NSUInteger current_index = [chapterTableView selectedRow];
    if (current_index < [track chapterCount]) {
        [track removeChapterAtIndex:current_index];

        [chapterTableView reloadData];
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction)addChapter:(id)sender {
    [track addChapter:@"Chapter" duration:0];

    [chapterTableView reloadData];
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
}

- (void)dealloc
{
    [detailBoldAttr release];
    [super dealloc];
}

@end
