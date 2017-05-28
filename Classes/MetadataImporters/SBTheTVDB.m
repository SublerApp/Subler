//
//  TheTVDB.m
//  Subler
//
//  Created by Douglas Stebila on 2013-06-06.
//
//

#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBTheTVDB.h"
#import "SBTheTVDBConnection.h"

#import "SBiTunesStore.h"

@implementation SBTheTVDB

#pragma mark - Public methods

- (NSArray<NSString *> *)languages
{
    return SBTheTVDBConnection.defaultManager.languagues;
}

- (SBMetadataImporterLanguageType)languageType
{
    return SBMetadataImporterLanguageTypeISO;
}

- (NSArray<NSString *> *)searchTVSeries:(NSString *)seriesName language:(NSString *)language
{
    NSMutableSet *results = [NSMutableSet set];

    language = [MP42Languages.defaultManager extendedTagForLocalizedLang:language];

    // search for series
    NSArray<NSDictionary *> *series = [SBTheTVDBConnection.defaultManager fetchSeries:[SBMetadataHelper urlEncoded:seriesName] language:language];

    for (NSDictionary *s in series) {
        [results addObject:s[@"seriesName"]];
    }

    // Fall back to english
    if (![language isEqualToString:@"en"]) {
        [results addObjectsFromArray:[self searchTVSeries:seriesName language:@"en"]];
    }
    
    return results.allObjects;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)seriesName language:(NSString *)language seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum
{
    if (!language) { language = @"en"; }

	// search for series id
    NSSet<NSNumber *> *seriesIDs = [self searchSeriesID:seriesName language:language];

    // fallback to English if no results are found
    if (!seriesIDs.count) {
        seriesIDs = [self searchSeriesID:seriesName language:@"en"];
    }

    NSMutableArray<SBMetadataResult *> *results = [[NSMutableArray alloc] init];

    for (NSDictionary *s in seriesIDs) {

        NSNumber *seriesID = s[@"id"];

        if (!seriesID || ![seriesID isKindOfClass:[NSNumber class]]) {
            continue;
        }

        // Series info
        NSDictionary *seriesInfo = [SBTheTVDBConnection.defaultManager fetchSeriesInfo:seriesID language:language];
        if (seriesInfo == nil) { continue; }

        // Series actors
        NSArray<NSDictionary *> *seriesActors = [SBTheTVDBConnection.defaultManager fetchSeriesActors:seriesID language:language];

        // Series episodes info
        NSArray<SBMetadataResult *> *localizedResults = [self loadTVEpisodes:seriesInfo actors:seriesActors
                                                                   seasonNum:seasonNum episodeNum:episodeNum language:language];

        // Check for null values, it might happens if there isn't a localized version
        SBTheTVDBNullValues nullValues = [self checkForNull:localizedResults];

        localizedResults = [localizedResults sortedArrayUsingFunction:sortSBMetadataResult context:NULL];

        if (nullValues && ![language isEqualToString:@"en"]) {
            if (nullValues & SBTheTVDBNullValuesEpisodes) {
                NSArray<SBMetadataResult *> *englishResults = [self loadTVEpisodes:seriesInfo actors:seriesActors
                                                                     seasonNum:seasonNum episodeNum:episodeNum language:@"en"];

                if (englishResults.count) {
                    englishResults = [englishResults sortedArrayUsingFunction:sortSBMetadataResult context:NULL];
                    [self merge:localizedResults with:englishResults];
                }
            }

            if (nullValues & SBTheTVDBNullValuesSeries) {
                NSDictionary *englishSeriesInfo = [SBTheTVDBConnection.defaultManager fetchSeriesInfo:seriesID language:@"en"];

                if (englishSeriesInfo) {
                    [self merge:localizedResults withSeries:englishSeriesInfo];
                }
            }
        }

        [self removeNullValues:localizedResults];

        [results addObjectsFromArray:localizedResults];
    }

    return [results sortedArrayUsingFunction:sortSBMetadataResult context:NULL];
}

#pragma mark - Sort

