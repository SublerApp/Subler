//
//  SBItemViewController.m
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import "SBItemViewController.h"
#import "SBQueueItem.h"

static void *SBItemViewContex = &SBItemViewContex;

#define TABLE_ROW_HEIGHT 14

@interface SBItemViewController ()

@property (nonatomic) SBQueueItem *item;

@property (nonatomic, assign) IBOutlet NSButton *editButton;
@property (nonatomic, assign) IBOutlet NSProgressIndicator *spinner;

@end

@implementation SBItemViewController

@synthesize item = _item;
@synthesize delegate = _delegate;

@synthesize editButton = _editButton;
@synthesize spinner = _spinner;

- (instancetype)initWithItem:(SBQueueItem *)item {
    self = [self init];
    if (self) {
        _item = [item retain];
    }
    return self;
}

- (instancetype)init {
    self = [super initWithNibName:@"QueueItem" bundle:nil];
    return self;
}

- (void)loadView {
    [super loadView];

    // Observe the item status
    [self addObserver:self
           forKeyPath:@"item.status"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:SBItemViewContex];

    // Observe the item actions
    [self addObserver:self
           forKeyPath:@"item.actions"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
              context:SBItemViewContex];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SBItemViewContex) {
        // Disable the edit button if the item status
        // is different from ready
        if ([keyPath isEqualToString:@"item.status"]) {
            SBQueueItemStatus newStatus = [[change valueForKey:NSKeyValueChangeNewKey] integerValue];
            if (newStatus != SBQueueItemStatusReady && newStatus != SBQueueItemStatusEditing) {
                [self.editButton setEnabled:NO];
            } else {
                [self.editButton setEnabled:YES];
            }
        } else if ([keyPath isEqualToString:@"item.actions"]) {
            NSInteger count = [[change objectForKey:NSKeyValueChangeNewKey] count] - [[change objectForKey:NSKeyValueChangeOldKey] count];
            NSSize frameSize = self.view.frame.size;
            frameSize.height += TABLE_ROW_HEIGHT * (count >= 0 ? count - 1 : count);
            if ([self.delegate respondsToSelector:@selector(setPopoverSize:)]) {
                [self.delegate setPopoverSize:frameSize];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)edit:(id)sender {
    [self.spinner setHidden:NO];

    if ([self.delegate respondsToSelector:@selector(editItem:)]) {
        [self.delegate editItem:self.item];
    }
}

- (void)dealloc {
    [_item release];

    @try {
        [self removeObserver:self forKeyPath:@"item.status"];
        [self removeObserver:self forKeyPath:@"item.actions"];
    } @catch (NSException * __unused exception) {}

    [super dealloc];
}

@end
