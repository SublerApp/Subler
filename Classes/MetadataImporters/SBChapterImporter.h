//
//  SBChapterImporter.h
//  Subler
//
//  Created by Michael Hueber on 21.11.15.
//
//

#import <Foundation/Foundation.h>
#import "SBMetadataHelper.h"

@class SBChapterResult;

NS_ASSUME_NONNULL_BEGIN

@interface SBChapterImporter : NSObject {
@private
    BOOL _isCancelled;
}

+ (NSString *)defaultProvider;

+ (instancetype)importerForProvider:(NSString *)providerName;
- (void) searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration completionHandler:(void(^)(NSArray<SBChapterResult *> * _Nullable results))handler;
- (void) cancel;

#pragma mark Methods to be overridden

- (NSArray<SBChapterResult *> *)searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration;

@end

NS_ASSUME_NONNULL_END
