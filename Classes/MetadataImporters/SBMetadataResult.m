//
//  SBMetadataResult.m
//  Subler
//
//  Created by Damiano Galassi on 17/02/16.
//
//

#import "SBMetadataResult.h"
#import "SBMetadataResultMap.h"
#import <MP42Foundation/MP42Metadata.h>

@implementation SBMetadataResult

- (instancetype)init
{
    if ((self = [super init]))
    {
        _tags = [[NSMutableDictionary alloc] init];
        _artworks = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)merge:(SBMetadataResult *)metadata
{
    [_tags addEntriesFromDictionary:metadata.tags];

    for (MP42Image *artwork in metadata.artworks) {
        [_artworks addObject:artwork];
    }

    _mediaKind = metadata.mediaKind;
    _contentRating = metadata.contentRating;
}

- (void)removeTagForKey:(NSString *)aKey
{
    [_tags removeObjectForKey:aKey];
}

- (void)setTag:(id)value forKey:(NSString *)key
{
    _tags[key] = value;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return _tags[key];
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

- (MP42Metadata *)metadataUsingMap:(SBMetadataResultMap *)map keepEmptyKeys:(BOOL)keep
{
    MP42Metadata *metadata = [[MP42Metadata alloc] init];

    for (SBMetadataResultMapItem *item in map.items) {
        NSMutableString *result = [NSMutableString string];
        for (NSString *component in item.value) {
            if ([component hasPrefix:@"{"] && [component hasSuffix:@"}"] && component.length > 2) {
                NSString *subComponent = [component substringWithRange:NSMakeRange(1, component.length - 2)];
                id value = _tags[subComponent];
                if ([value isKindOfClass:[NSString class]] && [value length]) {
                    [result appendString:value];
                }
                else if ([value isKindOfClass:[NSNumber class]]) {
                    [result appendString:[value stringValue]];
                }
            }
            else {
                [result appendString:component];
            }
        }

        if (result.length) {
            [metadata setTag:result forKey:item.key];
        }
        else if (keep) {
            [metadata setTag:result forKey:item.key];
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
