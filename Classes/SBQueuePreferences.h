//
//  SBQueuePreferences.h
//  Subler
//
//  Created by Damiano Galassi on 24/06/14.
//
//

#import <Foundation/Foundation.h>

extern NSString * const SBQueueOrganize;
extern NSString * const SBQueueMetadata;
extern NSString * const SBQueueSubtitles;
extern NSString * const SBQueueSet;

extern NSString * const SBQueueAutoStart;
extern NSString * const SBQueueOptimize;

extern NSString * const SBQueueMovieProvider;
extern NSString * const SBQueueTVShowProvider;
extern NSString * const SBQueueMovieProviderLanguage;
extern NSString * const SBQueueTVShowProviderLanguage;

extern NSString * const SBQueueDestination;

@interface SBQueuePreferences : NSObject {
    NSMutableDictionary *_options;
}

@property (readonly) NSMutableDictionary *options;
@property (readonly) NSURL *queueURL;

- (void)registerUserDefaults;
- (void)saveUserDefaults;

@end
