//
//  QueueOptionsController.h
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import <Cocoa/Cocoa.h>

@interface SBOptionsViewController : NSViewController {
    IBOutlet NSButton *_optimizeOption;
    IBOutlet NSButton *_metadataOption;
    IBOutlet NSButton *_organizeGroupsOption;
    IBOutlet NSButton *_autoStartOption;

    IBOutlet NSPopUpButton *_destButton;

    NSMutableDictionary *_options;

    NSURL *_destination;
    BOOL _customDestination;
}

- (instancetype)initWithOptions:(NSMutableDictionary *)options;

@end
