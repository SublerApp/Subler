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

@property (nonatomic, readonly) NSMutableArray<id<SBQueueActionProtocol>> *actionsInternal;
@property (nonatomic, readwrite) NSString *localizedWorkingDescription;

@property (nonatomic, readwrite, nullable) MP42File *mp4File;
@property (atomic, readwrite) BOOL cancelled;

@end

@implementation SBQueueItem

#pragma mark Initializers

- (instancetype)init {
    self = [super init];
    if (self) {
        _actionsInternal = [[NSMutableArray alloc] init];
        _status = SBQueueItemStatusReady;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [self init];
    if (self) {
        _fileURL = URL.filePathURL;

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:_fileURL.path error:nil] valueForKey:NSFileSize] unsignedLongLongValue];

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

        if (originalFileSize > ALMOST_4GiB) {
            attributes[MP4264BitData] = @YES;
        }

        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue]) {
            attributes[MP42GenerateChaptersPreviewTrack] = @YES;
        }

        _attributes = [attributes copy];
    }

    return self;
}

+ (instancetype)itemWithURL:(NSURL *)URL {
    return [[SBQueueItem alloc] initWithURL:URL];
}

- (instancetype)initWithMP4:(MP42File *)MP4 {
    self = [self init];
    if (self) {
        _mp4File = MP4;

        _fileURL = [NSURL fileURLWithPath:(MP4.URL).path];
        _destURL = [NSURL fileURLWithPath:(MP4.URL).path];

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

        if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] boolValue]) {
            attributes[MP42GenerateChaptersPreviewTrack] = @YES;
        }

        _attributes = [attributes copy];
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 {
    return [[SBQueueItem alloc] initWithMP4:MP4];
}

- (instancetype)initWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict {
    if (self = [self init]) {
        _mp4File = MP4;

        _fileURL = [URL copy];
        _destURL = [URL copy];

        _attributes = [dict copy];
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File *)MP4 destinationURL:(NSURL *)destURL attributes:(NSDictionary *)dict {
    return [[SBQueueItem alloc] initWithMP4:MP4 url:destURL attributes:dict];
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
    return [self.actionsInternal copy];
}

#pragma mark Item processing

- (BOOL)prepare:(NSError * __autoreleasing *)outError {
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]) {
        if (outError) {
            NSDictionary *errorDetail = @{ NSLocalizedDescriptionKey : @"File not found",
                                           NSLocalizedRecoverySuggestionErrorKey : @"The source file couldn't be found." };
            *outError = [NSError errorWithDomain:@"SBQueueItemError" code:10 userInfo:errorDetail];
        }
        return NO;
    }

    NSString *type;
    [self.fileURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:outError];

    if ([type isEqualToString:@"com.apple.m4a-audio"] || [type isEqualToString:@"com.apple.m4v-video"] || [type isEqualToString:@"public.mpeg-4"]) {
       self.mp4File = [[MP42File alloc] initWithURL:self.fileURL error:NULL];
    } else {
        self.mp4File = [[MP42File alloc] init];
        MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithURL:self.fileURL error:outError];

        NSUInteger bitRate = [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioBitrate"] integerValue];
        float drc = [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioDRC"] floatValue];

        for (MP42Track *track in fileImporter.tracks) {

            if (!(isTrackMuxable(track.format) || trackNeedConversion(track.format))) {
                continue;
            }

            BOOL conversionNeeded = NO;

            // AC-3 track, we might need to do the aac + ac3 trick.
            if (track.format == kMP42AudioCodecType_AC3 ||
                track.format == kMP42AudioCodecType_EnhancedAC3) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue]) {
                    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepAC3"] boolValue] &&
                        !((MP42AudioTrack *)track).fallbackTrack) {
                        MP42AudioTrack *copy = [track copy];
                        MP42ConversionSettings *settings = [MP42AudioConversionSettings audioConversionWithBitRate:bitRate
                                                                                                           mixDown:SBDolbyPlIIMixdown
                                                                                                               drc:drc];
                        copy.conversionSettings = settings;

                        ((MP42AudioTrack *)track).fallbackTrack = copy;

                        [self.mp4File addTrack:copy];
                    }
                    else {
                        conversionNeeded = YES;
                    }
                }
            }
            // DTS -> convert only if specified in the prefs.
            else if (track.format == kMP42AudioCodecType_DTS) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertDts"] boolValue]) {
                    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepDts"] boolValue]) {
                        MP42AudioTrack *copy = [track copy];
                        MP42ConversionSettings *settings = [MP42AudioConversionSettings audioConversionWithBitRate:bitRate
                                                                                                           mixDown:SBDolbyPlIIMixdown
                                                                                                               drc:drc];
                        copy.conversionSettings = settings;

                        [self.mp4File addTrack:copy];
                    }
                    else {
                        conversionNeeded = YES;
                    }
                }
            }

            // If an audio track needs to be converted, apply the mixdown from the preferences.
            if (([track isMemberOfClass:[MP42AudioTrack class]] && trackNeedConversion(track.format)) || conversionNeeded) {
                NSInteger mixdownType = [[[NSUserDefaults standardUserDefaults]
                                          valueForKey:@"SBAudioMixdown"] integerValue];
                NSString *mixdown = SBNoneMixdown;

                switch (mixdownType) {
                    case 5:
                        mixdown = SBNoneMixdown;
                        break;
                    case 4:
                        mixdown = SBMonoMixdown;
                        break;
                    case 3:
                        mixdown = SBStereoMixdown;
                        break;
                    case 2:
                        mixdown = SBDolbyMixdown;
                        break;
                    case 1:
                    default:
                        mixdown = SBDolbyPlIIMixdown;
                        break;
                }

                MP42AudioTrack *audioTrack = (MP42AudioTrack *)track;
                MP42ConversionSettings *settings = [MP42AudioConversionSettings audioConversionWithBitRate:bitRate
                                                                                                   mixDown:mixdown
                                                                                                       drc:drc];
                audioTrack.conversionSettings = settings;
                
            }


            // VobSub -> only if specified in the prefs.
            if ((track.format == kMP42SubtitleCodecType_VobSub &&
                 [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue])) {
                MP42ConversionSettings *settings = [MP42ConversionSettings subtitlesConversion];
                track.conversionSettings = settings;
            }
            else if ([track isMemberOfClass:[MP42SubtitleTrack class]] && trackNeedConversion(track.format)) {
                MP42ConversionSettings *settings = [MP42ConversionSettings subtitlesConversion];
                track.conversionSettings = settings;
            }

            [self.mp4File addTrack:track];
        }
    }

    for (id<SBQueueActionProtocol> action in self.actions) {
        self.localizedWorkingDescription = action.localizedDescription;
        [self progressStatus:0];
        [action runAction:self];
    }

    self.localizedWorkingDescription = nil;

    return YES;
}

