//
//  SBLogger.m
//  Subler
//
 
#import "SBExceptionAlertController.h"

@implementation SBExceptionAlertController

- (instancetype)init
{
    return [self initWithWindowNibName:@"ExceptionAlert"];
}

@synthesize exceptionBacktrace = _exceptionBacktrace;
@synthesize exceptionMessage = _exceptionMessage;

- (NSInteger)runModal
{
    return [NSApp runModalForWindow:self.window];
}

- (IBAction)btnCrashClicked:(id)sender
{
    [self.window orderOut:nil];
    [NSApp stopModalWithCode:SBExceptionAlertControllerResultCrash];
}

- (IBAction)btnContinueClicked:(id)sender
{
    [self.window orderOut:nil];
    [NSApp stopModalWithCode:SBExceptionAlertControllerResultContinue];
}

@end
