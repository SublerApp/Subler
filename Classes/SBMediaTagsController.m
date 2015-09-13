//
//  SBMediaTagsController.m
//  Subler
//
//  Created by Damiano Galassi on 12/09/15.
//
//

#import "SBMediaTagsController.h"
#import <MP42Foundation/MP42Track.h>

#pragma mark - Helpers

@interface SBMediaTag : NSObject {
    BOOL _state;
    NSString *_name;
    NSString *_localizedName;
    NSString *_localizedDescription;

}

@property (nonatomic, readwrite) BOOL state;
@property (nonatomic, readonly, nonnull) NSString *name;

@end

@implementation SBMediaTag

- (instancetype)initWithName:(NSString *)name state:(BOOL)state {
    self = [super init];
    if (self) {
        _state = state;
        _name = [name copy];
    }

    return self;
}

@synthesize state = _state;
@synthesize name = _name;

- (void)dealloc {
    [_name release];
    _name = nil;
    [super dealloc];
}

@end

@interface SBCheckBoxTableCellView : NSTableCellView {
    IBOutlet NSButton *_checkBox;
    SBMediaTag *_representedTag;
}


@property (nonatomic, readwrite, retain, nonnull) SBMediaTag *representedTag;

@end

@implementation SBCheckBoxTableCellView

@synthesize representedTag = _representedTag;

- (void)setRepresentedTag:(SBMediaTag *)representedTag {
    [_representedTag autorelease];
    _representedTag = [representedTag retain];

    _checkBox.title = _representedTag.name;
    _checkBox.state = _representedTag.state;
}

@end

@interface SBMediaTagsController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, readonly, nonnull) MP42Track *track;
@property (nonatomic, readonly, nonnull) NSArray<SBMediaTag *> *tags;

@end

#pragma mark - Main Class

@implementation SBMediaTagsController

- (instancetype)init {
    self = [super initWithWindowNibName:@"SBMediaTagsController"];
    if (self) {
    }
    return self;
}

- (instancetype)initWithTrack:(MP42Track *)track {
    self = [self init];
    if (self) {
        _track = [track retain];
        NSArray *predefinedTags = @[@"public.main-program-content", @"public.auxiliary-content",
                           @"public.subtitles.forced-only", @"public.accessibility.transcribes-spoken-dialog",
                           @"public.accessibility.describes-music-and-sound", @"public.easy-to-read",
                           @"public.accessibility.describes-video", @"public.translation.dubbed",
                           @"public.translation.voice-over", @"public.translation"];

        NSMutableArray<SBMediaTag *> *tags = [[NSMutableArray alloc] init];

        // Add the predefined tags
        for (NSString *availableTag in predefinedTags) {
            BOOL state = [track.mediaCharacteristicTags containsObject:availableTag] ? YES : NO;
            SBMediaTag *tag = [[SBMediaTag alloc] initWithName:availableTag state:state];
            [tags addObject:tag];
            [tag release];
        }

        // Keep the custom ones if present
        NSMutableSet<NSString *> *custom = [track.mediaCharacteristicTags mutableCopy];
        [custom minusSet:[NSSet setWithArray:predefinedTags]];

        for (NSString *customTag in custom) {
            SBMediaTag *tag = [[SBMediaTag alloc] initWithName:customTag state:YES];
            [tags addObject:tag];
            [tag release];
        }

        [custom release];

        _tags = [tags copy];
        [tags release];
    }
    return self;
}

@synthesize track = _track;
@synthesize tags = _tags;

- (void)dealloc {
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
    [_track release];
    _track = nil;
    [_tags release];
    _tags = nil;

    [super dealloc];
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.tags.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    SBCheckBoxTableCellView *result = [tableView makeViewWithIdentifier:@"SBCheckBoxTableCellView" owner:self];
    result.representedTag = self.tags[row];

    return result;
}

- (IBAction)setTagState:(NSButton *)sender {
    NSInteger row = [_tableView rowForView:sender];
    self.tags[row].state = sender.state;
}

- (IBAction)done:(id)sender {
    NSMutableSet *set = [NSMutableSet set];

    for (SBMediaTag *tag in self.tags) {
        if (tag.state == YES) {
            [set addObject:tag.name];
        }
    }

    self.track.mediaCharacteristicTags = set;

    [NSApp endSheet:self.window returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender{
    [NSApp endSheet:self.window returnCode:NSCancelButton];
}

@end
