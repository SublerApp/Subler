//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBVideoViewController.h"
#import "SBMediaTagsController.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42Languages.h>

@interface SBVideoViewController ()

@property (nonatomic, strong) IBOutlet NSView *forcedView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *forcedHeight;

@property (nonatomic, strong) IBOutlet NSView *profileView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *profileHeight;

@property (nonatomic, strong) IBOutlet NSView *colorView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *colorHeight;

@property (nonatomic, weak) IBOutlet NSPopUpButton *colorProfilePopUp;

@end

@implementation SBVideoViewController
{
    MP42VideoTrack *track;
    MP42File       *mp4file;

    NSViewController *_mediaTagsController;

    IBOutlet NSView *mediaTagsView;

    IBOutlet NSTextField *sampleWidth;
    IBOutlet NSTextField *sampleHeight;

    IBOutlet NSTextField *trackWidth;
    IBOutlet NSTextField *trackHeight;

    IBOutlet NSTextField *hSpacing;
    IBOutlet NSTextField *vSpacing;

    IBOutlet NSTextField *offsetX;
    IBOutlet NSTextField *offsetY;

    IBOutlet NSPopUpButton *alternateGroup;

    IBOutlet NSPopUpButton *videoProfile;

    IBOutlet NSPopUpButton *forcedSubs;
    IBOutlet NSPopUpButton *forced;

    IBOutlet NSButton *preserveAspectRatio;

    IBOutlet NSMenuItem *profileLevelUnchanged;
    
    NSMutableArray<MP42SubtitleTrack *> *_forced;
}

static NSString *getProfileName(uint8_t profile) {
    switch (profile) {
        case 66:
            return @"Baseline";
        case 77:
            return @"Main";
        case 88:
            return @"Extended";
        case 100:
            return @"High";
        case 110:
            return @"High 10";
        case 122:
            return @"High 4:2:2";
        case 144:
            return @"High 4:4:4";
        default:
            return @"Unknown profile";
    }
}

static NSString *getLevelName(uint8_t level) {
    switch (level) {
        case 10:
        case 20:
        case 30:
        case 40:
        case 50:
            return [NSString stringWithFormat:@"%u", level/10];
        case 11:
        case 12:
        case 13:
        case 21:
        case 22:
        case 31:
        case 32:
        case 41:
        case 42:
        case 51:
            return [NSString stringWithFormat:@"%u.%u", level/10, level % 10];
        default:
            return [NSString stringWithFormat:@"unknown level %x", level];
    }
}

static NSString *getColorProfileName(uint16_t colorPrimaries,
                                     uint16_t transferCharacteristics,
                                     uint16_t matrixCoefficients) {
    if (colorPrimaries == 0 && transferCharacteristics == 0 && matrixCoefficients == 0) {
        return NSLocalizedString(@"Implicit", @"Implicit color profile");
    }
    else if (colorPrimaries == 1 && transferCharacteristics == 1 && matrixCoefficients == 1) {
        return NSLocalizedString(@"Rec. 709 (1-1-1)", @"Implicit color profile");
    }
    else if (colorPrimaries == 9 && transferCharacteristics == 1 && matrixCoefficients == 9) {
        return NSLocalizedString(@"Rec. 2020 (9-1-9)", @"color profile");
    }
    if (colorPrimaries == 5 && transferCharacteristics == 1 && matrixCoefficients == 6) {
        return NSLocalizedString(@"Rec. 601 (5-1-6)", @"color profile");
    }
    if (colorPrimaries == 6 && transferCharacteristics == 1 && matrixCoefficients == 6) {
        return NSLocalizedString(@"Rec. 601 (6-1-6)", @"color profile");
    }
    return [NSString stringWithFormat:@"%d-%d-%d", colorPrimaries, transferCharacteristics, matrixCoefficients];
}

