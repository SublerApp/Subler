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

@interface SBChapterImporter : NSObject

+ (NSString *)defaultProvider;

+ (nullable instancetype)importerForProvider:(NSString *)providerName;

#pragma mark Methods to be overridden

- (void)searchTitle:(NSString *)title language:(nullable NSString *)language duration:(NSUInteger)duration completionHandler:(void(^)(NSArray<SBChapterResult *> *results))handler;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
