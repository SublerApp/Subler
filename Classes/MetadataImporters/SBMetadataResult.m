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

// Common Keys
NSString *const SBMetadataResultName = @"{Name}";
NSString *const SBMetadataResultComposer = @"{Composer}";
NSString *const SBMetadataResultGenre = @"{Genre}";
NSString *const SBMetadataResultReleaseDate = @"{Release Date}";
NSString *const SBMetadataResultDescription = @"{Description}";
NSString *const SBMetadataResultLongDescription = @"{Long Description}";
NSString *const SBMetadataResultRating = @"{Rating}";
NSString *const SBMetadataResultStudio = @"{Studio}";
NSString *const SBMetadataResultCast = @"{Cast}";
NSString *const SBMetadataResultDirector = @"{Director}";
NSString *const SBMetadataResultProducers = @"{Producers}";
NSString *const SBMetadataResultScreenwriters = @"{Screenwriters}";
NSString *const SBMetadataResultExecutiveProducer = @"{Executive Producer}";
NSString *const SBMetadataResultCopyright = @"{Copyright}";

// iTunes Keys
NSString *const SBMetadataResultContentID = @"{contentID}";
NSString *const SBMetadataResultArtistID = @"{artistID}";
NSString *const SBMetadataResultPlaylistID = @"{playlistID}";
NSString *const SBMetadataResultITunesCountry = @"{iTunes Country}";
NSString *const SBMetadataResultITunesURL = @"{iTunes URL}";

// TV Show Keys
NSString *const SBMetadataResultSeriesName = @"{Series Name}";
NSString *const SBMetadataResultSeriesDescription = @"{Series Description}";
NSString *const SBMetadataResultTrackNumber = @"{Track #}";
NSString *const SBMetadataResultDiskNumber = @"{Disk #}";
NSString *const SBMetadataResultEpisodeNumber = @"{Episode #}";
NSString *const SBMetadataResultEpisodeID = @"{Episode ID}";
NSString *const SBMetadataResultSeason = @"{Season}";
NSString *const SBMetadataResultNetwork = @"{Network}";

@implementation SBMetadataResult

- (instancetype)init
{
    if ((self = [super init]))
    {
        _tags = [[NSMutableDictionary alloc] init];
        _artworks = [[NSMutableArray alloc] init];
        _remoteArtworks = [[NSArray alloc] init];
    }

    return self;
}

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

static NSDictionary<NSString *, NSString *> *localizedKeys;

+ (NSString *)localizedDisplayNameForKey:(NSString *)key
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localizedKeys = @{
                          SBMetadataResultName: NSLocalizedString(@"Name", nil),
                          SBMetadataResultComposer: NSLocalizedString(@"Composer", nil),
                          SBMetadataResultGenre: NSLocalizedString(@"Genre", nil),
                          SBMetadataResultReleaseDate: NSLocalizedString(@"Release Date", nil),
                          SBMetadataResultDescription: NSLocalizedString(@"Description", nil),
                          SBMetadataResultLongDescription: NSLocalizedString(@"Long Description", nil),
                          SBMetadataResultRating: NSLocalizedString(@"Rating", nil),
                          SBMetadataResultStudio: NSLocalizedString(@"Studio", nil),
                          SBMetadataResultCast: NSLocalizedString(@"Cast", nil),
                          SBMetadataResultDirector: NSLocalizedString(@"Director", nil),
                          SBMetadataResultProducers: NSLocalizedString(@"Producers", nil),
                          SBMetadataResultScreenwriters: NSLocalizedString(@"Screenwriters", nil),
                          SBMetadataResultExecutiveProducer: NSLocalizedString(@"Executive Producer", nil),
                          SBMetadataResultCopyright: NSLocalizedString(@"Copyright", nil),

                          SBMetadataResultContentID: NSLocalizedString(@"contentID", nil),
                          SBMetadataResultArtistID: NSLocalizedString(@"artistID", nil),
                          SBMetadataResultPlaylistID: NSLocalizedString(@"playlistID", nil),
                          SBMetadataResultITunesCountry: NSLocalizedString(@"iTunes Country", nil),
                          SBMetadataResultITunesURL: NSLocalizedString(@"iTunes URL", nil),

                          SBMetadataResultSeriesName: NSLocalizedString(@"Series Name", nil),
                          SBMetadataResultSeriesDescription: NSLocalizedString(@"Series Description", nil),
                          SBMetadataResultTrackNumber: NSLocalizedString(@"Track #", nil),
                          SBMetadataResultDiskNumber: NSLocalizedString(@"Disk #", nil),
                          SBMetadataResultEpisodeNumber: NSLocalizedString(@"Episode #", nil),
                          SBMetadataResultEpisodeID: NSLocalizedString(@"Episode ID", nil),
                          SBMetadataResultSeason: NSLocalizedString(@"Season", nil),
                          SBMetadataResultNetwork: NSLocalizedString(@"Network", nil),
                          };
    });

    NSString *localizedString = localizedKeys[key];
    return localizedString ? localizedString : key;
    
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

- (void)setObject:(nullable id)obj forKeyedSubscript:(NSString *)key
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
                id value = _tags[component];
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

        MP42MetadataItem *metadataItem = [MP42MetadataItem metadataItemWithIdentifier:item.key
                                                                                value:result
                                                                             dataType:MP42MetadataItemDataTypeUnspecified
                                                                  extendedLanguageTag:nil];

        if (result.length) {
            [metadata addMetadataItem:metadataItem];
        }
        else if (keep) {
            [metadata addMetadataItem:metadataItem];
        }
    }

    for (MP42Image *artwork in self.artworks) {
        MP42MetadataItem *metadataItem = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyCoverArt
                                                                                value:(id)artwork
                                                                             dataType:MP42MetadataItemDataTypeImage
                                                                  extendedLanguageTag:nil];
        [metadata addMetadataItem:metadataItem];
    }

    MP42MetadataItem *mediaKind = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyMediaKind
                                                                            value:@(self.mediaKind)
                                                                         dataType:MP42MetadataItemDataTypeInteger
                                                              extendedLanguageTag:nil];
    [metadata addMetadataItem:mediaKind];

    if (self.contentRating || keep) {
        MP42MetadataItem *contentRating = [MP42MetadataItem metadataItemWithIdentifier:MP42MetadataKeyContentRating
                                                                                 value:@(self.contentRating)
                                                                              dataType:MP42MetadataItemDataTypeInteger
                                                                   extendedLanguageTag:nil];
        [metadata addMetadataItem:contentRating];
    }

    return metadata;
}

@end
