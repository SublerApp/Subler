//
//  SBQueueAction.h
//  Subler
//
//  Created by Damiano Galassi on 12/03/14.
//
//

#import <Foundation/Foundation.h>

@class SBQueueItem;
@class MP42Metadata;

NS_ASSUME_NONNULL_BEGIN

/**
 *  SBQueue actions protocol, actions can be run by
 *  the queue's items.
 */
@protocol SBQueueActionProtocol <NSObject, NSCoding>
- (void)runAction:(SBQueueItem *)item;
@property (nonatomic, readonly) NSString *localizedDescription;
@end

/**
 *  An actions that fetches metadata online.
 */
@interface SBQueueMetadataAction : NSObject <SBQueueActionProtocol> {
@private
    NSString *_movieLanguage;
    NSString *_tvShowLanguage;
    NSString *_movieProvider;
    NSString *_tvShowProvider;
}
- (instancetype)initWithMovieLanguage:(NSString *)movieLang
                       tvShowLanguage:(NSString *)tvLang
                   movieProvider:(NSString *)movieProvider
                  tvShowProvider:(NSString *)tvShowProvider;
@end

/**
 *  An actions that search in the item source directory for additionals srt subtitles
 */
@interface SBQueueSubtitlesAction : NSObject <SBQueueActionProtocol>
@end

/**
 *  An actions that applies a set to the item.
 */
@interface SBQueueSetAction : NSObject <SBQueueActionProtocol> {
@private
    MP42Metadata *_set;
}
- (instancetype)initWithSet:(MP42Metadata *)set;
@end

/**
 *  An actions that organize the item tracks' groups.
 */
@interface SBQueueOrganizeGroupsAction : NSObject <SBQueueActionProtocol>
@end

/**
 *  An actions that fix the item tracks' fallbacks.
 */
@interface SBQueueFixFallbacksAction : NSObject <SBQueueActionProtocol>
@end

NS_ASSUME_NONNULL_END
