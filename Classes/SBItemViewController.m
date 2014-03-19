//
//  SBItemViewController.m
//  Subler
//
//  Created by Damiano Galassi on 19/03/14.
//
//

#import "SBItemViewController.h"
#import "SBQueueItem.h"

@interface SBItemViewController ()

@property SBQueueItem *item;

@property (assign) IBOutlet NSTextField *nameLabel;
@property (assign) IBOutlet NSTextField *sourceLabel;
@property (assign) IBOutlet NSTextField *destinationLabel;

@property (assign) IBOutlet NSTextField *actionsLabel;

@end

@implementation SBItemViewController

@synthesize item = _item;

@synthesize nameLabel = _nameLabel;
@synthesize sourceLabel = _sourceLabel;
@synthesize destinationLabel = _destinationLabel;

@synthesize actionsLabel = _actionsLabel;

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
}

- (void)dealloc {
    [_item release];
    [super dealloc];
}

@end
