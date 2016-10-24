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
NSString * const SBQueueClearTrackName = @"SBQueueClearTrackName";
NSString * const SBQueueMetadata = @"SBQueueMetadata";
NSString * const SBQueueSubtitles = @"SBQueueSubtitles";

NSString * const SBQueueAutoStart = @"SBQueueAutoStart";
NSString * const SBQueueOptimize = @"SBQueueOptimize";
NSString * const SBQueueShowDoneNotification = @"SBQueueShowDoneNotification";

NSString * const SBQueueFixTrackLanguage = @"SBQueueFixTrackLanguage";
NSString * const SBQueueFixTrackLanguageValue = @"SBQueueFixTrackLanguageValue";

NSString * const SBQueueDestination = @"SBQueueDestination";

NSString * const SBQueueMovieProvider = @"SBQueueMovieProvider";
NSString * const SBQueueTVShowProvider = @"SBQueueTVShowProvider";
NSString * const SBQueueMovieProviderLanguage = @"SBQueueMovieProviderLanguage";
NSString * const SBQueueTVShowProviderLanguage = @"SBQueueTVShowProviderLanguage";
NSString * const SBQueueSet = @"SBQueueSet";

@implementation SBQueuePreferences

- (instancetype)init {
    self = [super init];
    if (self) {
        _options = [[NSMutableDictionary alloc] init];

        NSArray *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixTrackLanguage, SBQueueFixTrackLanguageValue, SBQueueFixFallbacks, SBQueueClearTrackName, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueOptimize, SBQueueShowDoneNotification, SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage];

        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            self.options[obj] = [[NSUserDefaults standardUserDefaults] valueForKey:obj];
        }];

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]) {
            self.options[SBQueueDestination] = [NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]];
        }

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]) {
            MP42Metadata *set = [[SBPresetManager sharedManager] setWithName:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]];
            if (set) {
                self.options[SBQueueSet] = set;
            }
        }

    }
    return self;
}

+ (void)registerUserDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ SBQueueFileType : @"mp4",
                                                               SBQueueOrganize : @YES,
                                                               SBQueueFixTrackLanguage: @NO,
                                                               SBQueueFixTrackLanguageValue: @"English",
                                                               SBQueueFixFallbacks: @NO,
                                                               SBQueueClearTrackName: @NO,
                                                               SBQueueMetadata : @NO,
                                                               SBQueueSubtitles: @YES,

                                                               SBQueueAutoStart: @NO,
                                                               SBQueueOptimize : @YES,
                                                               SBQueueShowDoneNotification: @YES,

                                                               SBQueueMovieProvider : @"TheMovieDB",
                                                               SBQueueTVShowProvider : @"TheTVDB",
                                                               SBQueueMovieProviderLanguage : @"English",
                                                               SBQueueTVShowProviderLanguage : @"English"}];
}

/**
 * Save the queue user defaults
 */
- (void)saveUserDefaults {
    NSArray<NSString *> *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixTrackLanguage, SBQueueFixTrackLanguageValue, SBQueueFixFallbacks, SBQueueClearTrackName, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueShowDoneNotification, SBQueueOptimize, SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage];

    [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [[NSUserDefaults standardUserDefaults] setValue:(self.options)[obj] forKey:obj];
    }];

    [[NSUserDefaults standardUserDefaults] setValue:[(self.options)[SBQueueDestination] path] forKey:SBQueueDestination];
    [[NSUserDefaults standardUserDefaults] setValue:[(self.options)[SBQueueSet] presetName] forKey:SBQueueSet];
}

- (nullable NSURL *)queueURL {
    NSURL *appSupportURL = nil;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if (allPaths.count) {
        appSupportURL = [NSURL fileURLWithPath:[[allPaths.lastObject stringByAppendingPathComponent:@"Subler"]
                                                stringByAppendingPathComponent:@"queue.sbqueue"] isDirectory:YES];
        return appSupportURL;
    } else {
        return nil;
    }
}

@end
