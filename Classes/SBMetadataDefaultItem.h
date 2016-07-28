//
//  SBMetadataDefaultSet.h
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBMetadataDefaultItem : NSObject

+ (instancetype)itemWithKey:(NSString *)key value:(NSArray *)value;
- (instancetype)initWithKey:(NSString *)key value:(NSArray *)value;

@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readwrite, copy) NSArray *value;

@end

NS_ASSUME_NONNULL_END
