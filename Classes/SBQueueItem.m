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

#define ALMOST_4GiB 4000000000

@interface SBQueueItem ()

@property (nonatomic, readwrite) NSString *localizedWorkingDescription;

@property (nonatomic, readwrite, retain) MP42File *mp4File;
@property (nonatomic, readwrite) NSMutableArray *actionsInternal;
@property (atomic) BOOL cancelled;

@end

@implementation SBQueueItem

@synthesize status = _status;
@synthesize localizedWorkingDescription = _localizedWorkingDescription;

@synthesize attributes = _attributes;
@synthesize actionsInternal = _actions;
@synthesize cancelled = _cancelled;

@synthesize URL = _fileURL;
@synthesize destURL = _destURL;
@synthesize mp4File = _mp4File;

@synthesize delegate = _delegate;

#pragma mark Initializers

- (instancetype)init {
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
        _fileURL = [[URL filePathURL] retain];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[_fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

        if (originalFileSize > ALMOST_4GiB) {
            [attributes setObject:@YES forKey:MP4264BitData];
        }

        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue]) {
            [attributes setObject:@YES forKey:MP42GenerateChaptersPreviewTrack];
        }

        _attributes = [attributes copy];
    }

    return self;
}

+ (instancetype)itemWithURL:(NSURL *)URL {
    return [[[SBQueueItem alloc] initWithURL:URL] autorelease];
}

- (instancetype)initWithMP4:(MP42File *)MP4 {
    self = [self init];
    if (self) {
        _mp4File = [MP4 retain];

        _fileURL = [[NSURL fileURLWithPath:[MP4.URL path]] retain];
        _destURL = [[NSURL fileURLWithPath:[MP4.URL path]] retain];

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue]) {
            [attributes setObject:@YES forKey:MP42GenerateChaptersPreviewTrack];
        }

        _attributes = [attributes copy];
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 {
    return [[[SBQueueItem alloc] initWithMP4:MP4] autorelease];
}

- (instancetype)initWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict {
    if (self = [self init]) {
        _mp4File = [MP4 retain];

        _fileURL = [URL copy];
        _destURL = [URL copy];

        _attributes = [dict copy];
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 destinationURL:(NSURL *)destURL attributes:(NSDictionary *)dict {
    return [[[SBQueueItem alloc] initWithMP4:MP4 url:destURL attributes:dict] autorelease];
}

#pragma mark KVO

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
    BOOL automatic = NO;
    if ([theKey isEqualToString:@"actions"]) {
        automatic = NO;
    } else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

#pragma mark Public methods

- (void)setStatus:(SBQueueItemStatus)itemStatus {
    _status = itemStatus;
    if (_status == SBQueueItemStatusCompleted) {
        self.mp4File = nil;
    }
}

- (void)addAction:(id<SBQueueActionProtocol>)action {
    if (self.status != SBQueueItemStatusWorking) {
        [self willChangeValueForKey:@"actions"];
        [self.actionsInternal addObject:action];
        [self didChangeValueForKey:@"actions"];
    }
}

- (void)removeAction:(id<SBQueueActionProtocol>)action {
    if (self.status != SBQueueItemStatusWorking) {
        [self willChangeValueForKey:@"actions"];
        if ([self.actionsInternal containsObject:action]) {
            [self.actionsInternal removeObject:action];
        }
        [self didChangeValueForKey:@"actions"];
    }
}

- (NSArray *)actions {
    return [[self.actionsInternal copy] autorelease];
}

#pragma mark Item processing

- (BOOL)prepare:(NSError **)outError {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.URL path]]) {
        if (outError) {
            NSDictionary *errorDetail = @{ NSLocalizedDescriptionKey : @"File not found",
                                           NSLocalizedRecoverySuggestionErrorKey : @"The source file couldn't be found." };
            *outError = [NSError errorWithDomain:@"SBQueueItemError" code:10 userInfo:errorDetail];
        }
        return NO;
    }

    NSString *type;
    [self.URL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:outError];

    if ([type isEqualToString:@"com.apple.m4a-audio"] || [type isEqualToString:@"com.apple.m4v-video"] || [type isEqualToString:@"public.mpeg-4"]) {
       self.mp4File = [[[MP42File alloc] initWithURL:self.URL] autorelease];
    } else {
        self.mp4File = [[[MP42File alloc] init] autorelease];
        MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithURL:self.URL error:outError];

        for (MP42Track *track in fileImporter.tracks) {
            // AC-3 track, we might need to do the aac + ac3 trick.
            if ([track.format isEqualToString:MP42AudioFormatAC3]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue]) {
                    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepAC3"] boolValue] &&
                        ![(MP42AudioTrack *)track fallbackTrack]) {
                        MP42AudioTrack *copy = [track copy];
                        copy.needConversion = YES;
                        copy.mixdownType = SBDolbyPlIIMixdown;

                        [(MP42AudioTrack *)track setFallbackTrack:copy];

                        [self.mp4File addTrack:copy];

                        [copy release];
                    } else {
                        track.needConversion = YES;
                    }
                }
            }

            // DTS -> convert only if specified in the prefs.
            if ([track.format isEqualToString:MP42AudioFormatDTS]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertDts"] boolValue]) {
                    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepDts"] boolValue]) {
                        MP42AudioTrack *copy = [track copy];
                        copy.needConversion = YES;
                        copy.mixdownType = SBDolbyPlIIMixdown;
                        
                        [self.mp4File addTrack:copy];
                        
                        [copy release];
                    }
                    else {
                        track.needConversion = YES;
                    }
                }
            }

            // VobSub -> only if specified in the prefs.
            if (([track.format isEqualToString:MP42SubtitleFormatVobSub] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue]))
                track.needConversion = YES;

            // If an audio track needs to be converted, apply the mixdown from the preferences.
            if ([track isMemberOfClass:[MP42AudioTrack class]] && track.needConversion) {
                NSInteger mixdown = [[[NSUserDefaults standardUserDefaults]
                  valueForKey:@"SBAudioMixdown"] integerValue];
                MP42AudioTrack *audioTrack = (MP42AudioTrack *)track;
                switch (mixdown) {
                    case 5:
                        audioTrack.mixdownType = nil;
                        break;
                    case 4:
                        audioTrack.mixdownType = SBMonoMixdown;
                        break;
                    case 3:
                        audioTrack.mixdownType = SBStereoMixdown;
                        break;
                    case 2:
                        audioTrack.mixdownType = SBDolbyMixdown;
                        break;
                    case 1:
                    default:
                        audioTrack.mixdownType = SBDolbyPlIIMixdown;
                        break;
                }
            }

            if (isTrackMuxable(track.format) || trackNeedConversion(track.format)) {
                [self.mp4File addTrack:track];
            }
        }
        [fileImporter release];
    }

    for (id<SBQueueActionProtocol> action in self.actions) {
        self.localizedWorkingDescription = action.localizedDescription;
        [self progressStatus:0];
        [action runAction:self];
    }

    self.localizedWorkingDescription = nil;

    return YES;
}

