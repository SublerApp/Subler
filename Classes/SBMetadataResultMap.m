//
//  SBMetadataDefaultSet.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataResultMap.h"
#import "SBMetadataResult.h"
#import <MP42Foundation/MP42Metadata.h>

@implementation SBMetadataResultMapItem

- (instancetype)initWithKey:(NSString *)key value:(NSArray *)value
{
    self = [super init];
    if (self) {
        _key = [key copy];
        _value = [value copy];
    }
    return self;
}

+ (instancetype)itemWithKey:(NSString *)key value:(NSArray *)value
{
    return [[self alloc] initWithKey:key value:value];
}

- (NSString *)localizedKeyDisplayName
{
    return localizedMetadataKeyName(self.key);
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        id temp;
        temp = [coder decodeObjectOfClass:[NSString class] forKey:@"key"];
        if (temp) {
            _key = temp;
        }
        temp = [coder decodeObjectOfClass:[NSArray class] forKey:@"value"];
        if (temp) {
            _value = temp;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.key forKey:@"key"];
    [coder encodeObject:self.value forKey:@"value"];
}

@end

@implementation SBMetadataResultMap

+ (instancetype)movieDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyName               value:@[SBMetadataResultName]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyArtist             value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyComposer           value:@[SBMetadataResultComposer]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyUserGenre          value:@[SBMetadataResultGenre]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyReleaseDate        value:@[SBMetadataResultReleaseDate]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyDescription        value:@[SBMetadataResultDescription]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyLongDescription    value:@[SBMetadataResultLongDescription]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyRating             value:@[SBMetadataResultRating]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyStudio             value:@[SBMetadataResultStudio]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyCast               value:@[SBMetadataResultCast]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyDirector           value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyProducer           value:@[SBMetadataResultProducers]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyScreenwriters      value:@[SBMetadataResultScreenwriters]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyCopyright          value:@[SBMetadataResultCopyright]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyContentID          value:@[SBMetadataResultContentID]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyAccountCountry     value:@[SBMetadataResultITunesCountry]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyExecProducer       value:@[SBMetadataResultExecutiveProducer]],
             ];

    return [[self alloc] initWithItems:items type:SBMetadataResultMapTypeMovie];
}

+ (instancetype)tvShowDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyName           value:@[SBMetadataResultName]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyArtist         value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyAlbumArtist    value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyAlbum          value:@[SBMetadataResultSeriesName, @", Season ", SBMetadataResultSeason]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyComposer       value:@[SBMetadataResultComposer]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyUserGenre      value:@[SBMetadataResultGenre]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyReleaseDate    value:@[SBMetadataResultReleaseDate]],

             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTrackNumber        value:@[SBMetadataResultTrackNumber]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyDiscNumber         value:@[SBMetadataResultDiskNumber]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTVShow             value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTVEpisodeNumber    value:@[SBMetadataResultEpisodeNumber]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTVNetwork          value:@[SBMetadataResultNetwork]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTVEpisodeID        value:@[SBMetadataResultEpisodeID]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyTVSeason           value:@[SBMetadataResultSeason]],

             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyDescription        value:@[SBMetadataResultDescription]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyLongDescription    value:@[SBMetadataResultLongDescription]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeySeriesDescription  value:@[SBMetadataResultSeriesDescription]],

             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyRating             value:@[SBMetadataResultRating]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyStudio             value:@[SBMetadataResultStudio]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyCast               value:@[SBMetadataResultCast]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyDirector           value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyProducer           value:@[SBMetadataResultProducers]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyScreenwriters      value:@[SBMetadataResultScreenwriters]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyExecProducer       value:@[SBMetadataResultExecutiveProducer]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyCopyright          value:@[SBMetadataResultCopyright]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyContentID          value:@[SBMetadataResultContentID]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyArtistID           value:@[SBMetadataResultArtistID]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyPlaylistID         value:@[SBMetadataResultPlaylistID]],
             [SBMetadataResultMapItem itemWithKey:MP42MetadataKeyAccountCountry     value:@[SBMetadataResultITunesCountry]],
             ];

    return [[self alloc] initWithItems:items type:SBMetadataResultMapTypeTvShow];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
        _type = SBMetadataResultMapTypeMovie;
    }
    return self;
}

- (instancetype)initWithItems:(NSArray<SBMetadataResultMapItem *> *)items type:(SBMetadataResultMapType)type
{
    self = [super init];
    if (self) {
        _items = [items mutableCopy];
        _type = type;
    }
    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        id temp;
        temp = [coder decodeObjectOfClass:[NSArray class] forKey:@"items"];
        if (temp) {
            _items = temp;
        }
        _type = [coder decodeIntegerForKey:@"type"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.items forKey:@"items"];
    [coder encodeInteger:self.type forKey:@"type"];
}

@end

@implementation NSUserDefaults (SublerMetadataResultMapAdditions)

- (nullable SBMetadataResultMap *)SB_resultMapForKey:(NSString *)defaultName
{
    NSData *encodedObject = [self objectForKey:defaultName];
    if (encodedObject) {
        @try {
            SBMetadataResultMap *decodedMap = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
            if ([decodedMap isKindOfClass:[SBMetadataResultMap class]]) {
                return decodedMap;
            }
        }
        @catch (NSException *exception) {}
        @finally {}
    }
    return nil;
}

- (void)SB_setResultMap:(nullable SBMetadataResultMap *)value forKey:(NSString *)defaultName
{
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:value];
    [self setObject:encodedObject forKey:defaultName];
}

@end
