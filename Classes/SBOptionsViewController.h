//
//  QueueOptionsController.h
//  Subler
//
//  Created by Damiano Galassi on 16/03/14.
//
//

#import <Cocoa/Cocoa.h>

@interface SBOptionsViewController : NSViewController {
    @private
    IBOutlet NSPopUpButton *_destButton;
    IBOutlet NSPopUpButton *_setsPopup;

    NSMutableDictionary *_options;

    NSURL *_destination;
}

- (instancetype)initWithOptions:(NSMutableDictionary *)options;

@end
