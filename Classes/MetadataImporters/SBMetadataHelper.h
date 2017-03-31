//
//  SBMetadataHelper.h
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBMetadataHelper : NSObject

typedef NS_ENUM(NSUInteger, SBCachePolicy) {
    SBDefaultPolicy,
    SBReturnCacheElseLoad,
    SBReloadIgnoringLocalCacheData,
};

#pragma mark Helper routines
+ (nullable NSDictionary<NSString *, NSString *> *)parseFilename:(NSString *)filename;
+ (NSString *)urlEncoded:(NSString *)string;

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url withCachePolicy:(SBCachePolicy)policy;
+ (NSURLSessionTask *)sessionTaskFromUrl:(NSURL *)url HTTPMethod:(NSString *)method headerOptions:(nullable NSDictionary *)header cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void(^)(NSData * _Nullable data))completionHandler;

@end

NS_ASSUME_NONNULL_END
