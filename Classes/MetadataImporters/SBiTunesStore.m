//
//  iTunesStore.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <MP42Foundation/MP42Ratings.h>

#import "SBiTunesStore.h"

@implementation SBiTunesStore

#pragma mark iTunes stores

- (NSArray<NSString *>  *)languages
{
	NSString *iTunesStoresJSON = [[NSBundle mainBundle] pathForResource:@"iTunesStores" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:iTunesStoresJSON];

    NSMutableArray<NSString *>  *results = [[NSMutableArray alloc] init];

    if (data) {
        NSArray *iTunesStores = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        if ([iTunesStores isKindOfClass:[NSArray class]]) {
            for (NSDictionary *store in iTunesStores) {
                [results addObject:[NSString stringWithFormat:@"%@ (%@)", store[@"country"], store[@"language"]]];
            }
        }
    }

	return results;
}

+ (NSDictionary *)getStoreFor:(NSString *)aLanguageString
{
	NSString *iTunesStoresJSON = [[NSBundle mainBundle] pathForResource:@"iTunesStores" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:iTunesStoresJSON];

    if (data) {
        NSArray *iTunesStores = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        if ([iTunesStores isKindOfClass:[NSArray class]]) {
            for (NSDictionary *store in iTunesStores) {
                if (aLanguageString && [aLanguageString isEqualToString:[NSString stringWithFormat:@"%@ (%@)", store[@"country"], store[@"language"]]]) {
                    return store;
                }
            }
        }
    }

	return nil;
}

#pragma mark Search for TV episode metadata

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

- (NSArray *)filterResult:(NSArray *)results tvSeries:(NSString *)aSeriesName seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
    NSMutableArray *r = [[NSMutableArray alloc] init];
    for (SBMetadataResult *m in results) {
        if (!aSeriesName || [m[SBMetadataResultSeriesName] isEqualToString:aSeriesName]) {
            // Episode Number and Season Number
            if ((aEpisodeNum && aEpisodeNum.length) && (aSeasonNum && aSeasonNum.length)) {
                if ([[m[SBMetadataResultEpisodeNumber] stringValue] isEqualToString:aEpisodeNum] &&
                    [m[SBMetadataResultSeason] integerValue] == aSeasonNum.integerValue) {
                    [r addObject:m];
                }

            }
            // Episode Number only
            else if ((aEpisodeNum && aEpisodeNum.length) && !(aSeasonNum && aSeasonNum.length)) {
                if ([[m[SBMetadataResultEpisodeNumber] stringValue] isEqualToString:aEpisodeNum]) {
                    [r addObject:m];
                }

            }
            // Season Number only
            else if (!(aEpisodeNum && aEpisodeNum.length) && (aSeasonNum && aSeasonNum.length)) {
                if ([m[SBMetadataResultSeason] integerValue] == aSeasonNum.integerValue) {
                    [r addObject:m];
                }
            }
            else if (!(aEpisodeNum && aEpisodeNum.length) && !(aSeasonNum && aSeasonNum.length)) {
                [r addObject:m];
            }
        }
    }
    return r;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
	NSString *country = @"US";
	NSString *language = @"EN";
	NSString *season = @"season";

	NSDictionary *store = [SBiTunesStore getStoreFor:aLanguage];
	if (store) {
		country = store[@"country2"];
		language = store[@"language2"];
		if (store[@"season"] && ![store[@"season"] isEqualToString:@""]) {
			season = [store[@"season"] lowercaseString];
		}
	}
    else {
        return @[];
    }

	NSURL *url;
	if (aSeasonNum.length) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=tvSeasonTerm&entity=tvEpisode&limit=200", country, language.lowercaseString, [SBMetadataHelper urlEncoded:[NSString stringWithFormat:@"%@ %@ %@", aSeriesName, season, aSeasonNum]]]];
	}
    else {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=showTerm&entity=tvEpisode&limit=200", country, language.lowercaseString, [SBMetadataHelper urlEncoded:aSeriesName]]];
	}
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        if ([d isKindOfClass:[NSDictionary class]]) {

            NSArray<SBMetadataResult *> *results = [SBiTunesStore metadataForResults:d store:store];

            if ((results.count == 0) && ![aLanguage isEqualToString:@"USA (English)"]) {
                return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            }

            if ((results.count == 0) && aSeasonNum) {
                return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:nil episodeNum:aEpisodeNum];
            }

            // Filter results
            NSArray<SBMetadataResult *> *r = [self filterResult:results tvSeries:aSeriesName seasonNum:aSeasonNum episodeNum:aEpisodeNum];

            // If we don't have any result for the exact series name, relax the filter
            if (r.count == 0) {
                r = [self filterResult:results tvSeries:nil seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            }

            NSArray<SBMetadataResult *> *resultsSorted = [r sortedArrayUsingFunction:sortSBMetadataResult context:NULL];
            return resultsSorted;
        }
	}
	return @[];
}

#pragma mark Quick iTunes search for metadata

