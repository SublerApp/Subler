//
//  MyDocument.h
//  MP4Dump
//
//  Created by Damiano Galassi on 27/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


#import <Cocoa/Cocoa.h>

@interface MyDocument : NSDocument
{
    IBOutlet NSTextView * textView;
    IBOutlet NSPopUpButton *logLevelButton;
    NSString *result;
}

- (IBAction)setLogLevel:(id)sender;

@end
