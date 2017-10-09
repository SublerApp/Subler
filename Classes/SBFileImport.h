//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42Track;
@class MP42Metadata;

@protocol SBFileImportDelegate
- (void)importDoneWithTracks:(NSArray<MP42Track *> *)tracksToBeImported andMetadata:(nullable MP42Metadata *)metadata;
@end

@interface SBFileImport : NSWindowController

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithURLs:(NSArray<NSURL *> *)fileURLs delegate:(id <SBFileImportDelegate>)delegate error:(NSError * __autoreleasing *)error;

- (IBAction)closeWindow:(id)sender;
- (IBAction)addTracks:(id)sender;

@property (nonatomic, readonly) BOOL onlyContainsSubtitleTracks;

- (IBAction)checkSelected:(id)sender;
- (IBAction)uncheckSelected:(id)sender;

@end

NS_ASSUME_NONNULL_END
