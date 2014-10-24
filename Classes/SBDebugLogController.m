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
@property (readonly) NSURL *fileURL;

@end

@implementation SBDebugLogController

@synthesize logView = _logView;
@synthesize fileURL = _fileURL;

- (instancetype)init {
    if ((self = [super initWithWindowNibName:@"SBDebugLogWindow"])) {
        [self window];
    }

    return self;
}

- (instancetype)initWithLogFile:(NSURL *)fileURL {
    self = [self init];

    if (self) {
        _fileURL = [fileURL copy];
        [[NSFileManager defaultManager] removeItemAtURL:_fileURL error:nil];
    }

    return self;
}

- (void)log:(NSString *)string {
    if (self.fileURL) {
        FILE *f = fopen([self.fileURL fileSystemRepresentation], "a");
        fprintf(f, "%s", [string UTF8String]);
        fclose(f);
    }

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
