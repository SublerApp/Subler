//
//  SBChapterResult.m
//  Subler
//
//  Created by Damiano Galassi on 25/11/15.
//
//

#import "SBChapterResult.h"

@implementation SBChapterResult

@synthesize title = _title;
@synthesize duration = _duration;
@synthesize confirmations = _confirmations;

@synthesize chapters = _chapters;

- (instancetype)initWithTitle:(NSString *)title duration:(NSUInteger)duration confirmations:(NSUInteger)confirmations chapters:(NSArray<MP42TextSample *> *)chapters
{
    self = [super init];
    if (self) {
        _title = [title copy];
        _duration = duration;
        _confirmations = confirmations;
        _chapters = [chapters copy];
    }
    return self;
}

@end
