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

#import "SBiTunesStore.h"
#import "XMLReader.h"

#define API_KEY @"3498815BE9484A62"

static NSArray<NSString *> *TVDBlanguages;
static NSString *globalToken;

@interface SBTheTVDB ()


@end

@implementation SBTheTVDB

+ (void)initialize
{
    if (self == [SBTheTVDB class]) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/api/%@/languages.xml", API_KEY]];
        NSData *languagesXML = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBReturnCacheElseLoad];
        NSDictionary *languages = [XMLReader dictionaryForXMLData:languagesXML error:NULL];

        if (languages) {
            NSArray *languagesArray = [languages retrieveArrayForPath:@"Languages.Language"];
            NSMutableArray<NSString *> *languagesResult = [NSMutableArray array];

            if ([languagesArray isKindOfClass:[NSArray class]] && languagesArray.count) {
                MP42Languages *langManager = MP42Languages.defaultManager;
                for (NSDictionary *language in languagesArray) {
                    NSString *lang = [language valueForKeyPath:@"abbreviation.text"];
                    if (lang && [lang isKindOfClass:[NSString class]]) {
                        [languagesResult addObject:[langManager extendedTagForISO_639_1:lang]];
                    }
                }
            }

            TVDBlanguages = [languagesResult copy];
        }
    }
}

- (NSArray<NSString *> *)languages
{
    return TVDBlanguages;
}

- (SBMetadataImporterLanguageType)languageType
{
    return SBMetadataImporterLanguageTypeISO;
}

- (void)updateToken
{
    NSDictionary *apiKey = @{@"apikey" : API_KEY};
    NSData *jsonApiKey = [NSJSONSerialization dataWithJSONObject:apiKey options:0 error:NULL];

    NSDictionary *headerOptions = @{@"Content-Type" : @"application/json",
                                    @"Accept" : @"application/json"};
    NSURL *url = [NSURL URLWithString:@"https://api.thetvdb.com/login"];
    NSData *data = [SBMetadataHelper downloadDataFromURL:url HTTPMethod:@"POST" HTTPBody:jsonApiKey headerOptions:headerOptions cachePolicy:SBDefaultPolicy];

    if (data) {
        id response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSString *token = response[@"token"];
            if ([token isKindOfClass:[NSString class]]) {
                globalToken = token;
            }
        }
    }
}

- (NSData *)requestData:(NSURL *)url language:(NSString *)language
{
    if (globalToken == nil) {
        [self updateToken];
    }

    NSDictionary *headerOptions = @{@"Authorization" : [NSString stringWithFormat:@"Bearer %@", globalToken],
                                    @"Content-Type" : @"application/json",
                                    @"Accept" : @"application/json",
                                    @"Accept-Language" : language};
    NSData *data = [SBMetadataHelper downloadDataFromURL:url HTTPMethod:@"GET" HTTPBody:nil headerOptions:headerOptions cachePolicy:SBDefaultPolicy];

    return data;
}

