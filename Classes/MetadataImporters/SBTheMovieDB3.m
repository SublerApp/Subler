//
//  TheMovieDB3.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Ratings.h>
#import <MP42Foundation/MP42Languages.h>

#import "SBTheMovieDB3.h"
#import "SBiTunesStore.h"

#define API_KEY @"b0073bafb08b4f68df101eb2325f27dc"

@implementation SBTheMovieDB3

- (NSArray<NSString *> *)languages
{
	return [[MP42Languages defaultManager] ISO_639_1Languages];
}

- (SBMetadataImporterLanguageType)languageType
{
    return SBMetadataImporterLanguageTypeISO;
}

- (NSArray<SBMetadataResult *> *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage
{
	NSString *lang = aLanguage;

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/search/movie?api_key=%@&query=%@&language=%@",
                                       API_KEY, [SBMetadataHelper urlEncoded:aMovieTitle], lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBCachePolicyDefault];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {
            return [SBTheMovieDB3 metadataForResults:d];
        }
	}

	return @[];
}

- (SBMetadataResult *)artworksForResult:(NSDictionary *)r metadata:(SBMetadataResult *)aMetadata
{
    // artwork
	NSMutableArray *remoteArtworks = [NSMutableArray array];

    // add iTunes artwork
    SBMetadataResult *iTunesMetadata = [SBiTunesStore quickiTunesSearchMovie:aMetadata[SBMetadataResultName]];

	if (iTunesMetadata && iTunesMetadata.remoteArtworks.count) {
		[remoteArtworks addObjectsFromArray:iTunesMetadata.remoteArtworks];
	}

    // load image variables from configuration
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/configuration?api_key=%@", API_KEY]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBCachePolicyDefault];
    NSArray *posters = r[@"images"][@"posters"];

    if (jsonData && posters && [posters isKindOfClass:[NSArray class]]) {
        NSDictionary *config = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

		if ([config isKindOfClass:[NSDictionary class]] && config[@"images"]) {
			NSString *imageBaseUrl = config[@"images"][@"secure_base_url"];
			NSString *posterThumbnailSize = [config[@"images"][@"poster_sizes"] firstObject];
			NSString *backdropThumbnailSize = [config[@"images"][@"backdrop_sizes"] firstObject];

            for (NSDictionary *poster in posters) {
                if (poster[@"file_path"] && (poster[@"file_path"] != [NSNull null])) {
                    [remoteArtworks addObject:[SBRemoteImage remoteImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", poster[@"file_path"]]]
                                                                       thumbURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, poster[@"file_path"]]]
                                                                   providerName:@"TheMovieDB|poster"]];
                }
            }
            if (!posters.count && r[@"poster_path"] && (r[@"poster_path"] != [NSNull null])) {
                [remoteArtworks addObject:[SBRemoteImage remoteImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", r[@"poster_path"]]]
                                                                   thumbURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, r[@"poster_path"]]]
                                                               providerName:@"TheMovieDB|poster"]];
			}

			if (r[@"backdrop_path"] && (r[@"backdrop_path"] != [NSNull null])) {
                [remoteArtworks addObject:[SBRemoteImage remoteImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", r[@"backdrop_path"]]]
                                                                   thumbURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, backdropThumbnailSize, r[@"backdrop_path"]]]
                                                               providerName:@"TheMovieDB|poster"]];
			}
		}

    }

    aMetadata.remoteArtworks = remoteArtworks;

    return aMetadata;
}

- (SBMetadataResult *)loadMovieMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage
{
	NSString *lang = aLanguage;
	NSNumber *theMovieDBID = aMetadata[@"TheMovieDB ID"];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/movie/%@?api_key=%@&language=%@&append_to_response=casts,releases,images",
                                       theMovieDBID, API_KEY, lang]];
	NSData *jsonData = [SBMetadataHelper downloadDataFromURL:url cachePolicy:SBCachePolicyDefault];

	if (jsonData) {
        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if ([d isKindOfClass:[NSDictionary class]]) {

            SBMetadataResult *r = [SBTheMovieDB3 metadataForResult:d language:lang];
            if (r) {
                [aMetadata merge:r];
            }
            aMetadata = [self artworksForResult:d metadata:aMetadata];
        }
	}

	return aMetadata;
}

#pragma mark Parse results

+ (NSString *)commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey {
	if (aArray.count == 0) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray arrayWithCapacity:aArray.count];
	for (NSDictionary *d in aArray) {
		if (d[aKey]) {
			[r addObject:d[aKey]];
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (NSString *)commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey withKey:(NSString *)aWithKey equalTo:(NSString *)aEqualTo {
	if (aArray.count == 0) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray array];
	for (NSDictionary *d in aArray) {
		if (d[aKey]) {
			if ([d[aWithKey] isEqualToString:aEqualTo]) {
				[r addObject:d[aKey]];
			}
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (SBMetadataResult *)metadataForResult:(NSDictionary<NSString *, id> *)r language:(NSString *)language
{
	SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

	metadata.mediaKind = 9; // movie
    metadata[@"TheMovieDB ID"]                = r[@"id"];
    metadata[SBMetadataResultName]            = r[@"title"];
    metadata[SBMetadataResultReleaseDate]     = r[@"release_date"];
    metadata[SBMetadataResultGenre]           = [SBTheMovieDB3 commaJoinedSubentriesOf:r[@"genres"] forKey:@"name"];
    metadata[SBMetadataResultDescription]     = r[@"overview"];
    metadata[SBMetadataResultLongDescription] = r[@"overview"];
    metadata[SBMetadataResultStudio]          = [SBTheMovieDB3 commaJoinedSubentriesOf:r[@"production_companies"] forKey:@"name"];

    NSDictionary<NSString *, NSArray *> *casts = r[@"casts"];
    metadata[SBMetadataResultCast]              = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"cast"] forKey:@"name"];
    metadata[SBMetadataResultDirector]          = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"];
    metadata[SBMetadataResultProducers]         = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Producer"];
    metadata[SBMetadataResultExecutiveProducer] = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Executive Producer"];
    metadata[SBMetadataResultScreenwriters]     = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"department" equalTo:@"Writing"];
    metadata[SBMetadataResultComposer]          = [SBTheMovieDB3 commaJoinedSubentriesOf:casts[@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Original Music Composer"];

    if (language) {
        NSArray<NSDictionary *> *countries = r[@"releases"][@"countries"];

        for (NSDictionary *d in countries) {
            if ([d[@"iso_3166_1"] isEqualToString:@"US"]) {
                metadata[SBMetadataResultRating] = [[MP42Ratings defaultManager] ratingStringForiTunesCountry:@"USA" media:@"movie" ratingString:d[@"certification"]];
            }
        }
    }

    return metadata;
}

+ (NSArray<SBMetadataResult *> *)metadataForResults:(NSDictionary *)dict
{
	NSArray *resultsArray = dict[@"results"];
    NSMutableArray<SBMetadataResult *> *returnArray = [NSMutableArray array];

	for (NSDictionary *r in resultsArray) {
        if ([r isKindOfClass:[NSDictionary class]]) {
            SBMetadataResult *metadata = [SBTheMovieDB3 metadataForResult:r language:nil];
            [returnArray addObject:metadata];
        }
	}

    return returnArray;
}

@end