- (BOOL)processWithOptions:(BOOL)optimize error:(NSError * __autoreleasing *)outError {
    BOOL noErr = YES;

#ifdef SB_SANDBOX
    if ([destination respondsToSelector:@selector(startAccessingSecurityScopedResource)])
        [destination startAccessingSecurityScopedResource];
#endif

    // The file has been added directly to the queue
    if (!self.mp4File && self.fileURL) {
        noErr = [self prepare:outError];
    }

    if (!noErr) { goto bail; }

    {
        __weak SBQueueItem *weakSelf = self;
        self.mp4File.progressHandler = ^(double progress){
            [weakSelf progressStatus:progress];
        };

        // Check if there is enough space on the destination disk
        if (![self.fileURL isEqualTo:self.destURL]) {
            NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:(self.destURL).URLByDeletingLastPathComponent.path error:NULL];
            NSNumber *freeSpace = dict[NSFileSystemFreeSize];
            if (freeSpace && (self.mp4File).dataSize > freeSpace.longLongValue) {
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
        _fileURL = self.fileURL.filePathURL;
        [self didChangeValueForKey:@"fileURL"];

        if (!self.cancelled) {
            if ([self.fileURL isEqualTo:self.destURL] && self.mp4File.hasFileRepresentation) {
                // We have an existing mp4 file, update it
                noErr = [self.mp4File updateMP4FileWithOptions:self.attributes error:outError];
            }
            else {
                // Write the new file to disk
                noErr = [self.mp4File writeToUrl:self.destURL
                                         options:self.attributes
                                           error:outError];
            }
        }
    }

    if (!noErr) { goto bail; }

    {
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

#pragma mark NSSecyreCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:2 forKey:@"SBQueueItemTagEncodeVersion"];

    [coder encodeObject:_mp4File forKey:@"SBQueueItemMp4File"];
    [coder encodeObject:_fileURL forKey:@"SBQueueItemFileURL"];
    [coder encodeObject:_destURL forKey:@"SBQueueItemDestURL"];
    [coder encodeObject:_attributes forKey:@"SBQueueItemAttributes"];
    [coder encodeObject:_actionsInternal forKey:@"SBQueueItemActions"];

    [coder encodeInt:_status forKey:@"SBQueueItemStatus"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];

    _mp4File = [decoder decodeObjectOfClass:[MP42File class] forKey:@"SBQueueItemMp4File"];

    _fileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"SBQueueItemFileURL"];
    _destURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"SBQueueItemDestURL"];
    _attributes = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"SBQueueItemAttributes"];
    _actionsInternal = [decoder decodeObjectOfClasses:[NSSet setWithObjects:[NSMutableArray class], [SBQueueSetAction class],
                                                       [SBQueueMetadataAction class], [SBQueueSubtitlesAction class],
                                                       [SBQueueSetLanguageAction class], [SBQueueFixFallbacksAction class],
                                                       [SBQueueClearTrackNameAction class], [SBQueueOrganizeGroupsAction class], nil]
                                               forKey:@"SBQueueItemActions"];

    _status = [decoder decodeIntForKey:@"SBQueueItemStatus"];

    return self;
}


@end
