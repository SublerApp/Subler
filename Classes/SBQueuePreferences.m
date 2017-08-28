//
//  SBQueuePreferences.m
//  Subler
//
//  Created by Damiano Galassi on 24/06/14.
//
//

#import "SBQueuePreferences.h"
#import "Subler-Swift.h"

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

NSString * const SBQueueApplyColorSpace = @"SBQueueApplyColorSpace";
NSString * const SBQueueApplyColorSpaceValue = @"SBQueueApplyColorSpaceValue";

NSString * const SBQueueDestination = @"SBQueueDestination";

NSString * const SBQueueMovieProvider = @"SBQueueMovieProvider";
NSString * const SBQueueTVShowProvider = @"SBQueueTVShowProvider";
NSString * const SBQueueMovieProviderLanguage = @"SBQueueMovieProviderLanguage";
NSString * const SBQueueTVShowProviderLanguage = @"SBQueueTVShowProviderLanguage";
NSString * const SBQueueProviderArtwork = @"SBQueueProviderArtwork";

NSString * const SBQueueSet = @"SBQueueSet";

@implementation SBQueuePreferences

- (instancetype)init {
    self = [super init];
    if (self) {
        _options = [[NSMutableDictionary alloc] init];

        NSArray *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixTrackLanguage, SBQueueFixTrackLanguageValue, SBQueueApplyColorSpace, SBQueueApplyColorSpaceValue, SBQueueFixFallbacks, SBQueueClearTrackName, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueOptimize, SBQueueShowDoneNotification, SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage, SBQueueProviderArtwork];

        [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            self.options[obj] = [[NSUserDefaults standardUserDefaults] valueForKey:obj];
        }];

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]) {
            self.options[SBQueueDestination] = [NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueDestination]];
        }

        if ([[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]) {
            SBMetadataPreset *preset = (SBMetadataPreset *)[SBPresetManager.shared itemWithName:[[NSUserDefaults standardUserDefaults] valueForKey:SBQueueSet]];
            if (preset) {
                self.options[SBQueueSet] = preset;
            }
        }

    }
    return self;
}

+ (void)registerUserDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ SBQueueFileType : @"mp4",
                                                               SBQueueOrganize : @YES,
                                                               SBQueueFixTrackLanguage: @NO,
                                                               SBQueueFixTrackLanguageValue: @"en",
                                                               SBQueueFixFallbacks: @NO,
                                                               SBQueueClearTrackName: @NO,
                                                               SBQueueMetadata : @NO,
                                                               SBQueueSubtitles: @YES,

                                                               SBQueueApplyColorSpace: @NO,
                                                               SBQueueApplyColorSpaceValue: @1,

                                                               SBQueueAutoStart: @NO,
                                                               SBQueueOptimize : @YES,
                                                               SBQueueShowDoneNotification: @YES,

                                                               SBQueueMovieProvider : @"TheMovieDB",
                                                               SBQueueTVShowProvider : @"TheTVDB",
                                                               SBQueueMovieProviderLanguage : @"en",
                                                               SBQueueTVShowProviderLanguage : @"en",
                                                               SBQueueProviderArtwork : @0}];
}

/**
 * Save the queue user defaults
 */
- (void)saveUserDefaults {
    NSArray<NSString *> *keys = @[SBQueueFileType, SBQueueOrganize, SBQueueFixTrackLanguage, SBQueueFixTrackLanguageValue, SBQueueApplyColorSpace, SBQueueApplyColorSpaceValue, SBQueueFixFallbacks, SBQueueClearTrackName, SBQueueMetadata, SBQueueSubtitles, SBQueueAutoStart, SBQueueShowDoneNotification, SBQueueOptimize, SBQueueMovieProvider, SBQueueTVShowProvider, SBQueueMovieProviderLanguage, SBQueueTVShowProviderLanguage, SBQueueProviderArtwork];

    [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [[NSUserDefaults standardUserDefaults] setValue:self.options[obj] forKey:obj];
    }];

    [[NSUserDefaults standardUserDefaults] setValue:[self.options[SBQueueDestination] path] forKey:SBQueueDestination];
    [[NSUserDefaults standardUserDefaults] setValue:[self.options[SBQueueSet] title] forKey:SBQueueSet];
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
