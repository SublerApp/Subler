//
//  SBQueuePreferences.m
//  Subler
//
//  Created by Damiano Galassi on 24/06/14.
//
//

#import "SBQueuePreferences.h"
#import "SBPresetManager.h"

#import <MP42Foundation/MP42Metadata.h>

NSString * const SBQueueFileType = @"SBQueueFileType";
NSString * const SBQueueOrganize = @"SBQueueOrganize";
NSString * const SBQueueFixFallbacks = @"SBQueueFixFallbacks";
NSString * const SBQueueMetadata = @"SBQueueMetadata";
NSString * const SBQueueSubtitles = @"SBQueueSubtitles";

NSString * const SBQueueAutoStart = @"SBQueueAutoStart";
NSString * const SBQueueOptimize = @"SBQueueOptimize";

NSString * const SBQueueDestination = @"SBQueueDestination";

NSString * const SBQueueMovieProvider = @"SBQueueMovieProvider";
NSString * const SBQueueTVShowProvider = @"SBQueueTVShowProvider";
NSString * const SBQueueMovieProviderLanguage = @"SBQueueMovieProviderLanguage";
NSString * const SBQueueTVShowProviderLanguage = @"SBQueueTVShowProviderLanguage";
NSString * const SBQueueSet = @"SBQueueSet";

@implementation SBQueuePreferences

@synthesize options = _options;

- (instancetype)init {
    self = [super init];
    if (self) {
        _options = [[NSMutableDictionary alloc] init];

        NSArray *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixFallbacks, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueOptimize,
                         SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage];

        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [_options setObject:[[NSUserDefaults standardUserDefaults] valueForKey:obj] forKey:obj];
        }];

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]) {
            [_options setObject:[NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]] forKey:SBQueueDestination];
        }

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]) {
            MP42Metadata *set = [[SBPresetManager sharedManager] setWithName:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]];
            if (set) {
                [_options setObject:set forKey:SBQueueSet];
            }
        }

    }
    return self;
}

+ (void)registerUserDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ SBQueueFileType : @"mp4",
                                                               SBQueueOrganize : @YES,
                                                               SBQueueFixFallbacks: @NO,
                                                               SBQueueMetadata : @NO,
                                                               SBQueueSubtitles: @YES,
                                                               SBQueueAutoStart: @NO,
                                                               SBQueueOptimize : @YES,
                                                               SBQueueMovieProvider : @"TheMovieDB",
                                                               SBQueueTVShowProvider : @"TheTVDB",
                                                               SBQueueMovieProviderLanguage : @"English",
                                                               SBQueueTVShowProviderLanguage : @"English"}];
}

/**
 * Save the queue user defaults
 */
- (void)saveUserDefaults {
    NSArray<NSString *> *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixFallbacks, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueOptimize,
                      SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage];

    [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [[NSUserDefaults standardUserDefaults] setValue:[self.options objectForKey:obj] forKey:obj];
    }];

    [[NSUserDefaults standardUserDefaults] setValue:[[self.options objectForKey:SBQueueDestination] path] forKey:SBQueueDestination];
    [[NSUserDefaults standardUserDefaults] setValue:[[self.options objectForKey:SBQueueSet] presetName] forKey:SBQueueSet];
}

- (NSURL *)queueURL {
    NSURL *appSupportURL = nil;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count]) {
        appSupportURL = [NSURL fileURLWithPath:[[[allPaths lastObject] stringByAppendingPathComponent:@"Subler"]
                                                stringByAppendingPathComponent:@"queue.sbqueue"] isDirectory:YES];
        return appSupportURL;
    } else {
        return nil;
    }
}

@end
