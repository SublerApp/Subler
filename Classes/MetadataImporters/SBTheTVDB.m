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

@implementation SBTheTVDB

+ (void)initialize
{
    if (self == [SBTheTVDB class]) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/%@/languages.xml", API_KEY]];
        NSData *languagesXML = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBReturnCacheElseLoad];
        NSDictionary *languages = [XMLReader dictionaryForXMLData:languagesXML error:NULL];

        if (languages) {
            NSArray *languagesArray = [languages retrieveArrayForPath:@"Languages.Language"];
            NSMutableArray<NSString *> *languagesResult = [NSMutableArray array];

            if ([languagesArray isKindOfClass:[NSArray class]] && languagesArray.count) {
                for (NSDictionary *language in languagesArray) {
                    NSString *lang = [language valueForKeyPath:@"abbreviation.text"];
                    if (lang && [lang isKindOfClass:[NSString class]]) {
                        iso639_lang_t *isoLanguage = lang_for_code_s(lang.UTF8String);
                        [languagesResult addObject:@(isoLanguage->eng_name)];
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

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage
{
	// search for series
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/GetSeries.php?seriesname=%@&language=all", [SBMetadataHelper urlEncoded:aSeriesName]]];

	NSData *seriesXML = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	NSDictionary *series = [XMLReader dictionaryForXMLData:seriesXML error:NULL];

    if (!series) { return @[]; }

	NSArray *seriesArray = [series retrieveArrayForPath:@"Data.Series"];
	NSMutableSet *results = [[NSMutableSet alloc] initWithCapacity:seriesArray.count];
	for (NSDictionary *s in seriesArray) {
		[results addObject:[s retrieveForPath:@"SeriesName.text"]];
	}
	return results.allObjects;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
	NSString *lang = [MP42Languages iso6391CodeFor:aLanguage];
    if (!lang) { lang = @"en"; }

	// search for series
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/GetSeries.php?seriesname=%@&language=all", [SBMetadataHelper urlEncoded:aSeriesName]]];
	NSData *seriesXML = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	NSDictionary *series = [XMLReader dictionaryForXMLData:seriesXML error:NULL];

    if (!series) { return @[]; }

	NSArray *seriesObject = [series retrieveForPath:@"Data.Series"];
	NSMutableSet *seriesIDs = [[NSMutableSet alloc] init];;
	if ([seriesObject isKindOfClass:[NSArray class]]) {
        for (NSDictionary *s in seriesObject) {
            if ([aSeriesName isEqualToString:[s retrieveForPath:@"SeriesName.text"]]) {
                [seriesIDs addObject:[s retrieveForPath:@"seriesid.text"]];
            }
        }

        if (!seriesIDs.count) {
            [seriesIDs addObject:[series retrieveForPath:@"Data.Series.0.seriesid.text"]];
        }
	}
    else {
        NSString *seriesID = [series retrieveForPath:@"Data.Series.seriesid.text"];
        if (seriesID)
            [seriesIDs addObject:seriesID];
	}

    NSMutableArray *results = [[NSMutableArray alloc] init];

    if (seriesIDs.count) {
        for (NSString *seriesID in seriesIDs) {
            if (!seriesID.length) {
                continue;
            }

            url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/%@/series/%@/all/%@.xml", API_KEY, seriesID, lang]];
            NSData *episodesXML = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
            NSDictionary *episodes = [XMLReader dictionaryForXMLData:episodesXML error:NULL];

            if (!episodes) {
                continue;
            }

            NSArray *episodesArray = [episodes retrieveArrayForPath:@"Data.Episode"];
            NSDictionary *thisSeries = [episodes retrieveForPath:@"Data.Series"];

            for (NSDictionary *episode in episodesArray) {
                if (aSeasonNum && ![aSeasonNum isEqualToString:@""]) {
                    if ([[episode retrieveForPath:@"SeasonNumber.text"] isEqualToString:aSeasonNum]) {
                        if (aEpisodeNum && ![aEpisodeNum isEqualToString:@""]) {
                            if ([[episode retrieveForPath:@"EpisodeNumber.text"] isEqualToString:aEpisodeNum]) {
                                [results addObject:[SBTheTVDB metadataForEpisode:episode series:thisSeries]];
                            }
                        } else {
                            [results addObject:[SBTheTVDB metadataForEpisode:episode series:thisSeries]];
                        }
                    }
                } else {
                    [results addObject:[SBTheTVDB metadataForEpisode:episode series:thisSeries]];
                }
            }
        }
    }


	return results;
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage
{
	// add iTunes artwork
    SBMetadataResult *iTunesMetadata = [SBiTunesStore quickiTunesSearchTV:aMetadata[@"TV Show"] episodeTitle:aMetadata[@"Name"]];

	NSMutableArray *newArtworkThumbURLs = [NSMutableArray array];
	NSMutableArray *newArtworkFullsizeURLs = [NSMutableArray array];
	NSMutableArray *newArtworkProviderNames = [NSMutableArray array];

	if (iTunesMetadata && iTunesMetadata.artworkThumbURLs && iTunesMetadata.artworkFullsizeURLs &&
        (iTunesMetadata.artworkThumbURLs.count == iTunesMetadata.artworkFullsizeURLs.count)) {
		[newArtworkThumbURLs addObjectsFromArray:iTunesMetadata.artworkThumbURLs];
		[newArtworkFullsizeURLs addObjectsFromArray:iTunesMetadata.artworkFullsizeURLs];
		[newArtworkProviderNames addObjectsFromArray:iTunesMetadata.artworkProviderNames];
	}

	[newArtworkThumbURLs addObjectsFromArray:aMetadata.artworkThumbURLs];
	[newArtworkFullsizeURLs addObjectsFromArray:aMetadata.artworkFullsizeURLs];
	[newArtworkProviderNames addObjectsFromArray:aMetadata.artworkProviderNames];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/%@/series/%@/banners.xml", API_KEY, aMetadata[@"TheTVDB Series ID"]]];
	NSData *bannersXML = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	NSDictionary *banners = [XMLReader dictionaryForXMLData:bannersXML error:NULL];
    if (!banners) { return nil; }
	NSArray *bannersArray = [banners retrieveArrayForPath:@"Banners.Banner"];

	for (NSDictionary *banner in bannersArray) {
		if ([[banner retrieveForPath:@"BannerType.text"] isEqualToString:@"season"] &&
            [[banner retrieveForPath:@"BannerType2.text"] isEqualToString:@"season"] &&
            [[banner retrieveForPath:@"Season.text"] isEqualToString:aMetadata[@"TV Season"]]) {
			NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [banner retrieveForPath:@"BannerPath.text"]]];
			[newArtworkThumbURLs addObject:u];
			[newArtworkFullsizeURLs addObject:u];
			[newArtworkProviderNames addObject:[NSString stringWithFormat:@"TheTVDB|season %@", aMetadata[@"TV Season"]]];
		}
	}
	for (NSDictionary *banner in bannersArray) {
		if ([[banner retrieveForPath:@"BannerType.text"] isEqualToString:@"poster"]) {
			NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [banner retrieveForPath:@"BannerPath.text"]]];
			[newArtworkThumbURLs addObject:u];
			[newArtworkFullsizeURLs addObject:u];
			[newArtworkProviderNames addObject:@"TheTVDB|poster"];
		}
	}
	aMetadata.artworkThumbURLs = newArtworkThumbURLs;
	aMetadata.artworkFullsizeURLs = newArtworkFullsizeURLs;
	aMetadata.artworkProviderNames = newArtworkProviderNames;

	return aMetadata;
}

+ (NSString *)cleanPeopleList:(NSString *)s
{
    NSArray *a = [[[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
				   stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"|"]]
				  componentsSeparatedByString:@"|"];
    return [a componentsJoinedByString:@", "];
}

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)aEpisode series:(NSDictionary *)aSeries
{
	SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

	metadata.mediaKind = 10; // TV show

    // TV Show
    metadata[@"TheTVDB Series ID"]  = [aSeries retrieveForPath:@"id.text"];
    metadata[@"Series Name"]        = [aSeries retrieveForPath:@"SeriesName.text"];
    metadata[@"Series Description"] = [aSeries retrieveForPath:@"Overview.text"];
    metadata[@"Genre"]              = [SBTheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Genre.text"]];

    // Episode
    metadata[@"Name"]               = [aEpisode retrieveForPath:@"EpisodeName.text"];
    metadata[@"Release Date"]       = [aEpisode retrieveForPath:@"FirstAired.text"];
    metadata[@"Description"]        = [aEpisode retrieveForPath:@"Overview.text"];
    metadata[@"Long Description"]   = [aEpisode retrieveForPath:@"Overview.text"];

    NSString *ratingString = [aSeries retrieveForPath:@"ContentRating.text"];
    if (ratingString.length) {
        metadata[@"Rating"] = @([[MP42Ratings defaultManager] ratingIndexForiTunesCountry:@"USA"
                                                                                    media:@"TV"
                                                                             ratingString:ratingString]);
    }

    metadata[@"Network"]     = [aSeries retrieveForPath:@"Network.text"];
    metadata[@"Season"]      = [aEpisode retrieveForPath:@"SeasonNumber.text"];

    NSString *episodeID = [NSString stringWithFormat:@"%d%02d",
                            [[aEpisode retrieveForPath:@"SeasonNumber.text"] intValue],
                            [[aEpisode retrieveForPath:@"EpisodeNumber.text"] intValue]];

    metadata[@"Episode ID"]     = episodeID;
    metadata[@"Episode #"]      = [aEpisode retrieveForPath:@"EpisodeNumber.text"];
    metadata[@"Track #"]        = [aEpisode retrieveForPath:@"EpisodeNumber.text"];

    metadata[@"Director"]        = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Director.text"]];
    metadata[@"Screenwriters"]   = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Writer.text"]];

	// Cast
	NSString *actors = [SBTheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Actors.text"]];
	NSString *gueststars = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"GuestStars.text"]];
	if (actors.length) {
		if (gueststars.length) {
            metadata[@"Cast"] = [NSString stringWithFormat:@"%@, %@", actors, gueststars];
		}
        else {
            metadata[@"Cast"] = actors;
		}
	} else {
		if (gueststars.length) {
            metadata[@"Cast"] = gueststars;
		}
	}

	// Artwork
	NSMutableArray *artworkThumbURLs = [NSMutableArray array];
	NSMutableArray *artworkFullsizeURLs = [NSMutableArray array];
	NSMutableArray *artworkProviderNames = [NSMutableArray array];

	if ([aEpisode retrieveForPath:@"filename.text"]) {
		NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [aEpisode retrieveForPath:@"filename.text"]]];
		[artworkThumbURLs addObject:u];
		[artworkFullsizeURLs addObject:u];
		[artworkProviderNames addObject:@"TheTVDB|episode"];
	}

	metadata.artworkThumbURLs = artworkThumbURLs;
	metadata.artworkFullsizeURLs = artworkFullsizeURLs;
	metadata.artworkProviderNames = artworkProviderNames;

    // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
	// "Copyright", "Comments", "Producers", "Artist"

	return metadata;
}

@end
