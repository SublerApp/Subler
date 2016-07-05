//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42AudioTrack;
@class MP42File;

@interface SBSoundViewController : NSViewController

@property (nonatomic, strong, nullable) MP42AudioTrack *soundTrack;
@property (nonatomic, strong, nullable) MP42File *file;

- (IBAction)setTrackVolume:(id)sender;
- (IBAction)setAltenateGroup:(id)sender;
- (IBAction)setFallbackTrack:(id)sender;
- (IBAction)setFollowsTrack:(id)sender;

@end

NS_ASSUME_NONNULL_END
