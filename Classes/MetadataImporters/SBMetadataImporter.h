//
//  MetadataImporter.h
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <Foundation/Foundation.h>
#import "SBMetadataHelper.h"
#import "SBMetadataResult.h"

@class MP42Metadata;

NS_ASSUME_NONNULL_BEGIN

@interface SBMetadataImporter : NSObject {
@private
    BOOL _isCancelled;
}

#pragma mark Class methods
+ (NSArray<NSString *> *) movieProviders;
+ (NSArray<NSString *> *) tvProviders;
+ (NSArray<NSString *> *) languagesForProvider:(NSString *)aProvider;
+ (nullable instancetype) importerForProvider:(NSString *)aProviderName;
+ (instancetype) defaultMovieProvider;
+ (instancetype) defaultTVProvider;
+ (NSString *) defaultMovieLanguage;
+ (NSString *) defaultTVLanguage;

+ (NSString *) defaultLanguageForProvider:(NSString *)provider;

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;

- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;

- (void) loadFullMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(SBMetadataResult * _Nullable metadata))handler;

- (void) cancel;

#pragma mark Methods to be overridden
@property (nonatomic, readonly, copy) NSArray<NSString *> * _Nonnull languages;

- (NSArray<SBMetadataResult *> *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage;
- (NSArray<SBMetadataResult *> *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(nullable NSString *)aSeasonNum episodeNum:(nullable NSString *)aEpisodeNum;

- (NSArray<SBMetadataResult *> *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage;

- (nullable SBMetadataResult *) loadTVMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage;
- (nullable SBMetadataResult *) loadMovieMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage;

@end

NS_ASSUME_NONNULL_END
