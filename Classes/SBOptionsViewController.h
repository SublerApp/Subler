//
//  QueueOptionsController.h
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import <Cocoa/Cocoa.h>

@interface SBOptionsViewController : NSViewController {
    IBOutlet NSPopUpButton *_destButton;
    IBOutlet NSPopUpButton *_setsPopup;

    NSMutableDictionary *_options;

    NSURL *_destination;
    BOOL _customDestination;
}

- (instancetype)initWithOptions:(NSMutableDictionary *)options;

@end
