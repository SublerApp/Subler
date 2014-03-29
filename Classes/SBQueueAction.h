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

@protocol SBQueueActionProtocol <NSObject, NSCoding>
- (void)runAction:(SBQueueItem *)item;
@end

@interface SBQueueMetadataAction : NSObject <SBQueueActionProtocol>
@end

@interface SBQueueSubtitlesAction : NSObject <SBQueueActionProtocol>
@end

@interface SBQueueSetAction : NSObject <SBQueueActionProtocol> {
@private
    MP42Metadata *_set;
}
- (id)initWithSet:(MP42Metadata *)set;
@end

@interface SBQueueOrganizeGroupsAction : NSObject <SBQueueActionProtocol>
@end
