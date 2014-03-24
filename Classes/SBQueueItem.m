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

#define ALMOST_4GiB 4100000000

@interface SBQueueItem () <MP42FileDelegate>

@property (nonatomic, readwrite, retain) MP42File *mp4File;
@property (nonatomic, readwrite) NSMutableArray *actionsInternal;
@property (atomic) BOOL cancelled;

@end

@implementation SBQueueItem

@synthesize status = _status;

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
        _fileURL = [URL retain];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[_fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
        if (originalFileSize > ALMOST_4GiB) {
            _attributes = [[NSDictionary alloc] initWithObjectsAndKeys:@YES, MP4264BitData, nil];
        }
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

+ (instancetype)itemWithMP4:(MP42File *)MP4 url:(NSURL *)URL attributes:(NSDictionary *)dict {
    return [[[SBQueueItem alloc] initWithMP4:MP4 url:URL attributes:dict] autorelease];
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

- (BOOL)processItem:(BOOL)optimize error:(NSError **)outError {
    BOOL noErr = YES;

#ifdef SB_SANDBOX
    if ([destination respondsToSelector:@selector(startAccessingSecurityScopedResource)])
        [destination startAccessingSecurityScopedResource];
#endif

    // The file has been added directly to the queue
    if (!self.mp4File && self.URL) {
        noErr = [self prepareItem:outError];
    }

    if (!noErr) { goto bail; }

    self.mp4File.delegate = self;

    // Check if there is enough space on the dest disk
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[[self.destURL URLByDeletingLastPathComponent] path] error:NULL];
    NSNumber *freeSpace = [dict objectForKey:NSFileSystemFreeSize];
    if (freeSpace && [self.mp4File dataSize] > [freeSpace longLongValue]) {
        noErr = NO;
        if (outError) {
            NSDictionary *errorDetail = @{ NSLocalizedDescriptionKey : @"Not enough disk space",
                                           NSLocalizedRecoverySuggestionErrorKey : @"" };
            *outError = [NSError errorWithDomain:@"SBQueueItemError" code:10 userInfo:errorDetail];
        }
        goto bail;
    }

    if (!self.cancelled) {
        if ([self.URL isEqualTo:self.destURL] && [self.mp4File hasFileRepresentation]) {
            // We have an existing mp4 file, update it
            noErr = [self.mp4File updateMP4FileWithAttributes:self.attributes error:outError];
        } else {
            // Write the new file to disk
            noErr = [self.mp4File writeToUrl:self.destURL
                              withAttributes:self.attributes
                                       error:outError];
        }
    }

    if (!noErr) { goto bail; }

    // Optimize the file
    if (!self.cancelled && optimize) {
        noErr = [self.mp4File optimize];
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

#pragma mark MP42File delegate

- (void)progressStatus:(CGFloat)progress {
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
