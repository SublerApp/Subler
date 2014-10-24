//
//  SBDebugLogController.m
//  Subler
//
//  Created by Damiano Galassi on 24/10/14.
//
//

#import "SBDebugLogController.h"

@interface SBDebugLogController ()

@property (assign) IBOutlet NSTextView *logView;

@end

@implementation SBDebugLogController
@synthesize logView;

- (instancetype)init
{
    if ((self = [super initWithWindowNibName:@"SBDebugLogWindow"])) {
        [self window];
    }

    return self;
}


- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)log:(NSString *)string {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string];
        [[self.logView textStorage] appendAttributedString:attributedString];
        [attributedString release];
    });
}

- (IBAction)clearLog:(id)sender {
    [[self.logView textStorage] deleteCharactersInRange:NSMakeRange(0, [[self.logView textStorage] length])];
}

@end
