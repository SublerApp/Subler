//
//  SBQueueItem.m
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBQueueItem.h"
#import <MP42Foundation/MP42File.h>

@implementation SBQueueItem

@synthesize attributes;
@synthesize URL = fileURL;
@synthesize destURL;
@synthesize mp4File;

- (instancetype)init
{
    self = [super init];
    if (self) {

    }

    return self;
}

- (instancetype)initWithURL:(NSURL*)URL {
    self = [super init];
    if (self) {
        fileURL = [URL retain];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
        if (originalFileSize > 4200000000) {
            attributes = [[NSDictionary alloc] initWithObjectsAndKeys:@YES, MP4264BitData, nil];
        }
    }

    return self;
}

+ (instancetype)itemWithURL:(NSURL*)URL
{
    return [[[SBQueueItem alloc] initWithURL:URL] autorelease];
}

- (id)initWithMP4:(MP42File*)MP4 {
    self = [super init];
    if (self) {
        mp4File = [MP4 retain];

        if ([MP4 URL])
            fileURL = [[MP4 URL] retain];
        else {
            for (NSUInteger i = 0; i < [mp4File tracksCount]; i++) {
                MP42Track *track = [mp4File trackAtIndex:i];
                if ([track sourceURL]) {
                    fileURL = [[track sourceURL] retain];
                    break;
                }
            }
        }

        status = SBQueueItemStatusReady;
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File*)MP4
{
    return [[[SBQueueItem alloc] initWithMP4:MP4] autorelease];
}

- (id)initWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict
{
    if (self = [super init])
    {
        mp4File = [MP4 retain];
        fileURL = [URL retain];
        destURL = [URL retain];
        attributes = [dict retain];

        status = SBQueueItemStatusReady;
    }

    return self;
}

+ (instancetype)itemWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict
{
    return [[[SBQueueItem alloc] initWithMP4:MP4 url:URL attributes:dict] autorelease];
}

- (SBQueueItemStatus)status
{
    return status;
}

- (void) setStatus:(SBQueueItemStatus)itemStatus
{
    status = itemStatus;
    if (status == SBQueueItemStatusCompleted) {
        if (mp4File) {
            [mp4File release];
            mp4File = nil;
        }
    }
}

- (void)dealloc
{
    [attributes release];
    [fileURL release];
    [destURL release];
    [mp4File release];
    
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:1 forKey:@"SBQueueItemTagEncodeVersion"];

    [coder encodeObject:mp4File forKey:@"SBQueueItemMp4File"];
    [coder encodeObject:fileURL forKey:@"SBQueueItemFileURL"];
    [coder encodeObject:destURL forKey:@"SBQueueItemDestURL"];
    [coder encodeObject:attributes forKey:@"SBQueueItemAttributes"];

    [coder encodeInt:status forKey:@"SBQueueItemStatus"];
    [coder encodeInt:humanEdited forKey:@"SBQueueItemHumanEdited"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    mp4File = [[decoder decodeObjectForKey:@"SBQueueItemMp4File"] retain];

    fileURL = [[decoder decodeObjectForKey:@"SBQueueItemFileURL"] retain];
    destURL = [[decoder decodeObjectForKey:@"SBQueueItemDestURL"] retain];
    attributes = [[decoder decodeObjectForKey:@"SBQueueItemAttributes"] retain];

    status = [decoder decodeIntForKey:@"SBQueueItemStatus"];
    humanEdited = [decoder decodeIntForKey:@"SBQueueItemHumanEdited"];

    return self;
}

@end
