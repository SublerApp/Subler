//
//  SBChapterResult.h
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42TextSample;

@interface SBChapterResult : NSObject {
@private
    NSString *_title;
    NSUInteger _duration;
    NSUInteger _confirmations;

    NSArray<MP42TextSample *> *_chapters;
}

- (instancetype)initWithTitle:(NSString *)title duration:(NSUInteger)duration confirmations:(NSUInteger)confirmations chapters:(NSArray<MP42TextSample *> *)chapters;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSUInteger duration;
@property (nonatomic, readonly) NSUInteger confirmations;

@property (nonatomic, readonly) NSArray<MP42TextSample *> *chapters;

@end

NS_ASSUME_NONNULL_END
