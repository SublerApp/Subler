//
//  MetadataImporter.h
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <Foundation/Foundation.h>

@class MP42Metadata;

@interface MetadataImporter : NSObject {
@private
    BOOL _isCancelled;
}

typedef enum SBCachePolicy : NSUInteger {
    SBDefaultPolicy = 0,
    SBReturnCacheElseLoad,
    SBReloadIgnoringLocalCacheData,
} SBCachePolicy;

#pragma mark Helper routines
+ (NSDictionary *) parseFilename: (NSString *) filename;
+ (NSString *) urlEncoded:(NSString *)s;
+ (NSData *)downloadDataFromURL:(NSURL *)url withCachePolicy:(SBCachePolicy)policy;

#pragma mark Class methods
+ (NSArray *) movieProviders;
+ (NSArray *) tvProviders;
+ (NSArray *) languagesForProvider:(NSString *)aProvider;
+ (instancetype) importerForProvider:(NSString *)aProviderName;
+ (instancetype) defaultMovieProvider;
+ (instancetype) defaultTVProvider;
+ (NSString *) defaultMovieLanguage;
+ (NSString *) defaultTVLanguage;

+ (NSString *) defaultLanguageForProvider:(NSString *)provider;

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray *results))handler;
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray *results))handler;

- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray *results))handler;

- (void) loadFullMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(MP42Metadata *metadata))handler;

- (void) cancel;

#pragma Methods to be overridden
- (NSArray *) languages;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum;
- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage;
- (MP42Metadata*) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;
- (MP42Metadata*) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;

@end
