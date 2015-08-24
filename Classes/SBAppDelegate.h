//
//  SBAppDelegate.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBPrefsController;
@class SBLogWindowController;

@interface SBDocumentController : NSDocumentController
@end

@interface SBAppDelegate : NSObject {
    SBPrefsController *prefController;
    SBLogWindowController *debugLogController;
	SBDocumentController *documentController;
}

- (IBAction) showBatchWindow: (id) sender;
- (IBAction) showPrefsWindow: (id) sender;
- (IBAction) donate:(id)sender;
- (IBAction) help:(id)sender;

- (IBAction) linkDonate: (id) sender;

@end

