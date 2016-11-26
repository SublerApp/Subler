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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SBMetadataImporterLanguageType) {
    SBMetadataImporterLanguageTypeISO,
    SBMetadataImporterLanguageTypeCustom,
};

@interface SBMetadataImporter : NSObject

#pragma mark Class methods
@property (nonatomic, class, readonly) NSArray<NSString *> *movieProviders;
@property (nonatomic, class, readonly) NSArray<NSString *> *tvProviders;

+ (NSArray<NSString *> *)languagesForProvider:(NSString *)providerName;
+ (SBMetadataImporterLanguageType)languageTypeForProvider:(NSString *)providerName;
+ (nullable instancetype)importerForProvider:(NSString *)providerName;

@property (nonatomic, class, readonly) SBMetadataImporter *defaultMovieProvider;
@property (nonatomic, class, readonly) SBMetadataImporter *defaultTVProvider;

@property (nonatomic, class, readonly) NSString *defaultMovieLanguage;
@property (nonatomic, class, readonly) NSString *defaultTVLanguage;

+ (NSString *)defaultLanguageForProvider:(NSString *)providerName;

#pragma mark - Asynchronous searching

- (void)searchTVSeries:(NSString *)series language:(NSString *)language completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;
- (void)searchTVSeries:(NSString *)series language:(NSString *)language seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;

- (void)searchMovie:(NSString *)title language:(NSString *)language completionHandler:(void(^)(NSArray<SBMetadataResult *> * _Nullable results))handler;

- (void)loadFullMetadata:(SBMetadataResult *)metadata language:(NSString *)language completionHandler:(void(^)(SBMetadataResult * _Nullable metadata))handler;

- (void)cancel;

#pragma mark - Methods to be overridden

@property (nonatomic, readonly) SBMetadataImporterLanguageType languageType;

@property (nonatomic, readonly, copy) NSArray<NSString *> *languages;

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)seriesName language:(NSString *)language;
- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)seriesName language:(NSString *)language seasonNum:(nullable NSString *)seasonNum episodeNum:(nullable NSString *)episodeNum;

- (NSArray<SBMetadataResult *> *)searchMovie:(NSString *)title language:(NSString *)language;

- (nullable SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)metadata language:(NSString *)language;
- (nullable SBMetadataResult *)loadMovieMetadata:(SBMetadataResult *)metadata language:(NSString *)language;

@end

NS_ASSUME_NONNULL_END
