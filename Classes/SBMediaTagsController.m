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

NS_ASSUME_NONNULL_BEGIN

/**
 *  A SBMediaTag is composed of a tag value and a boolean state.
 */
@interface SBMediaTag : NSObject {
@private
    BOOL _state;
    NSString *_value;
    NSString *_localizedTitle;
    NSString *_localizedDescription;
}

/**
 *  Returns the complete array of the predefined tags.
 */
+ (NSArray<NSString *> *)predefinedTags;

/**
 *  Returns the predefined supported media tags
 *  for a particular media type.
 *
 *  @param mediaType a MP42MediaType type.
 *
 *  @return an array of NSString with the supported tags.
 */
+ (NSArray<NSString *> *)predefinedTagsForMediaType:(NSString *)mediaType;

/**
 *  Returns the localized human readable title of a partical tag.
 */
+ (nullable NSString *)localizedTitleForTag:(NSString *)tag;

@property (nonatomic, readwrite) BOOL state;
@property (nonatomic, readonly) NSString *value;
@property (nonatomic, readonly) NSString *localizedTitle;
@property (nonatomic, readonly) NSString *localizedDescription;

@end

NS_ASSUME_NONNULL_END

@implementation SBMediaTag

- (instancetype)initWithValue:(NSString *)value state:(BOOL)state {
    self = [super init];
    if (self) {
        _state = state;
        _value = [value copy];
        _localizedTitle = [[SBMediaTag localizedTitleForTag:_value] copy];

        if (_localizedTitle == nil) {
            _localizedTitle = [_value retain];
        }
    }

    return self;
}

+ (NSArray<NSString *> *)predefinedTags {
    return @[@"public.main-program-content", @"public.auxiliary-content",
             @"public.subtitles.forced-only", @"public.accessibility.transcribes-spoken-dialog",
             @"public.accessibility.describes-music-and-sound", @"public.easy-to-read",
             @"public.accessibility.describes-video", @"public.translation.dubbed",
             @"public.translation.voice-over", @"public.translation"];
}

+ (NSArray<NSString *> *)predefinedTagsForMediaType:(NSString *)mediaType {
    NSMutableArray *tags = [NSMutableArray array];
    [tags addObjectsFromArray:@[@"public.main-program-content",
                                @"public.auxiliary-content"]];

    if ([mediaType isEqualToString:MP42MediaTypeAudio]) {
        [tags addObjectsFromArray:@[@"public.accessibility.describes-video",
                                    @"public.translation.dubbed",
                                    @"public.translation.voice-over"]];
    }

    else if ([mediaType isEqualToString:MP42MediaTypeSubtitle] ||
             [mediaType isEqualToString:MP42MediaTypeClosedCaption]) {

        [tags addObjectsFromArray:@[@"public.subtitles.forced-only",
                                    @"public.accessibility.transcribes-spoken-dialog",
                                    @"public.accessibility.describes-music-and-sound",
                                    @"public.easy-to-read"]];

    }

    if ([mediaType isEqualToString:MP42MediaTypeSubtitle] ||
        [mediaType isEqualToString:MP42MediaTypeClosedCaption] ||
        [mediaType isEqualToString:MP42MediaTypeAudio]) {

        [tags addObjectsFromArray:@[@"public.translation"]];
    }

    return tags;
}

+ (nullable NSString *)localizedTitleForTag:(NSString *)tag {
    NSDictionary *localizedDescriptions = @{@"public.main-program-content": NSLocalizedString(@"Main Program Content", nil),
                                            @"public.auxiliary-content": NSLocalizedString(@"Auxiliary Content", nil),
                                            @"public.subtitles.forced-only": NSLocalizedString(@"Contains Only Forced Subtitles", nil),
                                            @"public.accessibility.transcribes-spoken-dialog": NSLocalizedString(@"Transcribes Spoken Dialog For Accessibility", nil),
                                            @"public.accessibility.describes-music-and-sound": NSLocalizedString(@"Describes Music And Sound For Accessibility", nil),
                                            @"public.easy-to-read": NSLocalizedString(@"Easy To Read", nil),
                                            @"public.accessibility.describes-video": NSLocalizedString(@"Describes Video For Accessibility", nil),
                                            @"public.translation.dubbed": NSLocalizedString(@"Dubbed Translation", nil),
                                            @"public.translation.voice-over": NSLocalizedString(@"Voice Over Translation", nil),
                                            @"public.translation": NSLocalizedString(@"Language Translation", nil) };
    return localizedDescriptions[tag];
}

@synthesize state = _state;
@synthesize value= _value;
@synthesize localizedTitle = _localizedTitle;
@synthesize localizedDescription = _localizedDescription;

- (void)dealloc {
    [_value release];
    _value = nil;
    [_localizedTitle release];
    _localizedTitle = nil;
    [_localizedDescription release];
    _localizedDescription = nil;

    [super dealloc];
}

@end

NS_ASSUME_NONNULL_BEGIN

/**
 *  A NSTableCellView that contains a single checkbox.
 */
@interface SBCheckBoxTableCellView : NSTableCellView {
    IBOutlet NSButton *_checkBox;
    SBMediaTag *_representedTag;
}


@property (nonatomic, readwrite, retain) SBMediaTag *representedTag;

@end

NS_ASSUME_NONNULL_END

@implementation SBCheckBoxTableCellView

@synthesize representedTag = _representedTag;

- (void)setRepresentedTag:(SBMediaTag *)representedTag {
    [_representedTag autorelease];
    _representedTag = [representedTag retain];

    _checkBox.title = _representedTag.localizedTitle;
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
        NSArray<NSString *> *predefinedTags = [SBMediaTag predefinedTagsForMediaType:track.mediaType];

        NSMutableArray<SBMediaTag *> *tags = [[NSMutableArray alloc] init];

        // Add the predefined tags
        for (NSString *availableTag in predefinedTags) {
            BOOL state = [track.mediaCharacteristicTags containsObject:availableTag] ? YES : NO;
            SBMediaTag *tag = [[SBMediaTag alloc] initWithValue:availableTag
                                                         state:state];
            [tags addObject:tag];
            [tag release];
        }

        // Keep the custom ones if present
        NSMutableSet<NSString *> *custom = [track.mediaCharacteristicTags mutableCopy];
        [custom minusSet:[NSSet setWithArray:predefinedTags]];

        for (NSString *customTag in custom) {
            SBMediaTag *tag = [[SBMediaTag alloc] initWithValue:customTag state:YES];
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
            [set addObject:tag.value];
        }
    }

    self.track.mediaCharacteristicTags = set;

    [NSApp endSheet:self.window returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender{
    [NSApp endSheet:self.window returnCode:NSCancelButton];
}

@end
