//
//  SBChapterImporter.m
//  Subler
//
//  Created by Michael Hueber on 21.11.15.
//
//

#import "SBChapterImporter.h"
#import <MP42Foundation/MP42ChapterTrack.h>

#import "SBChapterDB.h"

@implementation SBChapterImporter

+ (NSString *)defaultProvider
{
    return @"ChapterDB";
}

+ (nullable instancetype)importerForProvider:(NSString *)aProvider
{
    if ([aProvider isEqualToString:@"ChapterDB"]) {
        return [[SBChapterDB alloc] init];
    }
    return nil;
}

- (void)searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration completionHandler:(void(^)(NSArray<SBChapterResult *> *results))handler
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (void)cancel
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end
