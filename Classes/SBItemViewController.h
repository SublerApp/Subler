//
//  SBItemViewController.h
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import <Cocoa/Cocoa.h>

@class SBQueueItem;

@protocol SBItemViewDelegate <NSObject>

- (void)setPopoverSize:(NSSize)size;
- (void)editItem:(SBQueueItem *)item;

@end

@interface SBItemViewController : NSViewController {
@private
    SBQueueItem *_item;

    NSButton *_editButton;
    NSProgressIndicator *_spinner;

    id _delegate;
}

@property (nonatomic, readonly) SBQueueItem *item;
@property (nonatomic, assign, readwrite) id delegate;

- (instancetype)initWithItem:(SBQueueItem *)item;

@end
