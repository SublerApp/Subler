//
//  MetadataImporter.h
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <Foundation/Foundation.h>
#import "SBMetadataHelper.h"

@class MP42Metadata;

NS_ASSUME_NONNULL_BEGIN

@interface MetadataImporter : NSObject {
@private
    BOOL _isCancelled;
}

#pragma mark Class methods
+ (NSArray<NSString *> *) movieProviders;
+ (NSArray<NSString *> *) tvProviders;
+ (NSArray<NSString *> *) languagesForProvider:(NSString *)aProvider;
+ (instancetype) importerForProvider:(NSString *)aProviderName;
+ (instancetype) defaultMovieProvider;
+ (instancetype) defaultTVProvider;
+ (NSString *) defaultMovieLanguage;
+ (NSString *) defaultTVLanguage;

+ (NSString *) defaultLanguageForProvider:(NSString *)provider;

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler;
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler;

- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler;

- (void) loadFullMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(MP42Metadata * _Nullable metadata))handler;

- (void) cancel;

#pragma mark Methods to be overridden
- (NSArray<NSString *> *) languages;

- (nullable NSArray<MP42Metadata *> *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage;
- (nullable NSArray<MP42Metadata *> *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(nullable NSString *)aSeasonNum episodeNum:(nullable NSString *)aEpisodeNum;

- (nullable NSArray<MP42Metadata *> *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage;

- (nullable MP42Metadata *) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;
- (nullable MP42Metadata *) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;

@end

NS_ASSUME_NONNULL_END
