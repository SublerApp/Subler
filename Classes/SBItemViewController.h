//
//  SBItemViewController.h
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class SBQueueItem;

@protocol SBItemViewDelegate <NSObject>

- (void)setPopoverSize:(NSSize)size;
- (void)editItem:(SBQueueItem *)item;

@end

@interface SBItemViewController : NSViewController

@property (nonatomic, readonly) SBQueueItem *item;
@property (nonatomic, unsafe_unretained, readwrite) id<SBItemViewDelegate> delegate;

- (instancetype)initWithItem:(SBQueueItem *)item;

@end

NS_ASSUME_NONNULL_END
