//
//  SBLogger.m
//  Subler
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, SBExceptionAlertControllerResult) {
    SBExceptionAlertControllerResultCrash,
    SBExceptionAlertControllerResultContinue,
};

@interface SBExceptionAlertController : NSWindowController {
    NSString *_exceptionMessage;
    NSAttributedString *_exceptionBacktrace;
}

// Properties are used by bindings
@property (nonatomic, copy) NSString *exceptionMessage;
@property (nonatomic, copy) NSAttributedString *exceptionBacktrace;

- (IBAction)btnCrashClicked:(id)sender;
- (IBAction)btnContinueClicked:(id)sender;

- (NSInteger)runModal;

@end