+ (nullable SBMetadataResult *)quickiTunesSearchTV:(NSString *)aSeriesName episodeTitle:(NSString *)aEpisodeTitle
{
	NSDictionary *store = [SBiTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = store[@"country2"];
	NSString *language = store[@"language2"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=tvEpisode", country, language.lowercaseString, [SBMetadataHelper urlEncoded:[NSString stringWithFormat:@"%@ %@", aSeriesName, aEpisodeTitle]]]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *results = [SBiTunesStore metadataForResults:d store:store];
                return results.firstObject;
        }
	}
	return nil;
}

+ (nullable SBMetadataResult *)quickiTunesSearchMovie:(NSString *)aMovieName
{
	NSDictionary *store = [SBiTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = store[@"country2"];
	NSString *language = store[@"language2"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=movie", country, language, [SBMetadataHelper urlEncoded:aMovieName]]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *results = [SBiTunesStore metadataForResults:d store:store];
            return results.firstObject;
        }
	}
	return nil;
}

#pragma mark Search for movie metadata

- (NSArray<SBMetadataResult *> *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage
{
	NSString *country = @"US";
	NSString *language = @"EN";

	NSDictionary *store = [SBiTunesStore getStoreFor:aLanguage];
	if (store) {
		country = store[@"country2"];
		language = store[@"language2"];
	}
    else {
        return @[];
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=movie&limit=150", country, language, [SBMetadataHelper urlEncoded:aMovieTitle]]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            return [SBiTunesStore metadataForResults:d store:store];
        }
	}
	return @[];
}

#pragma mark Load additional metadata

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)metadata language:(NSString *)language
{
	NSDictionary *store = [SBiTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = store[@"country2"];
	NSString *language2 = store[@"language2"];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?country=%@&lang=%@&id=%@", country, language2.lowercaseString, metadata[SBMetadataResultPlaylistID]]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *resultsArray = d[@"results"];
            if (resultsArray.count > 0) {
                NSDictionary *r = resultsArray.firstObject;
                metadata[SBMetadataResultSeriesDescription] = r[@"longDescription"];
            }
        }
	}
	return metadata;
}

- (SBMetadataResult *)loadMovieMetadata:(SBMetadataResult *)metadata language:(NSString *)language
{
	NSData *xmlData = [SBMetadataHelper downloadDataFromURL:[NSURL URLWithString:metadata[SBMetadataResultITunesURL]] withCachePolicy:SBDefaultPolicy];
	if (xmlData) {
        NSDictionary *store = [SBiTunesStore getStoreFor:language];
		NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:xmlData options:NSXMLDocumentTidyHTML error:NULL];

		NSArray *p = [SBiTunesStore readPeople:store[@"actor"] fromXML:xml];
        if (p.count) {
            metadata[SBMetadataResultCast] = [p componentsJoinedByString:@", "];
        }

		p = [SBiTunesStore readPeople:store[@"director"] fromXML:xml];
        if (p.count) {
            metadata[SBMetadataResultDirector] = [p componentsJoinedByString:@", "];
        }

		p = [SBiTunesStore readPeople:store[@"producer"] fromXML:xml];
        if (p.count) {
            metadata[SBMetadataResultProducers] = [p componentsJoinedByString:@", "];
        }

		p = [SBiTunesStore readPeople:store[@"screenwriter"] fromXML:xml];
        if (p.count) {
            metadata[SBMetadataResultScreenwriters] = [p componentsJoinedByString:@", "];
        }

		NSArray *nodes = [xml nodesForXPath:[NSString stringWithFormat:@"//li[@class='copyright']"] error:NULL];

		for (NSXMLNode *n in nodes) {
			NSString *copyright = n.stringValue;
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All Rights Reserved." withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All rights reserved." withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All Rights Reserved" withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All rights reserved" withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@" by " withString:@" "];
            metadata[SBMetadataResultCopyright] = copyright;
		}

    }
	
    return metadata;
}

#pragma mark Parse results

/* Scrape people from iTunes Store website HTML */
+ (NSArray *)readPeople:(NSString *)aPeople fromXML:(NSXMLDocument *)aXml {
	if (aXml) {
		NSArray *nodes = [aXml nodesForXPath:[NSString stringWithFormat:@"//div[starts-with(@metrics-loc,'Titledbox_%@')]", aPeople] error:NULL];
		for (NSXMLNode *n in nodes) {
			NSXMLDocument *subXML = [[NSXMLDocument alloc] initWithXMLString:n.XMLString options:0 error:NULL];
			if (subXML) {
				NSArray *subNodes = [subXML nodesForXPath:@"//a" error:NULL];
				NSMutableArray *r = [[NSMutableArray alloc] initWithCapacity:subNodes.count];
				for (NSXMLNode *sub in subNodes) {
					[r addObject:sub.stringValue];
				}
				return r;
			}
		}
	}
	return @[];
}