- (BOOL)processWithOptions:(BOOL)optimize error:(NSError **)outError {
    BOOL noErr = YES;

#ifdef SB_SANDBOX
    if ([destination respondsToSelector:@selector(startAccessingSecurityScopedResource)])
        [destination startAccessingSecurityScopedResource];
#endif

    // The file has been added directly to the queue
    if (!self.mp4File && self.URL) {
        noErr = [self prepare:outError];
    }

    if (!noErr) { goto bail; }

    self.mp4File.progressHandler = ^(double progress){
        [self progressStatus:progress];
    };

    // Check if there is enough space on the destination disk
    if (![self.URL isEqualTo:self.destURL]) {
        NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[[self.destURL URLByDeletingLastPathComponent] path] error:NULL];
        NSNumber *freeSpace = [dict objectForKey:NSFileSystemFreeSize];
        if (freeSpace && [self.mp4File dataSize] > [freeSpace longLongValue]) {
            noErr = NO;
            if (outError) {
                NSDictionary *errorDetail = @{ NSLocalizedDescriptionKey : @"Not enough disk space",
                                               NSLocalizedRecoverySuggestionErrorKey : @"" };
                *outError = [NSError errorWithDomain:@"SBQueueItemError" code:12 userInfo:errorDetail];
            }
            goto bail;
        }
    }

    // Convert from a file reference url to a normal url
    // the file will be replaced if optimized, and the reference url
    // may point to nil
    [self willChangeValueForKey:@"fileURL"];
    [_fileURL autorelease];
    _fileURL = [[self.URL filePathURL] retain];
    [self didChangeValueForKey:@"fileURL"];

    if (!self.cancelled) {
        if ([self.URL isEqualTo:self.destURL] && [self.mp4File hasFileRepresentation]) {
            // We have an existing mp4 file, update it
            noErr = [self.mp4File updateMP4FileWithOptions:self.attributes error:outError];
        } else {
            // Write the new file to disk
            noErr = [self.mp4File writeToUrl:self.destURL
                                     options:self.attributes
                                       error:outError];
        }
    }

    if (!noErr) { goto bail; }

    // Optimize the file
    if (!self.cancelled && optimize) {
        self.localizedWorkingDescription = NSLocalizedString(@"Optimizing", @"");
        noErr = [self.mp4File optimize];
        self.localizedWorkingDescription = nil;
    }

    if (!noErr) {
        if (outError) {
            NSDictionary *errorDetail = @{ NSLocalizedDescriptionKey : @"The file couldn't be optimized",
                                           NSLocalizedRecoverySuggestionErrorKey : @"An error occurred while optimizing the file." };
            *outError = [NSError errorWithDomain:@"SBQueueItemError" code:11 userInfo:errorDetail];
        }
        goto bail;
    }

bail:
    self.mp4File.progressHandler = nil;
    self.mp4File = nil;

    [self willChangeValueForKey:@"actions"];
    [self.actionsInternal removeAllObjects];
    [self didChangeValueForKey:@"actions"];

#ifdef SB_SANDBOX
    if ([destination respondsToSelector:@selector(stopAccessingSecurityScopedResource)])
        [destination stopAccessingSecurityScopedResource];
#endif

    return noErr;
}

- (void)cancel {
    self.cancelled = YES;
    [self.mp4File cancel];
}

- (void)progressStatus:(double)progress {
    [self.delegate progressStatus:progress];
}

#pragma mark NSCoding

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

- (void)dealloc {
    [_attributes release];
    [_actions release];
    [_fileURL release];
    [_destURL release];
    [_mp4File release];

    [super dealloc];
}

@end
