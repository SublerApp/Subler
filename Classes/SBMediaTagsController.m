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
+ (NSArray<NSString *> *)predefinedTagsForMediaType:(MP42MediaType)mediaType;

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
            _localizedTitle = _value;
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

+ (NSArray<NSString *> *)predefinedTagsForMediaType:(MP42MediaType)mediaType {
    NSMutableArray *tags = [NSMutableArray array];
    [tags addObjectsFromArray:@[@"public.main-program-content",
                                @"public.auxiliary-content"]];

    if (mediaType == kMP42MediaType_Audio) {
        [tags addObjectsFromArray:@[@"public.accessibility.describes-video",
                                    @"public.translation.dubbed",
                                    @"public.translation.voice-over"]];
    }

    else if (mediaType == kMP42MediaType_Subtitle ||
             mediaType == kMP42MediaType_ClosedCaption) {

        [tags addObjectsFromArray:@[@"public.subtitles.forced-only",
                                    @"public.accessibility.transcribes-spoken-dialog",
                                    @"public.accessibility.describes-music-and-sound",
                                    @"public.easy-to-read"]];

    }

    if (mediaType == kMP42MediaType_Subtitle ||
        mediaType == kMP42MediaType_ClosedCaption ||
        mediaType == kMP42MediaType_Audio) {

        [tags addObjectsFromArray:@[@"public.translation"]];
    }

    return tags;
}

+ (nullable NSString *)localizedTitleForTag:(NSString *)tag {
    NSDictionary *localizedDescriptions = @{@"public.main-program-content": NSLocalizedString(@"Main Program Content", @"Media characteristic."),
                                            @"public.auxiliary-content": NSLocalizedString(@"Auxiliary Content", @"Media characteristic."),
                                            @"public.subtitles.forced-only": NSLocalizedString(@"Contains Only Forced Subtitles", @"Media characteristic."),
                                            @"public.accessibility.transcribes-spoken-dialog": NSLocalizedString(@"Transcribes Spoken Dialog For Accessibility", @"Media characteristic."),
                                            @"public.accessibility.describes-music-and-sound": NSLocalizedString(@"Describes Music And Sound For Accessibility", @"Media characteristic."),
                                            @"public.easy-to-read": NSLocalizedString(@"Easy To Read", @"Media characteristic."),
                                            @"public.accessibility.describes-video": NSLocalizedString(@"Describes Video For Accessibility", @"Media characteristic."),
                                            @"public.translation.dubbed": NSLocalizedString(@"Dubbed Translation", @"Media characteristic."),
                                            @"public.translation.voice-over": NSLocalizedString(@"Voice Over Translation", @"Media characteristic."),
                                            @"public.translation": NSLocalizedString(@"Language Translation", @"Media characteristic.") };
    return localizedDescriptions[tag];
}

- (NSString *)description
{
    NSString *description = super.description;
    description = [description stringByAppendingFormat:@" %@, state = %d", _value, _state];
    return description;
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

@property (nonatomic, readwrite, strong) SBMediaTag *representedTag;

@end

NS_ASSUME_NONNULL_END

@implementation SBCheckBoxTableCellView

- (void)setRepresentedTag:(SBMediaTag *)representedTag {
    _representedTag = representedTag;

    _checkBox.title = _representedTag.localizedTitle;
    _checkBox.state = _representedTag.state;
}

@end

@interface SBMediaTagsController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, readonly, nonnull) MP42Track *track;
@property (nonatomic, readonly, nonnull) NSArray<SBMediaTag *> *tags;

@end

#pragma mark - Main Class

@implementation SBMediaTagsController {
    IBOutlet NSTableView *_tableView;
}

- (instancetype)init {
    self = [super initWithNibName:@"SBMediaTagsController" bundle:nil];
    return self;
}

- (instancetype)initWithTrack:(MP42Track *)track {
    self = [self init];
    if (self) {
        _track = track;
        NSArray<NSString *> *predefinedTags = [SBMediaTag predefinedTagsForMediaType:track.mediaType];

        NSMutableArray<SBMediaTag *> *tags = [[NSMutableArray alloc] init];

        // Add the predefined tags
        for (NSString *availableTag in predefinedTags) {
            BOOL state = [track.mediaCharacteristicTags containsObject:availableTag] ? YES : NO;
            SBMediaTag *tag = [[SBMediaTag alloc] initWithValue:availableTag
                                                         state:state];
            [tags addObject:tag];
        }

        // Keep the custom ones if present
        NSMutableSet<NSString *> *custom = [track.mediaCharacteristicTags mutableCopy];
        [custom minusSet:[NSSet setWithArray:predefinedTags]];

        for (NSString *customTag in custom) {
            SBMediaTag *tag = [[SBMediaTag alloc] initWithValue:customTag state:YES];
            [tags addObject:tag];
        }


        _tags = [tags copy];
    }
    return self;
}

- (void)dealloc
{
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
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

    [self updateTrack];
}

- (void)updateTrack {
    NSMutableSet *set = [NSMutableSet set];

    for (SBMediaTag *tag in self.tags) {
        if (tag.state == YES) {
            [set addObject:tag.value];
        }
    }

    self.track.mediaCharacteristicTags = set;

    [self.view.window.windowController.document updateChangeCount:NSChangeDone];
}

@end
