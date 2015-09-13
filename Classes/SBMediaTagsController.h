//
//  SBMediaTagsController.h
//  Subler
//
//  Created by Damiano Galassi on 12/09/15.
//
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42Track;
@class SBMediaTag;

@interface SBMediaTagsController : NSWindowController {
    @private
    MP42Track *_track;
    NSArray<SBMediaTag *> *_tags;

    IBOutlet NSTableView *_tableView;
}

- (instancetype)initWithTrack:(MP42Track *)track;

@end

NS_ASSUME_NONNULL_END
