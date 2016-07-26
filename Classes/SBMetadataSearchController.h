//
//  MetadataImportController.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class SBMetadataResult;

@protocol SBMetadataSearchControllerDelegate
- (void)metadataImportDone:(SBMetadataResult *)metadataToBeImported;
@end

@interface SBMetadataSearchController : NSWindowController

#pragma mark Initialization
- (instancetype)initWithDelegate:(id <SBMetadataSearchControllerDelegate>)del searchString:(NSString *)searchString;

#pragma mark Static methods
+ (void) clearRecentSearches;
+ (void) deleteCachedMetadata;

@end

NS_ASSUME_NONNULL_END
