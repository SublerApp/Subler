//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42File;
@class MP42VideoTrack;

@interface SBVideoViewController : NSViewController

- (void)setTrack:(MP42VideoTrack *)videoTrack;
- (void)setFile:(MP42File *)mp4;

- (IBAction)setSize:(id)sender;
- (IBAction)setPixelAspect:(id)sender;
- (IBAction)setAltenateGroup:(id)sender;

- (IBAction)setProfileLevel:(id)sender;

- (IBAction)setForcedSubtitles:(id)sender;
- (IBAction)setForcedTrack:(id)sender;

@end

NS_ASSUME_NONNULL_END