+ (NSArray<SBMetadataResult *> *)metadataForResults:(NSDictionary *)dict store:(NSDictionary *)store
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
	NSArray *resultsArray = dict[@"results"];

    for (NSDictionary<NSString *, id> *r in resultsArray) {

        // Skip if the result is not a track (for example an artist or a collection)
        if (![r[@"wrapperType"] isEqualToString:@"track"]) {
            continue;
        }

        SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

        metadata[SBMetadataResultName] = r[@"trackName"];

		if ([r[@"kind"] isEqualToString:@"feature-movie"]) {
			metadata.mediaKind = 9; // movie
            metadata[SBMetadataResultDirector] = r[@"artistName"];
		}
        else if ([r[@"kind"] isEqualToString:@"tv-episode"]) {
			metadata.mediaKind = 10; // TV show
            metadata[SBMetadataResultSeriesName] = r[@"artistName"];

			NSString *s = r[@"collectionName"];
            NSString *season = nil;

			if ([store[@"season"] length]) {
				NSArray *sa = [s.lowercaseString componentsSeparatedByString:[NSString stringWithFormat:@", %@ ", store[@"season"]]];
				if (sa.count <= 1) {
                    sa = [s.lowercaseString componentsSeparatedByString:[NSString stringWithFormat:@", %@ ", @"book"]];
                }

                if (sa.count > 1) {
                    season = [NSString stringWithFormat:@"%d", [sa[1] intValue]];
                }
                else {
                    season = @"1";
                }
			}

            if (season) {
                metadata[SBMetadataResultSeason]    = season;
                metadata[SBMetadataResultEpisodeID] = [NSString stringWithFormat:@"%d%02d", season.intValue, [r[@"trackNumber"] intValue]];
            }

            metadata[SBMetadataResultEpisodeNumber] = r[@"trackNumber"];
            metadata[SBMetadataResultTrackNumber]   = [NSString stringWithFormat:@"%@/%@", r[@"trackNumber"], r[@"trackCount"]];
            metadata[SBMetadataResultDiskNumber]    = @"1/1";
            metadata[SBMetadataResultArtistID]      = r[@"artistId"];
            metadata[SBMetadataResultPlaylistID]    = r[@"collectionId"];
		}

		// Metadata common to both TV episodes and movies
        metadata[SBMetadataResultReleaseDate]   = [r[@"releaseDate"] substringToIndex:10];

        if (r[@"shortDescription"]) {
            metadata[SBMetadataResultDescription]   = r[@"shortDescription"];
        }
        else {
            metadata[SBMetadataResultDescription]   = r[@"longDescription"];
        }

        metadata[SBMetadataResultLongDescription]   = r[@"longDescription"];
        metadata[SBMetadataResultGenre]             = r[@"primaryGenreName"];
        metadata[SBMetadataResultRating]            = [[MP42Ratings defaultManager] ratingStringForiTunesCountry:store[@"country"]
                                                                                                media:(metadata.mediaKind == 9 ? @"movie" : @"TV")
                                                                                         ratingString:r[@"contentAdvisoryRating"]];

		if (store[@"storeCode"]) {
            metadata[SBMetadataResultITunesCountry] = [store[@"storeCode"] stringValue];
		}

        metadata[SBMetadataResultITunesURL] = r[@"trackViewUrl"];
        metadata[SBMetadataResultContentID] =  r[@"trackId"];

		NSString *trackExplicitness = r[@"trackExplicitness"];
		if ([trackExplicitness isEqualToString:@"explicit"]) {
			metadata.contentRating = 4;
		} else if ([trackExplicitness isEqualToString:@"cleaned"]) {
			metadata.contentRating = 2;
		}

		// Artworks
		NSString *artworkString = r[@"artworkUrl100"];

        if (artworkString) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\{.*?\\})"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
            NSRange stringRange = NSMakeRange(0, artworkString.length);
            NSRange matchRange = [regex rangeOfFirstMatchInString:artworkString
                                                          options:0
                                                            range:stringRange];
            if (matchRange.length > 0) {
                artworkString = [artworkString stringByReplacingCharactersInRange:matchRange withString:@"bb"];
            }

            NSURL *artworkURL = [NSURL URLWithString:artworkString];
            NSURL *artworkFullSizeURL = [NSURL URLWithString:[artworkString stringByReplacingOccurrencesOfString:@"100x100bb" withString:@"1000x1000bb"]];

            if (metadata.mediaKind == 10) {
                artworkFullSizeURL = [NSURL URLWithString:[artworkString stringByReplacingOccurrencesOfString:@"100x100bb" withString:@"800x800bb"]];
            }

            if (artworkURL && artworkFullSizeURL) {
                metadata.artworkThumbURLs = @[artworkURL];
                metadata.artworkFullsizeURLs = @[artworkFullSizeURL];
                metadata.artworkProviderNames = @[@"iTunes"];
            }
        }

		// add to array
        [returnArray addObject:metadata];
		
	}
    return returnArray;
}

@end
