//
//  SBLogger.m
//  Subler
//

#import "SBApplication.h"
#import "Subler-Swift.h"

@implementation SBApplication

static void CrashMyApplication()
{
    *(char *)0x08 = 1;
}

- (NSAttributedString *)_formattedExceptionBacktrace:(NSArray *)backtrace
{
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSDictionary *textAttributes = @{NSForegroundColorAttributeName: NSColor.textColor,
                                     NSFontAttributeName: [NSFont fontWithName:@"Monaco" size:10]};

    for (__strong NSString *s in backtrace)
    {
        s = [s stringByAppendingString:@"\n"];
        NSAttributedString *attrS = [[NSAttributedString alloc] initWithString:s];
        [result appendAttributedString:attrS];
    }
    [result addAttributes:textAttributes range:NSMakeRange(0, result.length)];
    return result;
}

- (void)reportException:(NSException *)exception
{
    // NSApplication simply logs the exception to the console. We want to let the user know
    // when it happens in order to possibly prevent subsequent random crashes that are difficult to debug
    @try
    {
        @autoreleasepool
        {
            // Create a string based on the exception
            NSString *exceptionMessage = [NSString stringWithFormat:@"%@\nReason: %@\nUser Info: %@", exception.name, exception.reason, exception.userInfo];
            
            ExceptionAlertController *alertController = [[ExceptionAlertController alloc] initWithExceptionMessage:exceptionMessage exceptionBacktrace:[self _formattedExceptionBacktrace:exception.callStackSymbols]];

            NSInteger result = [alertController runModal];
            if (result == NSModalResponseStop)
            {
                CrashMyApplication();
            }
        }
    }
    @catch (NSException *e)
    {
        // Suppress any exceptions raised in the handling
    }    
}

@end
