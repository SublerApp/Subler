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
