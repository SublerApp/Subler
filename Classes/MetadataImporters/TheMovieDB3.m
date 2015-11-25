//
//  TheMovieDB3.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBMetadataSearchController.h"

#import "TheMovieDB3.h"
#import "iTunesStore.h"

#define API_KEY @"b0073bafb08b4f68df101eb2325f27dc"

@implementation TheMovieDB3

- (NSArray *) languages {
	return [[MP42Languages defaultManager] iso6391languages];
}

- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	NSString *lang = [MP42Languages iso6391CodeFor:aLanguage];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/search/movie?api_key=%@&query=%@&language=%@", API_KEY, [SBMetadataHelper urlEncoded:aMovieTitle], lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            return [TheMovieDB3 metadataForResults:d];
        }
	}
	return nil;
}

- (MP42Metadata *) artworksForResult:(NSDictionary *)r metadata:(MP42Metadata *)aMetadata {
    // artwork
	NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:2];
	NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:1];
	NSMutableArray *artworkProviderNames = [[NSMutableArray alloc] initWithCapacity:1];

    // add iTunes artwork
    MP42Metadata *iTunesMetadata = [iTunesStore quickiTunesSearchMovie:[[aMetadata tagsDict] valueForKey:@"Name"]];
	if (iTunesMetadata && [iTunesMetadata artworkThumbURLs] && [iTunesMetadata artworkFullsizeURLs] && ([[iTunesMetadata artworkThumbURLs] count] == [[iTunesMetadata artworkFullsizeURLs] count])) {
		[artworkThumbURLs addObjectsFromArray:[iTunesMetadata artworkThumbURLs]];
		[artworkFullsizeURLs addObjectsFromArray:[iTunesMetadata artworkFullsizeURLs]];
		[artworkProviderNames addObjectsFromArray:[iTunesMetadata artworkProviderNames]];
	}

    // load image variables from configuration
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/configuration?api_key=%@", API_KEY]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
    NSArray *posters = [r valueForKeyPath:@"images.posters"];

    if (jsonData && posters && [posters isKindOfClass:[NSArray class]]) {
        NSDictionary *config = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

		if ([config isKindOfClass:[NSDictionary class]] && [config valueForKey:@"images"]) {
			NSString *imageBaseUrl = [[config valueForKey:@"images"] valueForKey:@"secure_base_url"];
			NSString *posterThumbnailSize = [[[config valueForKey:@"images"] valueForKey:@"poster_sizes"] objectAtIndex:0];
			NSString *backdropThumbnailSize = [[[config valueForKey:@"images"] valueForKey:@"backdrop_sizes"] objectAtIndex:0];

            for (NSDictionary *poster in posters) {
                if ([poster valueForKey:@"file_path"] && ([poster valueForKey:@"file_path"] != [NSNull null])) {
                    [artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, [poster valueForKey:@"file_path"]]]];
                    [artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", [poster valueForKey:@"file_path"]]]];
                    [artworkProviderNames addObject:@"TheMovieDB|poster"];
                }
            }
            if (![posters count] && [r valueForKey:@"poster_path"] && ([r valueForKey:@"poster_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, [r valueForKey:@"poster_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", [r valueForKey:@"poster_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|poster"];
			}

			if ([r valueForKey:@"backdrop_path"] && ([r valueForKey:@"backdrop_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, backdropThumbnailSize, [r valueForKey:@"backdrop_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", [r valueForKey:@"backdrop_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|backdrop"];
			}
		}

    }

	[aMetadata setArtworkThumbURLs:artworkThumbURLs];
	[aMetadata setArtworkFullsizeURLs:artworkFullsizeURLs];
	[aMetadata setArtworkProviderNames:artworkProviderNames];
	[artworkThumbURLs release];
	[artworkFullsizeURLs release];
	[artworkProviderNames release];

    return aMetadata;
}

- (MP42Metadata *) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	NSString *lang = [MP42Languages iso6391CodeFor:aLanguage];
	NSNumber *theMovieDBID = [[aMetadata tagsDict] valueForKey:@"TheMovieDB ID"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/movie/%@?api_key=%@&language=%@&append_to_response=casts,releases,images", theMovieDBID, API_KEY, lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url withCachePolicy:SBDefaultPolicy];
	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {

            MP42Metadata *r = [TheMovieDB3 metadataForResult:d language:lang];
            if (r) {
                [aMetadata mergeMetadata:r];
            }
            aMetadata = [self artworksForResult:d metadata:aMetadata];
        }
	}

	return aMetadata;
}

#pragma mark Parse results

+ (NSString *) commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey {
	if (!aArray || ([aArray count] == 0)) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray arrayWithCapacity:[aArray count]];
	for (NSDictionary *d in aArray) {
		if ([d valueForKey:aKey]) {
			[r addObject:[d valueForKey:aKey]];
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (NSString *) commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey withKey:(NSString *)aWithKey equalTo:(NSString *)aEqualTo {
	if (!aArray || ([aArray count] == 0)) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray array];
	for (NSDictionary *d in aArray) {
		if ([d valueForKey:aKey]) {
			if ([d valueForKey:aWithKey] && [[d valueForKey:aWithKey] isEqualToString:aEqualTo]) {
				[r addObject:[d valueForKey:aKey]];
			}
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (MP42Metadata *) metadataForResult:(NSDictionary *)r language:(NSString *)aLanguage {
	MP42Metadata *metadata = [[MP42Metadata alloc] init];
	metadata.mediaKind = 9; // movie
	[metadata setTag:[r valueForKey:@"id"] forKey:@"TheMovieDB ID"];
	[metadata setTag:[r valueForKey:@"title"] forKey:@"Name"];
	[metadata setTag:[r valueForKey:@"release_date"] forKey:@"Release Date"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[r valueForKey:@"genres"] forKey:@"name"] forKey:@"Genre"];
    [metadata setTag:[r valueForKey:@"overview"] forKey:@"Description"];
	[metadata setTag:[r valueForKey:@"overview"] forKey:@"Long Description"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[r valueForKey:@"production_companies"] forKey:@"name"] forKey:@"Studio"];
	NSDictionary *casts = [r valueForKey:@"casts"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"cast"] forKey:@"name"] forKey:@"Cast"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"] forKey:@"Director"];
    [metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"] forKey:@"Artist"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Producer"] forKey:@"Producers"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Executive Producer"] forKey:@"Executive Producer"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"department" equalTo:@"Writing"] forKey:@"Screenwriters"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Original Music Composer"] forKey:@"Composer"];
    
    if (aLanguage) {
        NSArray *countries = [[r valueForKey:@"releases"] valueForKey:@"countries"];
        
        for (NSDictionary *d in countries) {
            if ([[d valueForKey:@"iso_3166_1"] isEqualToString:@"US"]) {
                [metadata setTag:[NSNumber numberWithUnsignedInteger:
                                  [[MP42Ratings defaultManager] ratingIndexForiTunesCountry:@"USA" media:@"movie" ratingString:[d valueForKey:@"certification"]]] forKey:@"Rating"]   ;

            }
        }
    }

    return [metadata autorelease];
}

+ (NSArray *) metadataForResults:(NSDictionary *)dict {
	NSArray *resultsArray = [dict valueForKey:@"results"];
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:[resultsArray count]];
	for (NSDictionary *r in resultsArray) {
        if ([r isKindOfClass:[NSDictionary class]]) {
            MP42Metadata *metadata = [TheMovieDB3 metadataForResult:r language:nil];
            [returnArray addObject:metadata];
        }
	}
    return [returnArray autorelease];
}

@end
