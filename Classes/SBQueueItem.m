//
//  SBQueueItem.m
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBQueueItem.h"
#import "SBQueueAction.h"

#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Utilities.h>

@interface SBQueueItem ()

@property (nonatomic, readwrite, retain) MP42File *mp4File;
@property (nonatomic, readwrite) NSMutableArray *actions;

@end

@implementation SBQueueItem

@synthesize status = _status;

@synthesize attributes = _attributes;
@synthesize actions = _actions;

@synthesize URL = _fileURL;
@synthesize destURL = _destURL;
@synthesize mp4File = _mp4File;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _actions = [[NSMutableArray alloc] init];
        _status = SBQueueItemStatusReady;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [self init];
    if (self) {
        _fileURL = [URL retain];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[_fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
        if (originalFileSize > 4200000000) {
            _attributes = [[NSDictionary alloc] initWithObjectsAndKeys:@YES, MP4264BitData, nil];
        }
    }

    return self;
}

+ (instancetype)itemWithURL:(NSURL *)URL {
    return [[[SBQueueItem alloc] initWithURL:URL] autorelease];
}

- (id)initWithMP4:(MP42File*)MP4 {
    self = [self init];
    if (self) {
        _mp4File = [MP4 retain];

        if ([MP4 URL]) {
            _fileURL = [[MP4 URL] retain];
        } else {
            for (NSUInteger i = 0; i < [_mp4File tracksCount]; i++) {
                MP42Track *track = [_mp4File trackAtIndex:i];
                if ([track sourceURL]) {
                    _fileURL = [[track sourceURL] retain];
                    break;
                }
            }
        }

        _status = SBQueueItemStatusReady;
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 {
    return [[[SBQueueItem alloc] initWithMP4:MP4] autorelease];
}

- (id)initWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict {
    if (self = [self init]) {
        _mp4File = [MP4 retain];
        _fileURL = [URL copy];
        _destURL = [URL copy];
        _attributes = [dict copy];

        _status = SBQueueItemStatusReady;
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict {
    return [[[SBQueueItem alloc] initWithMP4:MP4 url:URL attributes:dict] autorelease];
}

- (void)setStatus:(SBQueueItemStatus)itemStatus {
    _status = itemStatus;
    if (_status == SBQueueItemStatusCompleted) {
        if (self.mp4File) {
            self.mp4File = nil;
        }
    }
}

- (NSArray *)actionsArray {
    return [self.actions copy];
}

- (void)addAction:(id<SBQueueActionProtocol>)action {
    [self.actions addObject:action];
}

- (BOOL)prepareItem:(NSError **)outError {
    NSString *type;
    [self.URL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:outError];

    if ([type isEqualToString:@"com.apple.m4a-audio"] || [type isEqualToString:@"com.apple.m4v-video"] || [type isEqualToString:@"public.mpeg-4"]) {
       self.mp4File = [[[MP42File alloc] initWithExistingFile:self.URL andDelegate:nil] autorelease];
    } else {
        self.mp4File = [[[MP42File alloc] initWithDelegate:nil] autorelease];
        MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithURL:self.URL error:outError];

        for (MP42Track *track in fileImporter.tracks) {
            if ([track.format isEqualToString:MP42AudioFormatAC3]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue]) {
                    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepAC3"] boolValue] ||
                        ![(MP42AudioTrack *)track fallbackTrack]) {
                        MP42AudioTrack *copy = [track copy];
                        [copy setNeedConversion:YES];
                        [copy setMixdownType:SBDolbyPlIIMixdown];

                        [(MP42AudioTrack *)track setFallbackTrack:copy];

                        [self.mp4File addTrack:copy];

                        [copy release];
                    } else {
                        track.needConversion = YES;
                    }
                }
            }

            if ([track.format isEqualToString:MP42AudioFormatDTS] ||
                ([track.format isEqualToString:MP42SubtitleFormatVobSub] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue]))
                track.needConversion = YES;

            if (isTrackMuxable(track.format) || trackNeedConversion(track.format))
                [self.mp4File addTrack:track];
        }
        [fileImporter release];
    }

    for (id<SBQueueActionProtocol> action in self.actions) {
        [action runAction:self];
    }

    return YES;
}

- (void)dealloc {
    [_attributes release];
    [_actions release];
    [_fileURL release];
    [_destURL release];
    [_mp4File release];
    
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:2 forKey:@"SBQueueItemTagEncodeVersion"];

    [coder encodeObject:_mp4File forKey:@"SBQueueItemMp4File"];
    [coder encodeObject:_fileURL forKey:@"SBQueueItemFileURL"];
    [coder encodeObject:_destURL forKey:@"SBQueueItemDestURL"];
    [coder encodeObject:_attributes forKey:@"SBQueueItemAttributes"];
    [coder encodeObject:_actions forKey:@"SBQueueItemActions"];

    [coder encodeInt:_status forKey:@"SBQueueItemStatus"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];

    _mp4File = [[decoder decodeObjectForKey:@"SBQueueItemMp4File"] retain];

    _fileURL = [[decoder decodeObjectForKey:@"SBQueueItemFileURL"] retain];
    _destURL = [[decoder decodeObjectForKey:@"SBQueueItemDestURL"] retain];
    _attributes = [[decoder decodeObjectForKey:@"SBQueueItemAttributes"] retain];
    _actions = [[decoder decodeObjectForKey:@"SBQueueItemActions"] retain];

    _status = [decoder decodeIntForKey:@"SBQueueItemStatus"];

    return self;
}

@end
