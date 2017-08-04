//
//  SBMetadataHelper.m
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import "SBMetadataHelper.h"

@implementation SBMetadataHelper

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url HTTPMethod:(NSString *)method HTTPBody:(nullable NSData *)body headerOptions:(nullable NSDictionary *)header cachePolicy:(SBCachePolicy)policy {
    dispatch_semaphore_t sem =  dispatch_semaphore_create(0);
    __block NSData *downloadedData;

    NSURLRequestCachePolicy cachePolicy;
    switch (policy) {
        case SBCachePolicyReturnCacheElseLoad:
            cachePolicy = NSURLRequestReturnCacheDataElseLoad;
            break;
        case SBCachePolicyReloadIgnoringLocalCacheData:
            cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            break;
        case SBCachePolicyDefault:
        default:
            cachePolicy = NSURLRequestUseProtocolCachePolicy;
            break;
    }

    [[self sessionTaskFromUrl:url HTTPMethod:method HTTPBody:body headerOptions:header cachePolicy:cachePolicy completionHandler:^(NSData * _Nullable data) {
        downloadedData = data;
        dispatch_semaphore_signal(sem);
    }] resume];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    return downloadedData;
}

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url cachePolicy:(SBCachePolicy)policy {
    return [self downloadDataFromURL:url HTTPMethod:@"GET" HTTPBody:nil headerOptions:nil cachePolicy:policy];
}

#pragma mark NSURLRequest
+ (NSURLSessionTask *)sessionTaskFromUrl:(NSURL *)url HTTPMethod:(NSString *)method HTTPBody:(nullable NSData *)body headerOptions:(nullable NSDictionary *)header cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void(^)(NSData * _Nullable data))completionHandler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:cachePolicy
                                                       timeoutInterval:30.0];
    request.HTTPMethod = method;

    if (header) {
        for (NSString *key in header.allKeys) {
            [request addValue:header[key] forHTTPHeaderField:key];
        }
    }

    if (body) {
        request.HTTPBody = body;
    }


    NSURLSession *defaultSession = [NSURLSession sharedSession];
    NSURLSessionTask *task = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (data) {
            NSUInteger statusCode = 0;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                statusCode = (long)((NSHTTPURLResponse *)response).statusCode;
            }

            if (statusCode == 200) {
                completionHandler(data);
            }
            else {
                completionHandler(nil);
            }
        }

        completionHandler(nil);

    }];

    return task;
}

@end