- (void)loadView
{
    [super loadView];

    _mediaTagsController = [[SBMediaTagsController alloc] initWithTrack:track];

    (_mediaTagsController.view).frame = mediaTagsView.bounds;
    (_mediaTagsController.view).autoresizingMask = ( NSViewWidthSizable | NSViewHeightSizable );

    [mediaTagsView addSubview:_mediaTagsController.view];

    sampleWidth.stringValue = [NSString stringWithFormat:@"%lld", track.width];
    sampleHeight.stringValue = [NSString stringWithFormat:@"%lld", track.height];
    
    trackWidth.stringValue = [NSString stringWithFormat:@"%d", (uint16_t)track.trackWidth];
    trackHeight.stringValue = [NSString stringWithFormat:@"%d", (uint16_t)track.trackHeight];

    hSpacing.stringValue = [NSString stringWithFormat:@"%lld", track.hSpacing];
    vSpacing.stringValue = [NSString stringWithFormat:@"%lld", track.vSpacing];

    offsetX.stringValue = [NSString stringWithFormat:@"%d", track.offsetX];
    offsetY.stringValue = [NSString stringWithFormat:@"%d", track.offsetY];
    
    [alternateGroup selectItemAtIndex:(NSInteger)track.alternateGroup];

    if (track.format == kMP42VideoCodecType_H264 && track.origProfile && track.origLevel) {
        profileLevelUnchanged.title = [NSString stringWithFormat:@"%@ %@ @ %@", NSLocalizedString(@"Current profile:", nil),
                                         getProfileName(track.origProfile), getLevelName(track.origLevel)];
        if ((track.origProfile == track.newProfile) && (track.origLevel == track.newLevel)) {
            [videoProfile selectItemWithTag:1];
        } else {
            if ((track.newProfile == 66) && (track.newLevel == 21)) {
                [videoProfile selectItemWithTag:6621];
            } else if ((track.newProfile == 77) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:7731];
            } else if ((track.newProfile == 100) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:10031];
            } else if ((track.newProfile == 100) && (track.newLevel == 41)) {
                [videoProfile selectItemWithTag:10041];
            }
        }
    } else {
        self.profileView.hidden = YES;
        self.profileHeight.constant = 0;
    }

    if (track.format == kMP42VideoCodecType_H264 || track.format == kMP42VideoCodecType_MPEG4Video ||
        track.format == kMP42VideoCodecType_HEVC || track.format == kMP42VideoCodecType_HEVC_PSinBitstream) {
        NSString *colorProfile = getColorProfileName(track.colorPrimaries, track.transferCharacteristics, track.matrixCoefficients);
        [self.colorProfilePopUp selectItemWithTitle:colorProfile];

        if (self.colorProfilePopUp.indexOfSelectedItem == -1) {
            [self.colorProfilePopUp addItemWithTitle:colorProfile];
            [self.colorProfilePopUp selectItemWithTitle:colorProfile];
        }
    }
    else {
        self.colorView.hidden = YES;
        self.colorHeight.constant = 0;
    }

    if ([track isKindOfClass:[MP42SubtitleTrack class]]) {
        MP42SubtitleTrack * subTrack = (MP42SubtitleTrack*)track;

        if (!subTrack.someSamplesAreForced && !subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:0];
        } else if (subTrack.someSamplesAreForced && !subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:1];
        } else if (subTrack.allSamplesAreForced) {
            [forcedSubs selectItemWithTag:2];
        }

        _forced = [[NSMutableArray alloc] init];

        NSInteger i = 1;
        NSInteger selectedItem = 0;
        for (MP42SubtitleTrack *fileTrack in [mp4file tracksWithMediaType:kMP42MediaType_Subtitle]) {
            NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ - %@ - %@",
                                                                      fileTrack.trackId ? [NSString stringWithFormat:@"%d", fileTrack.trackId] : @"NA",
                                                                      fileTrack.name,
                                                                      [MP42Languages.defaultManager localizedLangForExtendedTag:fileTrack.language]]
                                                              action:@selector(setForcedTrack:)
                                                       keyEquivalent:@""];
            newItem.target = self;
            newItem.tag = i;
            [forced.menu addItem:newItem];
            [_forced addObject:fileTrack];

            if (((MP42SubtitleTrack *)track).forcedTrack == fileTrack)
                selectedItem = i;

            i++;
        }

        [forced selectItemWithTag:selectedItem];
    }
    else {
        self.forcedView.hidden = YES;
        self.forcedHeight.constant = 0;
    }
}

- (void)setTrack:(MP42VideoTrack *)videoTrack
{
    track = videoTrack;
}

