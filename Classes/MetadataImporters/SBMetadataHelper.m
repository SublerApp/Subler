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

+ (NSDictionary<NSString *, NSString *> *)parseFilename:(NSString *)filename
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
        NSInteger episodeNumber = [resultDictionary[@"episodeNumber"] integerValue];

        results[@"type"] = @"tv";
        results[@"seriesName"] = seriesName;
        results[@"seasonNum"] = @"1";
        results[@"episodeNum"] = [NSString stringWithFormat:@"%ld", (long)episodeNumber];

        return [results autorelease];
    }

    // Else use the ParseFilename perl script
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/perl"];

    NSMutableArray<NSString *> *args = [[NSMutableArray alloc] initWithCapacity:3];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ParseFilename" ofType:@""];
    [args addObject:[NSString stringWithFormat:@"-I%@/lib", path]];
    [args addObject:[NSString stringWithFormat:@"%@/ParseFilename.pl", path]];
    [args addObject:filename];
    [task setArguments:args];

    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutWrite = [stdOut fileHandleForWriting];
    [task setStandardOutput:stdOutWrite];

    [task launch];
    [task waitUntilExit];
    [stdOutWrite closeFile];

    NSData *outputData = [[stdOut fileHandleForReading] readDataToEndOfFile];
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

                if ([lines[2] integerValue]) {
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

    [outputString release];
    [stdOut release];
    [args release];
    [task release];

    return [results autorelease];
}

+ (NSString *)urlEncoded:(NSString *)string {
    string = [string precomposedStringWithCompatibilityMapping];
    CFStringRef urlString = CFURLCreateStringByAddingPercentEscapes(
                                                                    NULL,
                                                                    (CFStringRef) string,
                                                                    NULL,
                                                                    (CFStringRef) @"!*'\"();:@&=+$,/?%#[]% ",
                                                                    kCFStringEncodingUTF8);
    return [(NSString *)urlString autorelease];
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

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url withCachePolicy:(SBCachePolicy)policy error:(NSError **)error  {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSURL *cacheURL = [[[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask]
                        firstObject] URLByAppendingPathComponent:bundleName];


    NSURL *fileURL = [cacheURL URLByAppendingPathComponent:[SBMetadataHelper sha256String:url.absoluteString]];
    fileURL = [fileURL URLByAppendingPathExtension:url.pathExtension];

    if (policy != SBReloadIgnoringLocalCacheData) {
        NSDictionary<NSString *, id> *attrs = [fileURL resourceValuesForKeys:@[NSURLCreationDateKey] error:NULL];
        NSDate *creationDate = attrs[NSURLCreationDateKey];

        if (creationDate) {
            NSTimeInterval oldness = creationDate.timeIntervalSinceNow;

            // if less than 2 hours old or jpg
            if ([url.pathExtension caseInsensitiveCompare:@"jpg"] == NSOrderedSame ||
                (oldness > -60 * 60 * 2) ||
                policy == SBReturnCacheElseLoad) {
                return [NSData dataWithContentsOfURL:fileURL options:0 error:error];
            }
        }
    }
    
    NSData *downloadedData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:error];
    [downloadedData writeToURL:fileURL atomically:YES];
    
    return downloadedData;
}

+ (nullable NSData *)downloadDataFromURL:(NSURL *)url withCachePolicy:(SBCachePolicy)policy {
    return [SBMetadataHelper downloadDataFromURL:url withCachePolicy:policy error:NULL];
}

#pragma mark NSURLRequest
+ (nullable NSData *)dataFromUrl:(NSURL *)url withHTTPMethod:(NSString *)method headerOptions:(nullable NSDictionary *)header error:(NSError **)outError
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:30.0];
    [request setHTTPMethod:method];

    if (header) {
        for (NSString *key in header.allKeys) {
            [request addValue:header[key] forHTTPHeaderField:key];
        }
    }

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];

    if (data) {
        NSUInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = (long)[(NSHTTPURLResponse *)response statusCode];
        }

        if (statusCode == 200) {
            return data;
        }
    }
    
    return nil;
}

@end
