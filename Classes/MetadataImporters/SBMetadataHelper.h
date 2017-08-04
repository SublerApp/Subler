//
//  SBMetadataHelper.h
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import <Foundation/Foundation.h>
#import <MP42Foundation/MP42Logging.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBMetadataHelper : NSObject

typedef NS_ENUM(NSUInteger, SBCachePolicy) {
    SBCachePolicyDefault,
    SBCachePolicyReturnCacheElseLoad,
    SBCachePolicyReloadIgnoringLocalCacheData,
};

#pragma mark Helper routines
+ (nullable NSData *)downloadDataFromURL:(NSURL *)url cachePolicy:(SBCachePolicy)policy;

@end

NS_ASSUME_NONNULL_END
