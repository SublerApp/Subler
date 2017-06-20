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
+ (nullable NSDictionary<NSString *, NSString *> *)parseFilename:(NSString *)filename;
+ (NSString *)urlEncoded:(NSString *)string;

@property (class) id<MP42Logging> logger;

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url cachePolicy:(SBCachePolicy)policy;
+ (nullable NSData *)downloadDataFromURL:(NSURL *)url HTTPMethod:(NSString *)method HTTPBody:(nullable NSData *)body headerOptions:(nullable NSDictionary *)header cachePolicy:(SBCachePolicy)policy;
+ (NSURLSessionTask *)sessionTaskFromUrl:(NSURL *)url HTTPMethod:(NSString *)method HTTPBody:(nullable NSData *)body headerOptions:(nullable NSDictionary *)header cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void(^)(NSData * _Nullable data))completionHandler;

@end

NS_ASSUME_NONNULL_END
