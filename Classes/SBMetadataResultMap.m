//
//  SBMetadataDefaultSet.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataResultMap.h"
#import "SBMetadataResult.h"

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

#pragma mark - NSCoding

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

+ (NSArray<NSString *> *)movieKeys
{
    return @[SBMetadataResultName,
             SBMetadataResultComposer,
             SBMetadataResultGenre,
             SBMetadataResultReleaseDate,
             SBMetadataResultDescription,
             SBMetadataResultLongDescription,
             SBMetadataResultRating,
             SBMetadataResultStudio,
             SBMetadataResultCast,
             SBMetadataResultDirector,
             SBMetadataResultProducers,
             SBMetadataResultScreenwriters,
             SBMetadataResultExecutiveProducer,
             SBMetadataResultCopyright,
             SBMetadataResultContentID,
             SBMetadataResultITunesCountry];
}

+ (instancetype)movieDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:@"Name"               value:@[SBMetadataResultName]],
             [SBMetadataResultMapItem itemWithKey:@"Artist"             value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:@"Composer"           value:@[SBMetadataResultComposer]],
             [SBMetadataResultMapItem itemWithKey:@"Genre"              value:@[SBMetadataResultGenre]],
             [SBMetadataResultMapItem itemWithKey:@"Release Date"       value:@[SBMetadataResultReleaseDate]],
             [SBMetadataResultMapItem itemWithKey:@"Description"        value:@[SBMetadataResultDescription]],
             [SBMetadataResultMapItem itemWithKey:@"Long Description"   value:@[SBMetadataResultLongDescription]],
             [SBMetadataResultMapItem itemWithKey:@"Rating"             value:@[SBMetadataResultRating]],
             [SBMetadataResultMapItem itemWithKey:@"Studio"             value:@[SBMetadataResultStudio]],
             [SBMetadataResultMapItem itemWithKey:@"Cast"               value:@[SBMetadataResultCast]],
             [SBMetadataResultMapItem itemWithKey:@"Director"           value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:@"Producers"          value:@[SBMetadataResultProducers]],
             [SBMetadataResultMapItem itemWithKey:@"Screenwriters"      value:@[SBMetadataResultScreenwriters]],
             [SBMetadataResultMapItem itemWithKey:@"Copyright"          value:@[SBMetadataResultCopyright]],
             [SBMetadataResultMapItem itemWithKey:@"contentID"          value:@[SBMetadataResultContentID]],
             [SBMetadataResultMapItem itemWithKey:@"iTunes Country"     value:@[SBMetadataResultITunesCountry]],
             [SBMetadataResultMapItem itemWithKey:@"Executive Producer" value:@[SBMetadataResultExecutiveProducer]],
             ];

    return [[self alloc] initWithItems:items type:SBMetadataResultMapTypeMovie];
}

+ (NSArray<NSString *> *)tvShowKeys
{
    return @[SBMetadataResultName,
             SBMetadataResultSeriesName,
             SBMetadataResultComposer,
             SBMetadataResultGenre,
             SBMetadataResultReleaseDate,

             SBMetadataResultTrackNumber,
             SBMetadataResultDiskNumber,
             SBMetadataResultEpisodeNumber,
             SBMetadataResultNetwork,
             SBMetadataResultEpisodeID,
             SBMetadataResultSeason,

             SBMetadataResultDescription,
             SBMetadataResultLongDescription,
             SBMetadataResultSeriesDescription,

             SBMetadataResultRating,
             SBMetadataResultStudio,
             SBMetadataResultCast,
             SBMetadataResultDirector,
             SBMetadataResultProducers,
             SBMetadataResultScreenwriters,
             SBMetadataResultExecutiveProducer,
             SBMetadataResultCopyright,
             SBMetadataResultContentID,
             SBMetadataResultArtistID,
             SBMetadataResultPlaylistID,
             SBMetadataResultITunesCountry];
}

+ (instancetype)tvShowDefaultMap
{
    NSArray<SBMetadataResultMapItem *> *items = @[
             [SBMetadataResultMapItem itemWithKey:@"Name"         value:@[SBMetadataResultName]],
             [SBMetadataResultMapItem itemWithKey:@"Artist"       value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:@"Album Artist" value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:@"Album"        value:@[SBMetadataResultSeriesName, @", Season ", SBMetadataResultSeason]],
             [SBMetadataResultMapItem itemWithKey:@"Composer"     value:@[SBMetadataResultComposer]],
             [SBMetadataResultMapItem itemWithKey:@"Genre"        value:@[SBMetadataResultGenre]],
             [SBMetadataResultMapItem itemWithKey:@"Release Date" value:@[SBMetadataResultReleaseDate]],

             [SBMetadataResultMapItem itemWithKey:@"Track #"          value:@[SBMetadataResultTrackNumber]],
             [SBMetadataResultMapItem itemWithKey:@"Disk #"           value:@[SBMetadataResultDiskNumber]],
             [SBMetadataResultMapItem itemWithKey:@"TV Show"          value:@[SBMetadataResultSeriesName]],
             [SBMetadataResultMapItem itemWithKey:@"TV Episode #"     value:@[SBMetadataResultEpisodeNumber]],
             [SBMetadataResultMapItem itemWithKey:@"TV Network"       value:@[SBMetadataResultNetwork]],
             [SBMetadataResultMapItem itemWithKey:@"TV Episode ID"    value:@[SBMetadataResultEpisodeID]],
             [SBMetadataResultMapItem itemWithKey:@"TV Season"        value:@[SBMetadataResultSeason]],

             [SBMetadataResultMapItem itemWithKey:@"Description"          value:@[SBMetadataResultDescription]],
             [SBMetadataResultMapItem itemWithKey:@"Long Description"     value:@[SBMetadataResultLongDescription]],
             [SBMetadataResultMapItem itemWithKey:@"Series Description"   value:@[SBMetadataResultSeriesDescription]],

             [SBMetadataResultMapItem itemWithKey:@"Rating"               value:@[SBMetadataResultRating]],
             [SBMetadataResultMapItem itemWithKey:@"Studio"               value:@[SBMetadataResultStudio]],
             [SBMetadataResultMapItem itemWithKey:@"Cast"                 value:@[SBMetadataResultCast]],
             [SBMetadataResultMapItem itemWithKey:@"Director"             value:@[SBMetadataResultDirector]],
             [SBMetadataResultMapItem itemWithKey:@"Producers"            value:@[SBMetadataResultProducers]],
             [SBMetadataResultMapItem itemWithKey:@"Screenwriters"        value:@[SBMetadataResultScreenwriters]],
             [SBMetadataResultMapItem itemWithKey:@"Executive Producer"   value:@[SBMetadataResultExecutiveProducer]],
             [SBMetadataResultMapItem itemWithKey:@"Copyright"            value:@[SBMetadataResultCopyright]],
             [SBMetadataResultMapItem itemWithKey:@"contentID"            value:@[SBMetadataResultContentID]],
             [SBMetadataResultMapItem itemWithKey:@"artistID"             value:@[SBMetadataResultArtistID]],
             [SBMetadataResultMapItem itemWithKey:@"playlistID"           value:@[SBMetadataResultPlaylistID]],
             [SBMetadataResultMapItem itemWithKey:@"iTunes Country"       value:@[SBMetadataResultITunesCountry]],
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

#pragma mark - NSCoding

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
