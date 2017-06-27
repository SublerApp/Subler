//
//  MetadataImporter.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Languages.h>

#import "SBMetadataImporter.h"

#import "SBiTunesStore.h"
#import "Subler-Swift.h"

@interface SBMetadataImporter ()

@property (atomic, readwrite) BOOL isCancelled;

@end

@implementation SBMetadataImporter

#pragma mark Class methods

+ (NSArray<NSString *> *)movieProviders {
    return @[@"TheMovieDB", @"iTunes Store"];
}
+ (NSArray<NSString *> *)tvProviders {
    return @[@"TheTVDB", @"iTunes Store"];
}

+ (NSArray<NSString *> *)languagesForProvider:(NSString *)providerName {
	return [SBMetadataImporter importerForProvider:providerName].languages;
}

+ (SBMetadataImporterLanguageType)languageTypeForProvider:(NSString *)providerName {
    return [SBMetadataImporter importerForProvider:providerName].languageType;
}

+ (nullable instancetype)importerForProvider:(NSString *)aProvider {
	if ([aProvider isEqualToString:@"iTunes Store"]) {
		return [[SBiTunesStore alloc] init];
	}
    else if ([aProvider isEqualToString:@"TheMovieDB"]) {
		return [[TheMovieDB alloc] init];
	}
    else if ([aProvider isEqualToString:@"TheTVDB"]) {
		return [[TheTVDB alloc] init];
	}
	return nil;
}

+ (instancetype)defaultMovieProvider {
	return [SBMetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
}

+ (instancetype)defaultTVProvider {
	return [SBMetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
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
        return @"en";
    }
}

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<NSString *> *results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray<SBMetadataResult *> *results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<SBMetadataResult *> *results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchMovie:aMovieTitle language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)loadFullMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(SBMetadataResult * _Nullable metadata))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        SBMetadataResult *result = aMetadata;
        if (aMetadata.mediaKind == 9) {
            result = [self loadMovieMetadata:aMetadata language:aLanguage];
        } else if (aMetadata.mediaKind == 10) {
            result = [self loadTVMetadata:aMetadata language:aLanguage];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.isCancelled) {
                handler(result);
            }
        });
    });
}

- (void)cancel {
    self.isCancelled = YES;
}

#pragma mark Methods to be overridden

- (SBMetadataImporterLanguageType)languageType {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (NSArray<NSString *> *) languages {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<NSString *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage  {
	TheTVDB *searcher = [[TheTVDB alloc] init];
	NSArray *a = [searcher searchTVSeries:aSeriesName language:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|TheTVDB|Language"]];
	return a;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<SBMetadataResult *> *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (SBMetadataResult *)loadMovieMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

@end
