//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42AudioTrack;
@class MP42File;

@interface SBSoundViewController : NSViewController {
    MP42AudioTrack *track;
    MP42File       *mp4file;

    NSMutableArray *_fallbacks;
    NSMutableArray *_follows;

    IBOutlet NSSlider *volume;
    IBOutlet NSPopUpButton *alternateGroup;
    IBOutlet NSPopUpButton *fallback;
    IBOutlet NSPopUpButton *follows;
}

- (void)setTrack:(MP42AudioTrack *)soundTrack;
- (void)setFile:(MP42File *)mp4;

- (IBAction)setTrackVolume:(id)sender;
- (IBAction)setAltenateGroup:(id)sender;
- (IBAction)setFallbackTrack:(id)sender;
- (IBAction)setFollowsTrack:(id)sender;

@end
