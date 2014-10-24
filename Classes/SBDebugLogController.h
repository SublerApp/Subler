//
//  SBDebugLogController.h
//  Subler
//
//  Created by Damiano Galassi on 24/10/14.
//
//

#import <Cocoa/Cocoa.h>

@interface SBDebugLogController : NSWindowController {
    NSTextView  *_logView;
    NSURL       *_fileURL;
}

- (instancetype)initWithLogFile:(NSURL *)fileURL;
- (void)log:(NSString *)string;

@end
