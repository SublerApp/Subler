//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBSoundViewController.h"
#import "SBMediaTagsController.h"

#import <MP42Foundation/MP42File.h>

@implementation SBSoundViewController

- (void)loadView
{
    [super loadView];

    // Media Tags controls
    _mediaTagsController = [[SBMediaTagsController alloc] initWithTrack:track];

    (_mediaTagsController.view).frame = mediaTagsView.bounds;
    (_mediaTagsController.view).autoresizingMask = ( NSViewWidthSizable | NSViewHeightSizable );

    [mediaTagsView addSubview:_mediaTagsController.view];

    // Standard audio controls
    [alternateGroup selectItemAtIndex:(NSInteger)track.alternate_group];

    _fallbacks = [[NSMutableArray alloc] init];

    if ([track.format isEqualToString:MP42AudioFormatAC3] ||
        [track.format isEqualToString:MP42AudioFormatEAC3]) {
        NSInteger i = 1;
        NSInteger selectedItem = 0;

        for (MP42AudioTrack *fileTrack in [mp4file tracksWithMediaType:MP42MediaTypeAudio]) {
            if ([fileTrack.format isEqualToString:MP42AudioFormatAAC]) {
                NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ - %@ - %@",
                                                                          fileTrack.trackId ? [NSString stringWithFormat:@"%d", fileTrack.trackId] : @"na",
                                                                          fileTrack.name,
                                                                          fileTrack.language]
                                                                  action:@selector(setFallbackTrack:)
                                                           keyEquivalent:@""];
                newItem.target = self;
                newItem.tag = i;
                [fallback.menu addItem:newItem];
                [_fallbacks addObject:fileTrack];
                
                if (track.fallbackTrack == fileTrack)
                    selectedItem = i;

                i++;
            }
        }
        [fallback selectItemWithTag:selectedItem];
    }
    else {
        [fallback setEnabled:NO];
    }

    _follows = [[NSMutableArray alloc] init];

    NSInteger i = 1;
    NSInteger selectedItem = 0;

    for (MP42SubtitleTrack *fileTrack in [mp4file tracksWithMediaType:MP42MediaTypeSubtitle]) {
        NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ - %@ - %@",
                                                                  fileTrack.trackId ? [NSString stringWithFormat:@"%d", fileTrack.trackId] : @"na",
                                                                  fileTrack.name,
                                                                  fileTrack.language]
                                                          action:@selector(setFollowsTrack:)
                                                   keyEquivalent:@""];
        newItem.target = self;
        newItem.tag = i;
        [follows.menu addItem:newItem];
        [_follows addObject:fileTrack];

        if (track.followsTrack == fileTrack)
            selectedItem = i;

        i++;
    }

    [follows selectItemWithTag:selectedItem];

    volume.floatValue = track.volume * 100;
}

- (void)setFile:(MP42File *)mp4
{
    mp4file = mp4;
}

- (void)setTrack:(MP42AudioTrack *)soundTrack
{
    track = soundTrack;
}

- (IBAction)setTrackVolume:(id)sender
{
    float value = [sender floatValue] / 100;
    if (track.volume != value) {
        track.volume = value;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setFallbackTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42AudioTrack *audioTrack = _fallbacks[index-1];

        if (audioTrack != track.fallbackTrack) {
            track.fallbackTrack = audioTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        track.fallbackTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setFollowsTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42SubtitleTrack *subTrack = _follows[index-1];

        if (subTrack != track.followsTrack) {
            track.followsTrack = subTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        track.followsTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setAltenateGroup:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    
    if (track.alternate_group != tagName) {
        track.alternate_group = tagName;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

@end