static NSInteger sortSBMetadataResult(SBMetadataResult *ep1, SBMetadataResult *ep2, void *context)
{
    int v1 = [ep1[SBMetadataResultEpisodeNumber] intValue];
    int v2 = [ep2[SBMetadataResultEpisodeNumber] intValue];

    int s1 = [ep1[SBMetadataResultSeason] intValue];
    int s2 = [ep2[SBMetadataResultSeason] intValue];

    if (s1 == s2) {
        if (v1 < v2)
            return NSOrderedAscending;
        else if (v1 > v2)
            return NSOrderedDescending;
    }

    if (s1 < s2)
        return NSOrderedAscending;
    else if (s1 > s2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

#pragma mark - Series ID

- (BOOL)seriesResult:(NSDictionary *)s matchName:(NSString *)seriesName
{
    NSString *resultName = s[@"seriesName"];

    if (![resultName isKindOfClass:[NSString class]]) { return NO; }

    if ([seriesName isEqualTo:s[@"seriesName"]]) {
        return YES;
    }
    else {
        NSArray<NSString *> *aliases = s[@"aliases"];

        if ([aliases isKindOfClass:[NSArray class]]) {
            for (NSString *alias in aliases) {
                if ([alias isKindOfClass:[NSString class]] && [seriesName isEqualTo:alias]) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

- (NSSet<NSNumber *> *)searchSeriesID:(NSString *)seriesName language:(NSString *)language
{
    NSMutableSet<NSDictionary *> *selectedSeries = [[NSMutableSet alloc] init];

    // search for series id
    NSArray<NSDictionary *> *series = [SBTheTVDBConnection.defaultManager fetchSeries:[SBMetadataHelper urlEncoded:seriesName] language:language];

    for (NSDictionary *s in series) {
        if ([self seriesResult:s matchName:seriesName]) {
            [selectedSeries addObject:s];
        }
    }

    if (!selectedSeries.count && series.count) {
        [selectedSeries addObject:series.firstObject];
    }

    return [selectedSeries copy];
}

#pragma mark - Null values check

typedef NS_OPTIONS(NSUInteger, SBTheTVDBNullValues) {
    SBTheTVDBNullValuesEpisodes = 1 << 0,
    SBTheTVDBNullValuesSeries = 1 << 1,
};

- (SBTheTVDBNullValues)checkForNull:(NSArray<SBMetadataResult *> *)results
{
    NSNull *null = [NSNull null];
    SBTheTVDBNullValues nullValues = 0;

    for (SBMetadataResult *result in results) {
        if ([result[SBMetadataResultSeriesName] isEqualTo:null]) {
            nullValues |= SBTheTVDBNullValuesSeries;
        }
        if ([result[SBMetadataResultName] isEqualTo:null]) {
            nullValues |= SBTheTVDBNullValuesEpisodes;
        }
        if ([result[SBMetadataResultLongDescription] isEqualTo:null]) {
            nullValues |= SBTheTVDBNullValuesEpisodes;
        }
        if ([result[SBMetadataResultSeriesDescription] isEqualTo:null]) {
            nullValues |= SBTheTVDBNullValuesSeries;
        }

        if (nullValues & SBTheTVDBNullValuesEpisodes &&
            nullValues & SBTheTVDBNullValuesSeries) {
            break;
        }
    }

    return nullValues;
}

- (void)removeNullValues:(NSArray<SBMetadataResult *> *)results
{
    NSNull *null = [NSNull null];

    for (SBMetadataResult *result in results) {
        if ([result[SBMetadataResultSeriesName] isEqualTo:null]) {
            result[SBMetadataResultSeriesName] = nil;
        }
        if ([result[SBMetadataResultName] isEqualTo:null]) {
            result[SBMetadataResultName] = nil;
        }
        if ([result[SBMetadataResultLongDescription] isEqualTo:null]) {
            result[SBMetadataResultLongDescription] = nil;
        }
        if ([result[SBMetadataResultDescription] isEqualTo:null]) {
            result[SBMetadataResultDescription] = nil;
        }
        if ([result[SBMetadataResultSeriesDescription] isEqualTo:null]) {
            result[SBMetadataResultSeriesDescription] = nil;
        }
    }
}

- (void)merge:(NSArray<SBMetadataResult *> *)array with:(NSArray<SBMetadataResult *> *)array2
{
    NSNull *null = [NSNull null];

    if (array2.count != array.count) {
        return;
    }

    NSUInteger index = 0;
    for (SBMetadataResult *target in array) {
        SBMetadataResult *source = array2[index];

        if ([target[SBMetadataResultSeriesName] isEqualTo:null]) {
            target[SBMetadataResultSeriesName] = source[SBMetadataResultSeriesName];
        }
        if ([target[SBMetadataResultName] isEqualTo:null]) {
            target[SBMetadataResultName] = source[SBMetadataResultName];
        }
        if ([target[SBMetadataResultLongDescription] isEqualTo:null]) {
            target[SBMetadataResultLongDescription] = source[SBMetadataResultLongDescription];
            target[SBMetadataResultDescription] = source[SBMetadataResultDescription];
        }
        if ([target[SBMetadataResultSeriesDescription] isEqualTo:null]) {
            target[SBMetadataResultSeriesDescription] = source[SBMetadataResultSeriesDescription];
        }
        index++;
    }

    return;
}

- (void)merge:(NSArray<SBMetadataResult *> *)array withSeries:(NSDictionary *)series
{
    NSNull *null = [NSNull null];
    NSString *name = series[@"seriesName"];
    NSString *overview = series[@"overview"];

    for (SBMetadataResult *target in array) {
        if ([target[SBMetadataResultSeriesName] isEqualTo:null]) {
            target[SBMetadataResultSeriesName] = name;
        }
        if ([target[SBMetadataResultSeriesDescription] isEqualTo:null]) {
            target[SBMetadataResultSeriesDescription] = overview;
        }
    }
}

#pragma mark - Helpers

+ (nullable NSString *)cleanList:(nullable NSArray<NSString *> *)s
{
    NSMutableString *result = [NSMutableString string];

    if (s) {
        for (NSString *component in s) {
            if ([component isKindOfClass:[NSString class]]) {
                if (result.length) {
                    [result appendString:@", "];
                }
                [result appendString:component];
            }
        }
    }

    return result.length ? result : nil;
}

+ (nullable NSString *)cleanActorsList:(nullable NSArray<NSDictionary *> *)s
{
    NSMutableString *result = [NSMutableString string];

    if (s) {
        for (NSDictionary *component in s) {
            if ([component isKindOfClass:[NSDictionary class]]) {
                NSString *nameComponent = component[@"name"];
                if ([nameComponent isKindOfClass:[NSString class]]) {
                    if (result.length) {
                        [result appendString:@", "];
                    }
                    [result appendString:component[@"name"]];
                }
            }
        }
    }

    return result.length ? result : nil;
}

#pragma mark - Episodes

- (void)loadITunesArtwork:(SBMetadataResult *)metadata
{
    NSMutableArray<SBRemoteImage *> *remoteArtworks = metadata.remoteArtworks.mutableCopy;

    SBMetadataResult *iTunesMetadata = [SBiTunesStore quickiTunesSearchTV:metadata[SBMetadataResultSeriesName] episodeTitle:metadata[SBMetadataResultName]];

    if (iTunesMetadata && iTunesMetadata.remoteArtworks.count) {
        [remoteArtworks addObjectsFromArray:iTunesMetadata.remoteArtworks];
    }

    metadata.remoteArtworks = remoteArtworks;
}

- (void)loadTVImages:(SBMetadataResult *)metadata type:(NSString *)type language:(NSString *)language
{
    NSMutableArray<SBRemoteImage *> *remoteArtworks = metadata.remoteArtworks.mutableCopy;

    // get additionals images
    NSArray *images = [SBTheTVDBConnection.defaultManager fetchSeriesImages:metadata[@"TheTVDB Series ID"] type:type language:language];

    if (images && [images isKindOfClass:[NSArray class]]) {

        for (NSDictionary *image in images) {
            NSURL *fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/banners/%@", image[@"fileName"]]];
            NSURL *thumbURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/banners/%@", image[@"thumbnail"]]];

            BOOL toBeAdded = YES;

            if ([type isEqualToString:@"season"]) {
                NSString *subKey = image[@"subKey"];
                NSString *season = [metadata[SBMetadataResultSeason] stringValue];
                if (subKey && [subKey isKindOfClass:[NSString class]] && ![subKey isEqualToString:season]) {
                    toBeAdded = NO;
                }
            }
            if (toBeAdded) {
                SBRemoteImage *artwork = [SBRemoteImage remoteImageWithURL:fileURL
                                                                  thumbURL:thumbURL
                                                              providerName:[NSString stringWithFormat:@"TheTVDB|%@", type]];
                [remoteArtworks addObject:artwork];
            }
        }
    }

    metadata.remoteArtworks = remoteArtworks;
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)metadata language:(NSString *)language
{
    // Get additional episodes info
    NSNumber *episodesID = metadata[@"TheTVDB Episodes ID"];
    NSDictionary *episodesInfo = [SBTheTVDBConnection.defaultManager fetchEpisodesInfo:episodesID language:language];
    SBRemoteImage *artwork = nil;

    if (episodesInfo) {
        metadata[SBMetadataResultDirector]      = [SBTheTVDB cleanList:episodesInfo[@"directors"]];
        metadata[SBMetadataResultScreenwriters] = [SBTheTVDB cleanList:episodesInfo[@"writers"]];

        NSString *actors = metadata[SBMetadataResultCast];
        NSString *gueststars = [SBTheTVDB cleanList:episodesInfo[@"guestStars"]];

        if (actors.length && gueststars.length) {
            metadata[SBMetadataResultCast] = [NSString stringWithFormat:@"%@, %@", actors, gueststars];
        }
        else if (gueststars.length) {
            metadata[SBMetadataResultCast] = gueststars;
        }

        // Episodes artwork
        NSString *artworkFilename = episodesInfo[@"filename"];
        if (artworkFilename && [artworkFilename isKindOfClass:[NSString class]] && artworkFilename.length) {
            NSURL *artworkURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/banners/%@", artworkFilename]];

            artwork = [SBRemoteImage remoteImageWithURL:artworkURL
                                               thumbURL:artworkURL
                                           providerName:@"TheTVDB|episode"];
        }
    }

    // get additionals images
    [self loadITunesArtwork:metadata];
    if (artwork) {
        NSMutableArray<SBRemoteImage *> *remoteArtworks = metadata.remoteArtworks.mutableCopy;
        [remoteArtworks addObject:artwork];
        metadata.remoteArtworks = remoteArtworks;
    }
    [self loadTVImages:metadata type:@"season" language:language];
    [self loadTVImages:metadata type:@"poster" language:language];

	return metadata;
}

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)episode series:(NSDictionary *)series actors:(NSArray *)actors
{
	SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

	metadata.mediaKind = 10; // TV show

    // TV Show
    metadata[@"TheTVDB Series ID"]              = series[@"id"];
    metadata[SBMetadataResultSeriesName]        = series[@"seriesName"];
    metadata[SBMetadataResultSeriesDescription] = series[@"overview"];
    metadata[SBMetadataResultGenre]             = [SBTheTVDB cleanList:series[@"genre"]];

    // Episode
    metadata[@"TheTVDB Episodes ID"]          = episode[@"id"];
    metadata[SBMetadataResultName]            = episode[@"episodeName"];
    metadata[SBMetadataResultReleaseDate]     = episode[@"firstAired"];
    metadata[SBMetadataResultDescription]     = episode[@"overview"];
    metadata[SBMetadataResultLongDescription] = episode[@"overview"];

    NSString *ratingString = series[@"rating"];
    if (ratingString.length) {
        metadata[SBMetadataResultRating] = [[MP42Ratings defaultManager] ratingStringForiTunesCountry:@"USA"
                                                                                    media:@"TV"
                                                                             ratingString:ratingString];
    }

    metadata[SBMetadataResultNetwork] = series[@"network"];
    metadata[SBMetadataResultSeason]  = episode[@"airedSeason"];

    NSString *episodeID = [NSString stringWithFormat:@"%d%02d",
                            [episode[@"airedSeason"] intValue],
                            [episode[@"airedEpisodeNumber"] intValue]];

    metadata[SBMetadataResultEpisodeID]     = episodeID;
    metadata[SBMetadataResultEpisodeNumber] = episode[@"airedEpisodeNumber"];
    metadata[SBMetadataResultTrackNumber]   = episode[@"airedEpisodeNumber"];

    // Actors
    metadata[SBMetadataResultCast] = [SBTheTVDB cleanActorsList:actors];

    // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
	// "Copyright", "Comments", "Producers", "Artist"

	return metadata;
}

- (NSArray<SBMetadataResult *> *)loadTVEpisodes:(NSDictionary *)seriesInfo actors:(NSArray *)actors seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum language:(NSString *)language
{
    NSMutableArray *results = [[NSMutableArray alloc] init];
    NSNumber *seriesID = seriesInfo[@"id"];

    NSArray<NSDictionary *> *episodes = [SBTheTVDBConnection.defaultManager fetchEpisodes:seriesID season:seasonNum number:episodeNum language:language];

    for (NSDictionary *episode in episodes) {
        if (seasonNum && seasonNum.length) {
            NSString *episodeSeason = [episode[@"airedSeason"] stringValue];
            if ([episodeSeason isEqualToString:seasonNum]) {
                if (episodeNum && episodeNum.length) {
                    NSString *episodeNumber = [episode[@"airedEpisodeNumber"] stringValue];
                    if ([episodeNumber isEqualToString:episodeNum]) {
                        [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:actors]];
                    }
                } else {
                    [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:actors]];
                }
            }
        } else {
            [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:actors]];
        }
    }

    return results;
}

@end
