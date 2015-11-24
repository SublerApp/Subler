//
//  SBQueuePreferences.h
//  Subler
//
//  Created by Damiano Galassi on 24/06/14.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SBQueueFileType;
extern NSString * const SBQueueOrganize;
extern NSString * const SBQueueFixFallbacks;
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
@private
    NSMutableDictionary *_options;
}

@property (nonatomic, readonly) NSMutableDictionary *options;
@property (nonatomic, readonly) NSURL *queueURL;

+ (void)registerUserDefaults;
- (void)saveUserDefaults;

@end

NS_ASSUME_NONNULL_END
