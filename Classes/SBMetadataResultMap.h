//
//  SBMetadataDefaultSet.h
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBMetadataResultMapItem : NSObject<NSSecureCoding>

+ (instancetype)itemWithKey:(NSString *)key value:(NSArray *)value;
- (instancetype)initWithKey:(NSString *)key value:(NSArray *)value;

@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *value;

@property (nonatomic, readonly) NSString *localizedKeyDisplayName;

@end

typedef NS_ENUM(NSUInteger, SBMetadataResultMapType) {
    SBMetadataResultMapTypeMovie,
    SBMetadataResultMapTypeTvShow,
};

/**
 *  Maps the values returned by the metadata importers
 *  the the MP42Metadata values.
 */
@interface SBMetadataResultMap : NSObject<NSSecureCoding>

+ (instancetype)movieDefaultMap;
+ (instancetype)tvShowDefaultMap;

- (instancetype)initWithItems:(NSArray<SBMetadataResultMapItem *> *)items type:(SBMetadataResultMapType)type;

@property (nonatomic, readonly) NSMutableArray<SBMetadataResultMapItem *> *items;
@property (nonatomic, readonly) SBMetadataResultMapType type;

@end

@interface NSUserDefaults (SublerMetadataResultMapAdditions)

- (nullable SBMetadataResultMap *)SB_resultMapForKey:(NSString *)defaultName;
- (void)SB_setResultMap:(nullable SBMetadataResultMap *)value forKey:(NSString *)defaultName;

@end

NS_ASSUME_NONNULL_END
