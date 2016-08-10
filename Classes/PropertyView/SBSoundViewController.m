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
{
    NSMutableArray<MP42AudioTrack *> *_fallbacks;
    NSMutableArray<__kindof MP42Track *> *_follows;

    NSViewController *_mediaTagsController;

    IBOutlet NSView *mediaTagsView;
    IBOutlet NSSlider *volume;
    IBOutlet NSPopUpButton *alternateGroup;
    IBOutlet NSPopUpButton *fallback;
    IBOutlet NSPopUpButton *follows;
}

- (void)loadView
{
    [super loadView];

    // Media Tags controls
    _mediaTagsController = [[SBMediaTagsController alloc] initWithTrack:self.soundTrack];

    (_mediaTagsController.view).frame = mediaTagsView.bounds;
    (_mediaTagsController.view).autoresizingMask = ( NSViewWidthSizable | NSViewHeightSizable );

    [mediaTagsView addSubview:_mediaTagsController.view];

    // Standard audio controls
    [alternateGroup selectItemAtIndex:(NSInteger)self.soundTrack.alternate_group];

    _fallbacks = [[NSMutableArray alloc] init];

    if (self.soundTrack.format == kMP42AudioCodecType_AC3 ||
        self.soundTrack.format == kMP42AudioCodecType_EnhancedAC3) {
        NSInteger i = 1;
        NSInteger selectedItem = 0;

        for (MP42AudioTrack *fileTrack in [self.file tracksWithMediaType:kMP42MediaType_Audio]) {
            if (fileTrack.format == kMP42AudioCodecType_MPEG4AAC ||
                fileTrack.format == kMP42AudioCodecType_MPEG4AAC_HE) {
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
                
                if (self.soundTrack.fallbackTrack == fileTrack) {
                    selectedItem = i;
                }

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

    for (MP42SubtitleTrack *fileTrack in [self.file tracksWithMediaType:kMP42MediaType_Subtitle]) {
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

        if (self.soundTrack.followsTrack == fileTrack) {
            selectedItem = i;
        }

        i++;
    }

    [follows selectItemWithTag:selectedItem];

    volume.floatValue = self.soundTrack.volume * 100;
}

- (IBAction)setTrackVolume:(id)sender
{
    float value = [sender floatValue] / 100;
    if (self.soundTrack.volume != value) {
        self.soundTrack.volume = value;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setFallbackTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42AudioTrack *audioTrack = _fallbacks[index-1];

        if (audioTrack != self.soundTrack.fallbackTrack) {
            self.soundTrack.fallbackTrack = audioTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        self.soundTrack.fallbackTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setFollowsTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42SubtitleTrack *subTrack = _follows[index-1];

        if (subTrack != self.soundTrack.followsTrack) {
            self.soundTrack.followsTrack = subTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        self.soundTrack.followsTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setAltenateGroup:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    
    if (self.soundTrack.alternate_group != tagName) {
        self.soundTrack.alternate_group = tagName;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

@end
