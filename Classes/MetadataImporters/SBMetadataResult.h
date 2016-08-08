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

@interface SBMetadataResult : NSObject

- (void)merge:(SBMetadataResult *)aObject;

- (void)removeTagForKey:(NSString *)aKey;
- (void)setTag:(id)value forKey:(NSString *)key;

- (nullable id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *tags;

@property (nonatomic, readwrite) uint8_t    mediaKind;
@property (nonatomic, readwrite) uint8_t    contentRating;

@property (nonatomic, readonly) NSMutableArray<MP42Image *> *artworks;

@property (nonatomic, readwrite, strong, nullable) NSArray<NSURL *> *artworkThumbURLs;
@property (nonatomic, readwrite, strong, nullable) NSArray<NSURL *> *artworkFullsizeURLs;
@property (nonatomic, readwrite, strong, nullable) NSArray<NSString *> *artworkProviderNames;

- (MP42Metadata *)metadataUsingMap:(SBMetadataResultMap *)map keepEmptyKeys:(BOOL)keep;

@end

NS_ASSUME_NONNULL_END
