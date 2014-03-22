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

    NSMutableDictionary *_options;
    NSMutableArray *_sets;

    NSURL *_destination;
}

- (instancetype)initWithOptions:(NSMutableDictionary *)options;

@end
