//
//  SBItemViewController.m
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import "SBItemViewController.h"

#import "SBQueueItem.h"
#import "SBQueueController.h"

static void *SBItemViewContex = &SBItemViewContex;

@interface SBItemViewController ()

@property SBQueueItem *item;

@property (assign) IBOutlet NSTextField *nameLabel;
@property (assign) IBOutlet NSTextField *sourceLabel;
@property (assign) IBOutlet NSTextField *destinationLabel;

@property (assign) IBOutlet NSTextField *actionsLabel;

@property (assign) IBOutlet NSButton *editButton;
@property (assign) IBOutlet NSProgressIndicator *spinner;

@end

@implementation SBItemViewController

@synthesize item = _item;
@synthesize delegate = _delegate;

@synthesize nameLabel = _nameLabel;
@synthesize sourceLabel = _sourceLabel;
@synthesize destinationLabel = _destinationLabel;

@synthesize actionsLabel = _actionsLabel;

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

    [self.nameLabel setStringValue:[self.item.URL lastPathComponent]];
    [self.sourceLabel setStringValue:[self.item.URL path]];
    [self.destinationLabel setStringValue:[self.item.destURL path]];

    NSMutableString *actions = [[[NSMutableString alloc] init] autorelease];
    for (id<SBQueueActionProtocol> action in self.item.actions) {
        [actions appendString:[NSString stringWithFormat:@"%@\n", [action description]]];
    }

    if ([actions length]) {
        [self.actionsLabel setStringValue:actions];
    } else {
        [self.actionsLabel setStringValue:@"None"];
    }

    NSSize frameSize = self.view.frame.size;
    frameSize.height += [self.item.actions count] ? self.actionsLabel.frame.size.height * ([self.item.actions count] - 1) : 0;
    [self.view setFrameSize:frameSize];

    // Observe the item status
    [self addObserver:self forKeyPath:@"item.status" options:NSKeyValueObservingOptionInitial context:SBItemViewContex];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == SBItemViewContex) {
        // Disable the edit button if the item status
        // is different from ready
        if ([keyPath isEqualToString:@"item.status"]) {
            if (self.item.status != SBQueueItemStatusReady) {
                [self.editButton setEnabled:NO];
            } else {
                [self.editButton setEnabled:YES];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)edit:(id)sender {
    [self.spinner setHidden:NO];

    if ([self.delegate respondsToSelector:@selector(editItem:)]) {
        [self.delegate performSelector:@selector(editItem:) withObject:self.item];
    }
}

- (void)dealloc {
    [_item release];

    @try {
        [self removeObserver:self forKeyPath:@"item.status"];
    } @catch (NSException * __unused exception) {}

    [super dealloc];
}

@end
