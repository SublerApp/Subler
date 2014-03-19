//
//  SBItemViewController.h
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import <Cocoa/Cocoa.h>

@class SBQueueItem;

@interface SBItemViewController : NSViewController {
@private
    SBQueueItem *_item;

    NSTextField *_nameLabel;
    NSTextField *_sourceLabel;
    NSTextField *_destinationLabel;

    NSTextField *_actionsLabel;

    id _delegate;
}

@property (nonatomic, readonly) SBQueueItem *item;
@property (nonatomic, assign, readwrite) id delegate;

- (instancetype)initWithItem:(SBQueueItem *)item;

@end
