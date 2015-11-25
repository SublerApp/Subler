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

@interface SBChapterImporter ()

@property (atomic, readwrite) BOOL isCancelled;

@end

@implementation SBChapterImporter

@synthesize isCancelled = _isCancelled;

+ (NSString *)defaultProvider
{
    return @"ChapterDB";
}

+ (instancetype)importerForProvider:(NSString *)aProvider
{
    if ([aProvider isEqualToString:@"ChapterDB"]) {
        return [[[SBChapterDB alloc] init] autorelease];
    }
    return nil;
}

- (void)searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration completionHandler:(void(^)(NSArray<SBChapterResult *> * _Nullable results))handler
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *results = [self searchTitle:title language:language duration:duration];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.isCancelled) {
                handler(results);
            }
        });
    });
}

- (void)cancel
{
    self.isCancelled = YES;
}

- (NSArray<SBChapterResult *> *)searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end
