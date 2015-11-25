//
//  MetadataImporter.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import "MetadataImporter.h"

#import "SBMetadataSearchController.h"

#import "iTunesStore.h"
#import "TheMovieDB3.h"
#import "TheTVDB.h"

@interface MetadataImporter ()

@property (atomic, readwrite) BOOL isCancelled;

@end

@implementation MetadataImporter

@synthesize isCancelled = _isCancelled;

#pragma mark Class methods

+ (NSArray<NSString *> *)movieProviders {
    return @[@"TheMovieDB", @"iTunes Store"];
}
+ (NSArray<NSString *> *)tvProviders {
    return @[@"TheTVDB", @"iTunes Store"];
}

+ (NSArray<NSString *> *)languagesForProvider:(NSString *)aProvider {
	MetadataImporter *m = [MetadataImporter importerForProvider:aProvider];
	NSArray *a = [m languages];
	return a;
}

+ (instancetype)importerForProvider:(NSString *)aProvider {
	if ([aProvider isEqualToString:@"iTunes Store"]) {
		return [[[iTunesStore alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheMovieDB"]) {
		return [[[TheMovieDB3 alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheTVDB"]) {
		return [[[TheTVDB alloc] init] autorelease];
	}
	return nil;
}

+ (instancetype)defaultMovieProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
}

+ (instancetype)defaultTVProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
}

+ (NSString *)defaultMovieLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [defaults valueForKey:@"SBMetadataPreference|Movie"]]];
}

+ (NSString *)defaultTVLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [defaults valueForKey:@"SBMetadataPreference|TV"]]];
}

+ (NSString *)defaultLanguageForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"iTunes Store"]) {
        return @"USA (English)";
    } else {
        return @"English";
    }
}

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchMovie:aMovieTitle language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)loadFullMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(MP42Metadata * _Nullable metadata))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (aMetadata.mediaKind == 9) {
                [self loadMovieMetadata:aMetadata language:aLanguage];
            } else if (aMetadata.mediaKind == 10) {
                [self loadTVMetadata:aMetadata language:aLanguage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(aMetadata);
                }
            });
    });
}

- (void)cancel {
    self.isCancelled = YES;
}

#pragma mark Methods to be overridden

- (NSArray<NSString *> *) languages {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<MP42Metadata *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage  {
	TheTVDB *searcher = [[TheTVDB alloc] init];
	NSArray *a = [searcher searchTVSeries:aSeriesName language:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|TheTVDB|Language"]];
	[searcher release];
	return a;
}

- (NSArray<MP42Metadata *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata *)loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<MP42Metadata *> *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata *)loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

@end
