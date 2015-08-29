//
//  SBDebugLogController.h
//  Subler
//
//  Created by Damiano Galassi on 24/10/14.
//
//

#import <Cocoa/Cocoa.h>
#import <MP42Foundation/MP42Logging.h>

NS_ASSUME_NONNULL_BEGIN

@class SBLogger;

@interface SBLogWindowController : NSWindowController <MP42Logging> {
    @private
    NSTextView  *_logView;
    SBLogger    *_logger;
}

- (instancetype)initWithLogger:(SBLogger *)logger;

@end

NS_ASSUME_NONNULL_END
