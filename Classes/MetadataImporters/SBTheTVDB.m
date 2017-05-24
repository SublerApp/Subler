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
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/search/series?name=%@", [SBMetadataHelper urlEncoded:seriesName]]];
    NSData *seriesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (seriesJSON) {

        NSDictionary *series = [NSJSONSerialization JSONObjectWithData:seriesJSON options:0 error:NULL];

        if (series || [series isKindOfClass:[NSDictionary class]]) {

            NSArray<NSDictionary *> *seriesArray = series[@"data"];

            if ([seriesArray isKindOfClass:[NSArray class]] && seriesArray.count) {
                for (NSDictionary *s in seriesArray) {
                    [results addObject:s[@"seriesName"]];
                }
            }
        }
    }

    if (![language isEqualToString:@"en"]) {
        [results addObjectsFromArray:[self searchTVSeries:seriesName language:@"en"]];
    }
    
    return results.allObjects;
}

- (BOOL)seriesResult:(NSDictionary *)s matchName:(NSString *)seriesName
{
    if ([seriesName isEqualTo:s[@"seriesName"]]) {
        return YES;
    }
    else {
        NSArray<NSString *> *aliases = s[@"aliases"];

        if ([aliases isKindOfClass:[NSArray class]]) {
            for (NSString *alias in aliases) {
                if ([seriesName isEqualTo:alias]) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

- (NSSet<NSNumber *> *)searchSeriesID:(NSString *)seriesName language:(NSString *)language
{
    // search for series id
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/search/series?name=%@", [SBMetadataHelper urlEncoded:seriesName]]];
    NSData *seriesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];
    
    if (!seriesJSON) { return [NSSet set]; }

    NSDictionary *series = [NSJSONSerialization JSONObjectWithData:seriesJSON options:0 error:NULL];

    if (!series || ![series isKindOfClass:[NSDictionary class]]) { return [NSSet set]; }

    NSArray<NSDictionary *> *seriesObject = series[@"data"];
    NSMutableSet<NSDictionary *> *selectedSeries = [[NSMutableSet alloc] init];

    if ([seriesObject isKindOfClass:[NSArray class]] && seriesObject.count) {

        for (NSDictionary *s in seriesObject) {
            if ([self seriesResult:s matchName:seriesName]) {
                [selectedSeries addObject:s];
            }
        }

        if (!selectedSeries.count) {
            [selectedSeries addObject:seriesObject.firstObject];
        }
    }

    return [selectedSeries copy];
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)seriesName language:(NSString *)language seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum
{
    if (!language) { language = @"en"; }

	// search for series id
    NSSet<NSNumber *> *seriesIDs = [self searchSeriesID:seriesName language:language];

    // fallback to english if the no results are found
    if (!seriesIDs.count) {
        seriesIDs = [self searchSeriesID:seriesName language:@"en"];
    }

    NSMutableArray *results = [[NSMutableArray alloc] init];

    for (NSDictionary *s in seriesIDs) {

        NSNumber *seriesID = s[@"id"];

        if (!seriesID || ![seriesID isKindOfClass:[NSNumber class]]) {
            continue;
        }

        // Series info

        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@", seriesID]];
        NSData *seriesInfoJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

        if (!seriesInfoJSON) { continue; }

        NSDictionary *seriesInfo = [NSJSONSerialization JSONObjectWithData:seriesInfoJSON options:0 error:NULL];

        if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { continue; }

        seriesInfo = seriesInfo[@"data"];

        if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { continue; }

        // Series actors

        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/actors", seriesID]];
        NSData *seriesActorsJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

        if (!seriesActorsJSON) { continue; }

        NSDictionary *seriesActorsDictionary = [NSJSONSerialization JSONObjectWithData:seriesActorsJSON options:0 error:NULL];

        if (!seriesActorsDictionary || ![seriesActorsDictionary isKindOfClass:[NSDictionary class]]) { continue; }

        NSArray *seriesActors = seriesActorsDictionary[@"data"];

        if (!seriesActors || ![seriesActors isKindOfClass:[NSArray class]]) { continue; }

        // Series episodes info

        if (seasonNum.length && episodeNum.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@&airedEpisode=%@", seriesID, seasonNum, episodeNum]];
        } else if (seasonNum.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@", seriesID, seasonNum]];
        }
        else {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes", seriesID]];
        }

        NSData *episodesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

        if (!episodesJSON) { continue; }

        NSDictionary *episodes = [NSJSONSerialization JSONObjectWithData:episodesJSON options:0 error:NULL];

        if (!episodes || ![episodes isKindOfClass:[NSDictionary class]]) { continue; }

        // Decode the individual episodes

        NSArray<NSDictionary *> *episodesArray = episodes[@"data"];

        if ([episodesArray isKindOfClass:[NSArray class]]) {

            for (NSDictionary *episode in episodesArray) {
                if (seasonNum && seasonNum.length) {
                    NSString *episodeSeason = [episode[@"airedSeason"] stringValue];
                    if ([episodeSeason isEqualToString:seasonNum]) {
                        if (episodeNum && episodeNum.length) {
                            NSString *episodeNumber = [episode[@"airedEpisodeNumber"] stringValue];
                            if ([episodeNumber isEqualToString:episodeNum]) {
                                [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:seriesActors]];
                            }
                        } else {
                            [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:seriesActors]];
                        }
                    }
                } else {
                    [results addObject:[SBTheTVDB metadataForEpisode:episode series:seriesInfo actors:seriesActors]];
                }
            }
        }
    }

    NSArray<SBMetadataResult *> *resultsSorted = [results sortedArrayUsingComparator:^NSComparisonResult(SBMetadataResult *ep1, SBMetadataResult *ep2) {
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
    }];

    return resultsSorted;
}

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

- (void)loadITunesArtwork:(SBMetadataResult *)metadata
{
    NSMutableArray *newArtworkThumbURLs = [NSMutableArray array];
    NSMutableArray *newArtworkFullsizeURLs = [NSMutableArray array];
    NSMutableArray *newArtworkProviderNames = [NSMutableArray array];

    [newArtworkThumbURLs addObjectsFromArray:metadata.artworkThumbURLs];
    [newArtworkFullsizeURLs addObjectsFromArray:metadata.artworkFullsizeURLs];
    [newArtworkProviderNames addObjectsFromArray:metadata.artworkProviderNames];

    SBMetadataResult *iTunesMetadata = [SBiTunesStore quickiTunesSearchTV:metadata[SBMetadataResultSeriesName] episodeTitle:metadata[SBMetadataResultName]];

    if (iTunesMetadata && iTunesMetadata.artworkThumbURLs && iTunesMetadata.artworkFullsizeURLs &&
        (iTunesMetadata.artworkThumbURLs.count == iTunesMetadata.artworkFullsizeURLs.count)) {
        [newArtworkThumbURLs addObjectsFromArray:iTunesMetadata.artworkThumbURLs];
        [newArtworkFullsizeURLs addObjectsFromArray:iTunesMetadata.artworkFullsizeURLs];
        [newArtworkProviderNames addObjectsFromArray:iTunesMetadata.artworkProviderNames];
    }

    metadata.artworkThumbURLs = newArtworkThumbURLs;
    metadata.artworkFullsizeURLs = newArtworkFullsizeURLs;
    metadata.artworkProviderNames = newArtworkProviderNames;
}

- (void)loadTVImages:(SBMetadataResult *)metadata type:(NSString *)type language:(NSString *)language
{
    NSMutableArray *newArtworkThumbURLs = [NSMutableArray array];
    NSMutableArray *newArtworkFullsizeURLs = [NSMutableArray array];
    NSMutableArray *newArtworkProviderNames = [NSMutableArray array];

    [newArtworkThumbURLs addObjectsFromArray:metadata.artworkThumbURLs];
    [newArtworkFullsizeURLs addObjectsFromArray:metadata.artworkFullsizeURLs];
    [newArtworkProviderNames addObjectsFromArray:metadata.artworkProviderNames];

    // get additionals images
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/images/query?keyType=%@", metadata[@"TheTVDB Series ID"], type]];
    NSData *imagesJSON = [SBTheTVDBConnection.defaultManager requestData:url language:language];

    if (imagesJSON) {
        NSDictionary *imagesData = [NSJSONSerialization JSONObjectWithData:imagesJSON options:0 error:NULL];

        if (imagesData || [imagesData isKindOfClass:[NSDictionary class]]) {

            NSArray *images = imagesData[@"data"];

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
                        [newArtworkThumbURLs addObject:thumbURL];
                        [newArtworkFullsizeURLs addObject:fileURL];
                        [newArtworkProviderNames addObject:[NSString stringWithFormat:@"TheTVDB|%@", type]];
                    }
                }
            }
        }
    }

    metadata.artworkThumbURLs = newArtworkThumbURLs;
    metadata.artworkFullsizeURLs = newArtworkFullsizeURLs;
    metadata.artworkProviderNames = newArtworkProviderNames;
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage
{
    // Get additional episodes info
    NSNumber *episodesID = aMetadata[@"TheTVDB Episodes ID"];
    NSURL *episodesUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/episodes/%@", episodesID]];
    NSData *episodesJSON = [SBTheTVDBConnection.defaultManager requestData:episodesUrl language:aLanguage];

    if (episodesJSON) {
        NSDictionary *episodesInfo = [NSJSONSerialization JSONObjectWithData:episodesJSON options:0 error:NULL];

        if (episodesInfo || [episodesInfo isKindOfClass:[NSDictionary class]]) {
            NSDictionary *episodesData = episodesInfo[@"data"];

            if (episodesData || [episodesData isKindOfClass:[NSDictionary class]]) {

                aMetadata[SBMetadataResultDirector]      = [SBTheTVDB cleanList:episodesData[@"directors"]];
                aMetadata[SBMetadataResultScreenwriters] = [SBTheTVDB cleanList:episodesData[@"writers"]];

                NSString *actors = aMetadata[SBMetadataResultCast];
                NSString *gueststars = [SBTheTVDB cleanList:episodesData[@"guestStars"]];

                if (actors.length && gueststars.length) {
                    aMetadata[SBMetadataResultCast] = [NSString stringWithFormat:@"%@, %@", actors, gueststars];
                }
                else if (gueststars.length) {
                    aMetadata[SBMetadataResultCast] = gueststars;
                }

                // Episodes artwork
                NSString *artworkFilename = episodesData[@"filename"];
                if (artworkFilename && [artworkFilename isKindOfClass:[NSString class]] && artworkFilename.length) {
                    NSURL *artworkURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/banners/%@", artworkFilename]];

                    aMetadata.artworkThumbURLs = @[artworkURL];
                    aMetadata.artworkFullsizeURLs = @[artworkURL];
                    aMetadata.artworkProviderNames = @[@"TheTVDB|episode"];
                }
            }
        }
    }

    // get additionals images
    [self loadITunesArtwork:aMetadata];
    [self loadTVImages:aMetadata type:@"season" language:aLanguage];
    [self loadTVImages:aMetadata type:@"poster" language:aLanguage];

	return aMetadata;
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

@end