- (void)setFile:(MP42File *)mp4
{
    mp4file = mp4;
}

- (IBAction)setSize:(id)sender
{
    NSInteger i;

    if (sender == trackWidth) {
        i = trackWidth.integerValue;
        if (track.trackWidth != i) {
            if (preserveAspectRatio.state == NSOnState) {
                track.trackHeight = (track.trackHeight / track.trackWidth) * i;
                trackHeight.integerValue = (NSInteger)track.trackHeight;
            }
            track.trackWidth = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else if (sender == trackHeight) {
        i = trackHeight.integerValue;
        if (track.trackHeight != i) {
            track.trackHeight = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else if (sender == offsetX) {
        i = offsetX.integerValue;
        if (track.offsetX != i) {
            track.offsetX = (uint32_t)i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else if (sender == offsetY) {
        i = offsetY.integerValue;
        if (track.offsetY != i) {
            track.offsetY = (uint32_t)i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
}

- (IBAction)setPixelAspect:(id)sender
{
    NSInteger i;
    
    if (sender == hSpacing) {
        i = hSpacing.integerValue;
        if (track.hSpacing != i) {
            track.hSpacing = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else if (sender == vSpacing) {
        i = vSpacing.integerValue;
        if (track.vSpacing != i) {
            track.vSpacing = i;

            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
}

- (IBAction)setAltenateGroup:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    
    if (track.alternateGroup != tagName) {
        track.alternateGroup = tagName;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setColorProfile:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    switch (tagName) {
        case 1:
            track.colorPrimaries = 0;
            track.transferCharacteristics = 0;
            track.matrixCoefficients = 0;
            break;
        case 2:
            track.colorPrimaries = 5;
            track.transferCharacteristics = 1;
            track.matrixCoefficients = 6;
            break;
        case 3:
            track.colorPrimaries = 6;
            track.transferCharacteristics = 1;
            track.matrixCoefficients = 6;
            break;
        case 4:
            track.colorPrimaries = 1;
            track.transferCharacteristics = 1;
            track.matrixCoefficients = 1;
            break;
        case 5:
            track.colorPrimaries = 9;
            track.transferCharacteristics = 1;
            track.matrixCoefficients = 9;
            break;
        default:
            return;
    }

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

- (IBAction)setProfileLevel:(id)sender
{
    NSInteger tagName = [sender selectedItem].tag;
    switch (tagName) {
        case 1:
            track.newProfile = track.origProfile;
            track.newLevel = track.origLevel;
            return;
        case 6621:
            track.newProfile = 66;
            track.newLevel = 21;
            break;
        case 7731:
            track.newProfile = 77;
            track.newLevel = 31;
            break;
        case 10031:
            track.newProfile = 100;
            track.newLevel = 31;
            break;
        case 10041:
            track.newProfile = 100;
            track.newLevel = 41;
            break;
        default:
            return;
    }

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

- (IBAction)setForcedSubtitles:(id)sender
{
    if ([track isKindOfClass:[MP42SubtitleTrack class]]) {
        MP42SubtitleTrack *subTrack = (MP42SubtitleTrack *)track;
        NSInteger tagName = [sender selectedItem].tag;

        switch (tagName) {
            case 0:
                subTrack.someSamplesAreForced = NO;
                subTrack.allSamplesAreForced = NO;
                break;
            case 1:
                subTrack.someSamplesAreForced = YES;
                subTrack.allSamplesAreForced = NO;
                break;
            case 2:
                subTrack.someSamplesAreForced = YES;
                subTrack.allSamplesAreForced = YES;
                break;
            default:
                return;
        }

        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}

- (IBAction)setForcedTrack:(id)sender
{
    NSInteger index = [sender tag];

    if (index) {
        MP42SubtitleTrack *subTrack = _forced[index-1];

        if (subTrack != ((MP42SubtitleTrack *)track).forcedTrack) {
            ((MP42SubtitleTrack *)track).forcedTrack = subTrack;
            [self.view.window.windowController.document updateChangeCount:NSChangeDone];
        }
    }
    else {
        ((MP42SubtitleTrack *)track).forcedTrack = nil;
        [self.view.window.windowController.document updateChangeCount:NSChangeDone];
    }
}


@end
