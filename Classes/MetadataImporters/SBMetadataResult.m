//
//  SBMetadataResult.m
//  Subler
//
//  Created by Damiano Galassi on 17/02/16.
//
//

#import "SBMetadataResult.h"
#import <MP42Foundation/MP42Metadata.h>

@implementation SBMetadataResult

@synthesize artworks = _artworks;

@synthesize tags = _tagsDict;

@synthesize artworkThumbURLs = _artworkThumbURLs;
@synthesize artworkFullsizeURLs = _artworkFullsizeURLs;
@synthesize artworkProviderNames = _artworkProviderNames;

@synthesize mediaKind = _mediaKind;
@synthesize contentRating = _contentRating;

- (instancetype)init
{
    if ((self = [super init]))
    {
        _tagsDict = [[NSMutableDictionary alloc] init];
        _artworks = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)merge:(SBMetadataResult *)metadata
{
    [_tagsDict addEntriesFromDictionary:metadata.tags];

    for (MP42Image *artwork in metadata.artworks) {
        [_artworks addObject:artwork];
    }

    _mediaKind = metadata.mediaKind;
    _contentRating = metadata.contentRating;
}

- (void)removeTagForKey:(NSString *)aKey
{
    [_tagsDict removeObjectForKey:aKey];
}

- (void)setTag:(id)value forKey:(NSString *)key
{
    _tagsDict[key] = value;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return _tagsDict[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key
{
    if (obj == nil) {
        [self removeTagForKey:key];
    }
    else {
        [self setTag:obj forKey:key];
    }
}

- (MP42Metadata *)metadata
{
    MP42Metadata *metadata = [[MP42Metadata alloc] init];

    for (NSString *key in [metadata writableMetadata]) {
        NSString *tagValue;
        if ((tagValue = _tagsDict[key])) {
            [metadata setTag:tagValue forKey:key];
        }
    }

    for (MP42Image *artwork in self.artworks) {
        [metadata.artworks addObject:artwork];
    }

    metadata.mediaKind = self.mediaKind;
    metadata.contentRating = self.contentRating;

    return metadata;
}

@end