NSInteger sortSBMetadataResult(id ep1, id ep2, void *context)
{
    int v1 = [((SBMetadataResult *) ep1)[SBMetadataResultEpisodeNumber] intValue];
    int v2 = [((SBMetadataResult *) ep2)[SBMetadataResultEpisodeNumber] intValue];

    int s1 = [((SBMetadataResult *) ep1)[SBMetadataResultSeason] intValue];
    int s2 = [((SBMetadataResult *) ep2)[SBMetadataResultSeason] intValue];

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

- (NSArray<NSString *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage
{
	// search for series
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://thetvdb.com/api/GetSeries.php?seriesname=%@&language=all", [SBMetadataHelper urlEncoded:aSeriesName]]];

	NSData *seriesXML = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBDefaultPolicy];
	NSDictionary *series = [XMLReader dictionaryForXMLData:seriesXML error:NULL];

    if (!series) { return @[]; }

	NSArray *seriesArray = [series retrieveArrayForPath:@"Data.Series"];
	NSMutableSet *results = [[NSMutableSet alloc] initWithCapacity:seriesArray.count];
	for (NSDictionary *s in seriesArray) {
		[results addObject:[s retrieveForPath:@"SeriesName.text"]];
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

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
	NSString *lang = aLanguage;
    if (!lang) { lang = @"en"; }

	// search for series
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/search/series?name=%@", [SBMetadataHelper urlEncoded:aSeriesName]]];
    NSData *seriesJSON = [self requestData:url language:lang];

    if (!seriesJSON) { return @[]; }

	NSDictionary *series = [NSJSONSerialization JSONObjectWithData:seriesJSON options:0 error:NULL];

    if (!series || ![series isKindOfClass:[NSDictionary class]]) { return @[]; }

	NSArray<NSDictionary *> *seriesObject = series[@"data"];
	NSMutableSet<NSDictionary *> *selectedSeries = [[NSMutableSet alloc] init];

	if ([seriesObject isKindOfClass:[NSArray class]] && seriesObject.count) {

        for (NSDictionary *s in seriesObject) {
            if ([self seriesResult:s matchName:aSeriesName]) {
                [selectedSeries addObject:s];
            }
        }

        if (!selectedSeries.count) {
            [selectedSeries addObject:seriesObject.firstObject];
        }
	}

    NSMutableArray *results = [[NSMutableArray alloc] init];

    for (NSDictionary *s in selectedSeries) {

        NSNumber *seriesID = s[@"id"];
        NSString *seriesName = s[@"seriesName"];

        if (!seriesID || ![seriesID isKindOfClass:[NSNumber class]]) {
            continue;
        }

        if (!seriesName || ![seriesName isKindOfClass:[NSString class]]) {
            continue;
        }

        // Series info

        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@", seriesID]];
        NSData *seriesInfoJSON = [self requestData:url language:lang];

        if (!seriesJSON) { continue; }

        NSDictionary *seriesInfo = [NSJSONSerialization JSONObjectWithData:seriesInfoJSON options:0 error:NULL];

        if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { continue; }

        seriesInfo = seriesInfo[@"data"];

        if (!seriesInfo || ![seriesInfo isKindOfClass:[NSDictionary class]]) { continue; }

        // Series actors

        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/actors", seriesID]];
        NSData *seriesActorsJSON = [self requestData:url language:lang];

        if (!seriesActorsJSON) { continue; }

        NSDictionary *seriesActorsDictionary = [NSJSONSerialization JSONObjectWithData:seriesActorsJSON options:0 error:NULL];

        if (!seriesActorsDictionary || ![seriesActorsDictionary isKindOfClass:[NSDictionary class]]) { continue; }

        NSArray *seriesActors = seriesActorsDictionary[@"data"];

        if (!seriesActors || ![seriesActors isKindOfClass:[NSArray class]]) { continue; }

        // Series episodes info

        if (aSeasonNum.length && aEpisodeNum.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@&airedEpisode=%@", seriesID, aSeasonNum, aEpisodeNum]];
        } else if (aSeasonNum.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes/query?airedSeason=%@", seriesID, aSeasonNum]];
        }
        else {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.thetvdb.com/series/%@/episodes", seriesID]];
        }

        NSData *episodesJSON = [self requestData:url language:lang];

        if (!episodesJSON) { continue; }

        NSDictionary *episodes = [NSJSONSerialization JSONObjectWithData:episodesJSON options:0 error:NULL];

        if (!episodes || ![episodes isKindOfClass:[NSDictionary class]]) { continue; }

        // Decode the individual episodes

        NSArray<NSDictionary *> *episodesArray = episodes[@"data"];

        if ([episodesArray isKindOfClass:[NSArray class]]) {

            for (NSDictionary *episode in episodesArray) {
                if (aSeasonNum && aSeasonNum.length) {
                    NSString *episodeSeason = [episode[@"airedSeason"] stringValue];
                    if ([episodeSeason isEqualToString:aSeasonNum]) {
                        if (aEpisodeNum && aEpisodeNum.length) {
                            NSString *episodeNumber = [episode[@"airedEpisodeNumber"] stringValue];
                            if ([episodeNumber isEqualToString:aEpisodeNum]) {
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


    NSArray<SBMetadataResult *> *resultsSorted = [results sortedArrayUsingFunction:sortSBMetadataResult context:NULL];
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
    NSData *imagesJSON = [self requestData:url language:language];

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
    NSData *episodesJSON = [self requestData:episodesUrl language:aLanguage];

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

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)aEpisode series:(NSDictionary *)aSeries actors:(NSArray *)actors
{
	SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

	metadata.mediaKind = 10; // TV show

    // TV Show
    metadata[@"TheTVDB Series ID"]              = aSeries[@"id"];
    metadata[SBMetadataResultSeriesName]        = aSeries[@"seriesName"];
    metadata[SBMetadataResultSeriesDescription] = aSeries[@"overview"];
    metadata[SBMetadataResultGenre]             = [SBTheTVDB cleanList:aSeries[@"genre"]];

    // Episode
    metadata[@"TheTVDB Episodes ID"]          = aEpisode[@"id"];
    metadata[SBMetadataResultName]            = aEpisode[@"episodeName"];
    metadata[SBMetadataResultReleaseDate]     = aEpisode[@"firstAired"];
    metadata[SBMetadataResultDescription]     = aEpisode[@"overview"];
    metadata[SBMetadataResultLongDescription] = aEpisode[@"overview"];

    NSString *ratingString = aSeries[@"rating"];
    if (ratingString.length) {
        metadata[SBMetadataResultRating] = [[MP42Ratings defaultManager] ratingStringForiTunesCountry:@"USA"
                                                                                    media:@"TV"
                                                                             ratingString:ratingString];
    }

    metadata[SBMetadataResultNetwork] = aSeries[@"network"];
    metadata[SBMetadataResultSeason]  = aEpisode[@"airedSeason"];

    NSString *episodeID = [NSString stringWithFormat:@"%d%02d",
                            [aEpisode[@"airedSeason"] intValue],
                            [aEpisode[@"airedEpisodeNumber"] intValue]];

    metadata[SBMetadataResultEpisodeID]     = episodeID;
    metadata[SBMetadataResultEpisodeNumber] = aEpisode[@"airedEpisodeNumber"];
    metadata[SBMetadataResultTrackNumber]   = aEpisode[@"airedEpisodeNumber"];

    // Actors
    metadata[SBMetadataResultCast] = [SBTheTVDB cleanActorsList:actors];

    // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
	// "Copyright", "Comments", "Producers", "Artist"

	return metadata;
}

@end
