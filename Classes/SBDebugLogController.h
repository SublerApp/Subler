//
//  SBDebugLogController.h
//  Subler
//
//  Created by Damiano Galassi on 24/10/14.
//
//

#import <Cocoa/Cocoa.h>

@interface SBDebugLogController : NSWindowController {
    NSTextView *logView;
}

- (void)log:(NSString *)string;

@end
