//
//  SBDocument.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MP42File;

@interface SBDocument : NSDocument

@property (nonatomic, strong) MP42File *mp4;

- (instancetype)initWithMP4:(MP42File *)mp4File error:(NSError * __autoreleasing *)outError;

- (IBAction)setSaveFormat:(NSPopUpButton *)sender;
- (IBAction)saveAndOptimize:(id)sender;

@end

NS_ASSUME_NONNULL_END
