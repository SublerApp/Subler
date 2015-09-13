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

/**
 *  A SBMediaTagsControllert takes a MP42Track in input,
 *  and show a windows to configure the media characteristic tags
 *  of the input track. The new set of tags is added to the track
 *  after the user press the OK button.
 *
 *  Custom media tags are preserved.
 */
@interface SBMediaTagsController : NSWindowController {
    @private
    MP42Track *_track;
    NSArray<SBMediaTag *> *_tags;

    IBOutlet NSTableView *_tableView;
}

/**
 *  Initializes an SBMediaTagsController with the tags
 *  from the provided track.
 *
 *  @param track the track
 *
 *  @return an SBMediaTagsController.
 */
- (instancetype)initWithTrack:(MP42Track *)track;

@end

NS_ASSUME_NONNULL_END
