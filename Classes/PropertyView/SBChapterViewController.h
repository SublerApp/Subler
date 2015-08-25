//
//  ChapterViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42ChapterTrack.h>

NS_ASSUME_NONNULL_BEGIN

@class SBTableView;

@interface SBChapterViewController : NSViewController {
    MP42ChapterTrack *track;

    NSDictionary *detailBoldAttr;

    IBOutlet SBTableView    *chapterTableView;
    IBOutlet NSButton       *removeChapter;
}

- (void) setTrack:(MP42ChapterTrack *)track;
- (IBAction) addChapter: (id) sender;
- (IBAction) removeChapter: (id) sender;
- (IBAction) renameChapters: (id) sender;

@end

NS_ASSUME_NONNULL_END
