//
//  SBDebugLogController.m
//  Subler
//
//  Created by Damiano Galassi on 24/10/14.
//
//

#import "SBLogWindowController.h"
#import "SBLogger.h"

@interface SBLogWindowController ()

@property (nonatomic, assign) IBOutlet NSTextView *logView;
@property (nonatomic, readonly) SBLogger *logger;

@end

@implementation SBLogWindowController

@synthesize logView = _logView;
@synthesize logger = _logger;

- (instancetype)init {
    if ((self = [super initWithWindowNibName:@"SBLogWindow"])) {
        (void)[self window];
    }

    return self;
}

- (instancetype)initWithLogger:(SBLogger *)logger {
    NSAssert(!_logger, @"Logger is nil");
    self = [self init];

    if (self) {
        _logger = [logger retain];
        _logger.delegate = self;
    }

    return self;
}

- (void)writeToLog:(NSString *)string {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string];
        [[self.logView textStorage] appendAttributedString:attributedString];
        [attributedString release];
    });
}

- (IBAction)clearLog:(id)sender {
    [[self.logView textStorage] deleteCharactersInRange:NSMakeRange(0, [[self.logView textStorage] length])];
    [self.logger clearLog];
}

- (void)dealloc
{
    [_logger release];
    _logger = nil;

    [super dealloc];
}

@end
