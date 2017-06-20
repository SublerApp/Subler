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

#define TABLE_ROW_HEIGHT 16

@interface SBItemViewController ()
{
    id<SBItemViewDelegate> __unsafe_unretained _delegate;
}

@property (nonatomic) SBQueueItem *item;

@property (nonatomic, weak) IBOutlet NSButton *editButton;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *spinner;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableHeight;

@end

@implementation SBItemViewController

@synthesize item = _item;
@synthesize delegate = _delegate;

@synthesize editButton = _editButton;
@synthesize spinner = _spinner;

- (instancetype)initWithItem:(SBQueueItem *)item {
    self = [self init];
    if (self) {
        _item = item;
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
            dispatch_async(dispatch_get_main_queue(), ^{
                if (newStatus != SBQueueItemStatusReady && newStatus != SBQueueItemStatusEditing) {
                    [self.editButton setEnabled:NO];
                } else {
                    [self.editButton setEnabled:YES];
                }
            });
        } else if ([keyPath isEqualToString:@"item.actions"]) {
            NSInteger count = [change[NSKeyValueChangeNewKey] count] - [change[NSKeyValueChangeOldKey] count];
            CGFloat height = TABLE_ROW_HEIGHT * (count >= 0 ? count : 1);
            [self.tableHeight setConstant:height];
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
    @try {
        [self removeObserver:self forKeyPath:@"item.status"];
        [self removeObserver:self forKeyPath:@"item.actions"];
    } @catch (NSException * __unused exception) {}

}

@end
