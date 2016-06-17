//
//  SBChapterSearchController.h
//  Subler
//
//  Created by Michael Hueber on 20.11.15.
//
//

#import <Cocoa/Cocoa.h>
#import <MP42Foundation/MP42TextSample.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SBChapterSearchControllerDelegate

- (void)chapterImportDone:(NSArray<MP42TextSample *> *)chaptersToBeImported;

@end

@interface SBChapterSearchController : NSWindowController

- (instancetype)initWithDelegate:(id <SBChapterSearchControllerDelegate>)del searchTitle:(NSString *)title andDuration:(NSUInteger)duration; 

@end

NS_ASSUME_NONNULL_END
