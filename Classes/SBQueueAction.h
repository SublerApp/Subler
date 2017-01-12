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
@protocol SBQueueActionProtocol <NSObject, NSSecureCoding>
- (void)runAction:(SBQueueItem *)item;
@property (nonatomic, readonly) NSString *localizedDescription;
@end

/**
 *  An actions that fetches metadata online.

 */
typedef NS_ENUM(NSUInteger, SBQueueMetadataActionPreferredArtwork) {
     SBQueueMetadataActionPreferredArtworkDefault,
     SBQueueMetadataActionPreferredArtworkiTunes,
     SBQueueMetadataActionPreferredArtworkEpisode,
     SBQueueMetadataActionPreferredArtworkSeason,
 };

@interface SBQueueMetadataAction : NSObject <SBQueueActionProtocol>
- (instancetype)initWithMovieLanguage:(NSString *)movieLang
                       tvShowLanguage:(NSString *)tvLang
                   movieProvider:(NSString *)movieProvider
                  tvShowProvider:(NSString *)tvShowProvider
                preferredArtwork:(SBQueueMetadataActionPreferredArtwork)preferredArtwork;
@end

/**
 *  An actions that search in the item source directory for additionals srt subtitles
 */
@interface SBQueueSubtitlesAction : NSObject <SBQueueActionProtocol>
@end

/**
 *  An actions that applies a set to the item.
 */
@interface SBQueueSetAction : NSObject <SBQueueActionProtocol>
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

/**
 *  An actions that remove the tracks names.
 */
@interface SBQueueClearTrackNameAction : NSObject <SBQueueActionProtocol>
@end

/**
 *  An actions that set unknown language tracks to preferred one.
 */
@interface SBQueueSetLanguageAction : NSObject <SBQueueActionProtocol>
- (instancetype)initWithLanguage:(NSString *)language;
@end

/**
 *  An actions that set the video track color space.
 */

typedef NS_ENUM(NSUInteger, SBQueueColorSpaceActionTag) {
     SBQueueColorSpaceActionTagNone = 1,
     SBQueueColorSpaceActionTagRec601PAL,
     SBQueueColorSpaceActionTagRec601SMPTEC,
     SBQueueColorSpaceActionTagRec709,
     SBQueueColorSpaceActionTagRec2020
 };
@interface SBQueueColorSpaceAction : NSObject <SBQueueActionProtocol>
- (instancetype)initWithTag:(uint16_t)tag;
- (instancetype)initWithColorPrimaries:(uint16_t)colorPrimaries transferCharacteristics:(uint16_t)transferCharacteristics matrixCoefficients:(uint16_t)matrixCoefficients;
@end

NS_ASSUME_NONNULL_END
