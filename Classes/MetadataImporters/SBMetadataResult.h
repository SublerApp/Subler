//
//  SBMetadataResult.h
//  Subler
//
//  Created by Damiano Galassi on 17/02/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42Image;
@class MP42Metadata;
@class SBMetadataResultMap;

// Common Keys
extern NSString *const SBMetadataResultName;
extern NSString *const SBMetadataResultComposer;
extern NSString *const SBMetadataResultGenre;
extern NSString *const SBMetadataResultReleaseDate;
extern NSString *const SBMetadataResultDescription;
extern NSString *const SBMetadataResultLongDescription;
extern NSString *const SBMetadataResultRating;
extern NSString *const SBMetadataResultStudio;
extern NSString *const SBMetadataResultCast;
extern NSString *const SBMetadataResultDirector;
extern NSString *const SBMetadataResultProducers;
extern NSString *const SBMetadataResultScreenwriters;
extern NSString *const SBMetadataResultExecutiveProducer;
extern NSString *const SBMetadataResultCopyright;

// iTunes Keys
extern NSString *const SBMetadataResultContentID;
extern NSString *const SBMetadataResultArtistID;
extern NSString *const SBMetadataResultPlaylistID;
extern NSString *const SBMetadataResultITunesCountry;
extern NSString *const SBMetadataResultITunesURL;

// TV Show Keys
extern NSString *const SBMetadataResultSeriesName;
extern NSString *const SBMetadataResultSeriesDescription;
extern NSString *const SBMetadataResultTrackNumber;
extern NSString *const SBMetadataResultDiskNumber;
extern NSString *const SBMetadataResultEpisodeNumber;
extern NSString *const SBMetadataResultEpisodeID;
extern NSString *const SBMetadataResultSeason;
extern NSString *const SBMetadataResultNetwork;

@interface SBRemoteImage : NSObject

+ (instancetype)remoteImageWithURL:(NSURL *)fullSizeURL thumbURL:(NSURL *)thumbURL service:(NSString *)service type:(NSString *)kind;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSURL *thumbURL;
@property (nonatomic, readonly) NSString *service;
@property (nonatomic, readonly) NSString *type;

@end

@interface SBMetadataResult : NSObject

+ (NSArray<NSString *> *)movieKeys;
+ (NSArray<NSString *> *)tvShowKeys;
+ (NSString *)localizedDisplayNameForKey:(NSString *)key;

- (void)merge:(SBMetadataResult *)aObject;

- (void)removeTagForKey:(NSString *)aKey;
- (void)setTag:(id)value forKey:(NSString *)key;

- (nullable id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(nullable id)obj forKeyedSubscript:(NSString *)key;

- (NSArray<NSString *> *)orderedKeys;

@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *tags;

@property (nonatomic, readwrite) uint8_t    mediaKind;
@property (nonatomic, readwrite) uint8_t    contentRating;

@property (nonatomic, readonly) NSMutableArray<MP42Image *> *artworks;

@property (nonatomic, readwrite, nullable) NSArray<SBRemoteImage *> *remoteArtworks;

- (MP42Metadata *)mappedTo:(SBMetadataResultMap *)map keepEmptyKeys:(BOOL)keep;

@end

NS_ASSUME_NONNULL_END
