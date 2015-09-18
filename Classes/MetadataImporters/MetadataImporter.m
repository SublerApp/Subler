//
//  MetadataImporter.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import "MetadataImporter.h"

#import "SBMetadataSearchController.h"

#import <CommonCrypto/CommonDigest.h>

#import "iTunesStore.h"
#import "TheMovieDB3.h"
#import "TheTVDB.h"


@interface MetadataImporter ()

@property (atomic, readwrite) BOOL isCancelled;

@end

@implementation MetadataImporter

@synthesize isCancelled = _isCancelled;

#pragma mark Helper routines

+ (NSDictionary<NSString *, NSString *> *)parseFilename:(NSString *)filename
{
    NSParameterAssert(filename);

    NSMutableDictionary<NSString *, NSString *> *results = nil;

    // Try with the usual anime filename
    NSError *error = NULL;
    __block NSDictionary<NSString *, NSString *> *resultDictionary = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9][0-9]?)"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];

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


    NSURL *fileURL = [cacheURL URLByAppendingPathComponent:[MetadataImporter sha256String:url.absoluteString]];
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
    return [MetadataImporter downloadDataFromURL:url withCachePolicy:policy error:NULL];
}

#pragma mark Class methods

+ (NSArray<NSString *> *)movieProviders {
    return @[@"TheMovieDB", @"iTunes Store"];
}
+ (NSArray<NSString *> *)tvProviders {
    return @[@"TheTVDB", @"iTunes Store"];
}

+ (NSArray<NSString *> *)languagesForProvider:(NSString *)aProvider {
	MetadataImporter *m = [MetadataImporter importerForProvider:aProvider];
	NSArray *a = [m languages];
	return a;
}

+ (instancetype)importerForProvider:(NSString *)aProvider {
	if ([aProvider isEqualToString:@"iTunes Store"]) {
		return [[[iTunesStore alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheMovieDB"]) {
		return [[[TheMovieDB3 alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheTVDB"]) {
		return [[[TheTVDB alloc] init] autorelease];
	}
	return nil;
}

+ (instancetype)defaultMovieProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
}

+ (instancetype)defaultTVProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
}

+ (NSString *)defaultMovieLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [defaults valueForKey:@"SBMetadataPreference|Movie"]]];
}

+ (NSString *)defaultTVLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [defaults valueForKey:@"SBMetadataPreference|TV"]]];
}

+ (NSString *)defaultLanguageForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"iTunes Store"]) {
        return @"USA (English)";
    } else {
        return @"English";
    }
}

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage completionHandler:(void(^)(NSArray<MP42Metadata *> * _Nullable results))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSArray *results = [self searchMovie:aMovieTitle language:aLanguage];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(results);
                }
            });
    });
}

- (void)loadFullMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage completionHandler:(void(^)(MP42Metadata * _Nullable metadata))handler {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (aMetadata.mediaKind == 9) {
                [self loadMovieMetadata:aMetadata language:aLanguage];
            } else if (aMetadata.mediaKind == 10) {
                [self loadTVMetadata:aMetadata language:aLanguage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.isCancelled) {
                    handler(aMetadata);
                }
            });
    });
}

- (void)cancel {
    self.isCancelled = YES;
}

#pragma mark Methods to be overridden

- (NSArray<NSString *> *) languages {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<MP42Metadata *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage  {
	TheTVDB *searcher = [[TheTVDB alloc] init];
	NSArray *a = [searcher searchTVSeries:aSeriesName language:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|TheTVDB|Language"]];
	[searcher release];
	return a;
}

- (NSArray<MP42Metadata *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata *)loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray<MP42Metadata *> *)searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata *)loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

@end
