//
//  MetadataImporter.h
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <Foundation/Foundation.h>

@class SBMetadataSearchController;
@class MP42Metadata;

@interface MetadataImporter : NSObject {
    SBMetadataSearchController *mCallback;
    BOOL isCancelled;
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

#pragma mark Static methods
+ (NSArray *) languagesForProvider:(NSString *)aProvider;
+ (instancetype) importerForProvider:(NSString *)aProviderName;
+ (instancetype) defaultMovieProvider;
+ (instancetype) defaultTVProvider;
+ (NSString *) defaultMovieLanguage;
+ (NSString *) defaultTVLanguage;

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback;
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum callback:(SBMetadataSearchController *)aCallback;
- (void) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback;
- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback;
- (void) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback;
- (void) cancel;

#pragma Methods to be overridden
- (NSArray *) languages;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum;
- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage;
- (MP42Metadata*) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;
- (MP42Metadata*) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;

@end
