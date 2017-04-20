//
//  SBMetadataHelper.m
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import "SBMetadataHelper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SBMetadataHelper

+ (nullable NSDictionary<NSString *, NSString *> *)parseFilename:(NSString *)filename
{
    NSParameterAssert(filename);

    NSMutableDictionary<NSString *, NSString *> *results = nil;

    // Try with the usual anime filename
    __block NSDictionary<NSString *, NSString *> *resultDictionary = nil;

    NSString *pattern = @"^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9]+)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];

    [regex enumerateMatchesInString:filename
                            options:0
                              range:NSMakeRange(0, filename.length)
                         usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {

                             resultDictionary = @{ @"fanSubGroup": [filename substringWithRange:[match rangeAtIndex:1]],
                                                   @"seriesName": [filename substringWithRange:[match rangeAtIndex:2]],
                                                   @"episodeNumber": [filename substringWithRange:[match rangeAtIndex:3]] };

                         }];

    if (resultDictionary.count) {
        results = [[NSMutableDictionary alloc] init];
        NSString *seriesName = [resultDictionary[@"seriesName"] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        NSInteger episodeNumber = (resultDictionary[@"episodeNumber"]).integerValue;

        results[@"type"] = @"tv";
        results[@"seriesName"] = seriesName;
        results[@"seasonNum"] = @"1";
        results[@"episodeNum"] = [NSString stringWithFormat:@"%ld", (long)episodeNumber];

        return results;
    }

    // Else use the ParseFilename perl script
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/perl";

    NSMutableArray<NSString *> *args = [[NSMutableArray alloc] initWithCapacity:3];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ParseFilename" ofType:@""];
    [args addObject:[NSString stringWithFormat:@"-I%@/lib", path]];
    [args addObject:[NSString stringWithFormat:@"%@/ParseFilename.pl", path]];
    [args addObject:filename];
    task.arguments = args;

    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutWrite = stdOut.fileHandleForWriting;
    task.standardOutput = stdOutWrite;

    [task launch];
    [task waitUntilExit];
    [stdOutWrite closeFile];

    NSData *outputData = [stdOut.fileHandleForReading readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [outputString componentsSeparatedByString:@"\n"];

    if (lines.count) {

        if ([lines.firstObject isEqualToString:@"tv"]) {

            if (lines.count >= 4) {

                results = [[NSMutableDictionary alloc] initWithCapacity:4];
                results[@"type"] = @"tv";

                NSString *newSeriesName=[lines[1] stringByReplacingOccurrencesOfString:@"."
                                                                            withString:@" "];
                results[@"seriesName"] = newSeriesName;

                if ((lines[2]).integerValue) {
                    results[@"seasonNum"] = lines[2];
                }
                else {
                    results[@"seasonNum"] = @"0";
                }

                results[@"episodeNum"] = lines[3];
            }
        }
        else if ([lines.firstObject isEqualToString:@"movie"]) {

            if (lines.count >= 2) {

                results = [[NSMutableDictionary alloc] initWithCapacity:2];
                results[@"type"] = @"movie";

                NSString *newTitle=[lines[1] stringByReplacingOccurrencesOfString:@"."
                                                                       withString:@" "];

                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"(" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@")" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"[" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"]" withString:@" "];
                newTitle = [newTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                results[@"title"] = newTitle;
            }
        }
    }

    return results;
}

+ (NSString *)urlEncoded:(NSString *)string {
    return [string.precomposedStringWithCompatibilityMapping stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

+ (NSString *)md5String:(NSString *)s {
    const char *cStr = s.UTF8String;
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    NSMutableString *r = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        [r appendFormat:@"%02x", result[i]];
    }
    return [NSString stringWithString:r];
}

+ (NSString *)sha256String:(NSString *)s {
    const char *cStr = s.UTF8String;
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), result);
    NSMutableString *r = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [r appendFormat:@"%02x", result[i]];
    }
    return [NSString stringWithString:r];
}

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url withCachePolicy:(SBCachePolicy)policy {
    dispatch_semaphore_t sem =  dispatch_semaphore_create(0);
    __block NSData *downloadedData;

    NSURLRequestCachePolicy cachePolicy;
    switch (policy) {
        case SBReturnCacheElseLoad:
            cachePolicy = NSURLRequestReturnCacheDataElseLoad;
            break;
        case SBReloadIgnoringLocalCacheData:
            cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            break;
        case SBDefaultPolicy:
        default:
            cachePolicy = NSURLRequestUseProtocolCachePolicy;
            break;
    }

    [[self sessionTaskFromUrl:url HTTPMethod:@"GET" headerOptions:nil cachePolicy:cachePolicy completionHandler:^(NSData * _Nullable data) {
        downloadedData = data;
        dispatch_semaphore_signal(sem);
    }] resume];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    return downloadedData;
}

#pragma mark NSURLRequest
+ (NSURLSessionTask *)sessionTaskFromUrl:(NSURL *)url HTTPMethod:(NSString *)method headerOptions:(nullable NSDictionary *)header cachePolicy:(NSURLRequestCachePolicy)cachePolicy completionHandler:(void(^)(NSData * _Nullable data))completionHandler
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
    }];

    return task;
}

@end
