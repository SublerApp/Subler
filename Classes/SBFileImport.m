//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import "SBFileImport.h"
#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42FileImporter.h>
#import <MP42Foundation/MP42Utilities.h>
#import <MP42Foundation/MP42Languages.h>

@interface SBFileImport () <NSTableViewDelegate>
{
@private
    NSArray<NSURL *>  *_fileURLs;

    NSMutableArray<MP42FileImporter *> *_fileImporters;
    NSMutableArray  *_tracks;

    NSMutableArray<NSNumber *> *_importCheckArray;
    NSMutableArray<NSNumber *> *_actionArray;

    id<SBFileImportDelegate> _delegate;

    IBOutlet NSTableView *tracksTableView;
    IBOutlet NSButton    *addTracksButton;
    IBOutlet NSButton    *importMetadata;
}

@end

@implementation SBFileImport

- (nullable instancetype)initWithURLs:(NSArray<NSURL *> *)fileURLs delegate:(id <SBFileImportDelegate>)delegate error:(NSError * __autoreleasing *)error
{
	if ((self = [super initWithWindowNibName:@"FileImport"])) {
		_delegate = delegate;
        _fileURLs = [fileURLs copy];
        _fileImporters = [[NSMutableArray alloc] initWithCapacity:fileURLs.count];
        _tracks = [[NSMutableArray alloc] init];

        // Load the files.
        for (NSURL *url in fileURLs) {
            MP42FileImporter *importer = [[MP42FileImporter alloc] initWithURL:url error:error];
            if (importer) {
                [_tracks addObject:url.lastPathComponent];
                [_fileImporters addObject:importer];
                [_tracks addObjectsFromArray:importer.tracks];
            }
        }

        if (!_tracks.count) {
            return nil;
        }
	}

	return self;
}

/**
 * Fills the checkboxes and actions menu defaults
 */
- (void)_prepareActionArray
{
    _importCheckArray = [[NSMutableArray alloc] initWithCapacity:_tracks.count];
    _actionArray = [[NSMutableArray alloc] initWithCapacity:_tracks.count];

    for (MP42Track *object in _tracks) {
        if ([object isKindOfClass:[MP42Track class]]) {

            // Set the checkbox state
            if (isTrackMuxable(object.format) || trackNeedConversion(object.format)) {
                [_importCheckArray addObject:@YES];
            } else {
                [_importCheckArray addObject:@NO];
            }

            // Set the action menu selection
            // AC-3 Specific actions
            if ((object.format == kMP42AudioCodecType_AC3 || object.format == kMP42AudioCodecType_EnhancedAC3) &&
                [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepAC3"] boolValue] &&
                    [(MP42AudioTrack *)object fallbackTrack] == nil) {
                    [_actionArray addObject:@6];
                } else if ([(MP42AudioTrack *)object fallbackTrack]) {
                    [_actionArray addObject:@0];
                } else {
                    [_actionArray addObject:@([[[NSUserDefaults standardUserDefaults]
                                                valueForKey:@"SBAudioMixdown"] integerValue])];
                }
            }
            // DTS Specific actions
            else if (object.format == kMP42AudioCodecType_DTS &&
                     [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertDts"] boolValue]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepDts"] boolValue] &&
                    [(MP42AudioTrack *)object fallbackTrack] == nil) {
                    [_actionArray addObject:@6];
                } else if ([(MP42AudioTrack *)object fallbackTrack]) {
                    [_actionArray addObject:@0];
                } else {
                    [_actionArray addObject:@([[[NSUserDefaults standardUserDefaults]
                                                valueForKey:@"SBAudioMixdown"] integerValue])];
                }
            }
            // Vobsub
            else if (object.format == kMP42SubtitleCodecType_VobSub &&
                       [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue]) {
                [_actionArray addObject:@1];
            }
            // Generic actions
            else if (!trackNeedConversion(object.format)) {
                [_actionArray addObject:@0];
            }
            else if ([object isMemberOfClass:[MP42AudioTrack class]]) {
                [_actionArray addObject:@([[[NSUserDefaults standardUserDefaults]
                                                                 valueForKey:@"SBAudioMixdown"] integerValue])];
            }
            // Chapters
            else if ([object isMemberOfClass:[MP42ChapterTrack class]]) {
                [_actionArray addObject:@0];
            }
            else {
                [_actionArray addObject:@1];
            }
        }
        else {
            [_importCheckArray addObject:@YES];
            [_actionArray addObject:@0];
        }
    }

    if (_fileImporters.firstObject.metadata) {
        [importMetadata setEnabled:YES];
    }
    else {
        [importMetadata setEnabled:NO];
    }
}

- (void)windowDidLoad
{
	[self _prepareActionArray];
    [addTracksButton setEnabled:YES];
}

- (BOOL)onlyContainsSubtitleTracks
{
	BOOL onlySubtitle = YES;
    for (MP42Track *track in _tracks) {
        if ([track isKindOfClass:[MP42Track class]]) {
			if (![track isMemberOfClass:[MP42SubtitleTrack class]] || track.format != kMP42SubtitleCodecType_3GText)
				onlySubtitle = NO;
		}
    }
	return onlySubtitle;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)t
{
    return _tracks.count;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    if ([_tracks[row] isKindOfClass:[MP42Track class]]) {
        return NO;
    }

    return  YES;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    if ([_tracks[row] isKindOfClass:[MP42Track class]]) {
        return YES;
    }

    return  NO;
}

- (NSInteger)tableView:(NSTableView *)tableView
    spanForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row
{
    if ([_tracks[row] isKindOfClass:[MP42Track class]]) {
        return 1;
    }

    return 6;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    NSCell *cell = nil;
    MP42Track *track = _tracks[rowIndex];

    if ([track isKindOfClass:[MP42Track class]]) {
        if ([tableColumn.identifier isEqualToString:@"check"]) {
            NSButtonCell *buttonCell = [[NSButtonCell alloc] init];
            [buttonCell setButtonType:NSSwitchButton];
            buttonCell.controlSize = NSControlSizeSmall;
            buttonCell.title = @"";

            buttonCell.enabled = (isTrackMuxable(track.format) || trackNeedConversion(track.format)) ? YES : NO;

            return buttonCell;
        }

        if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
            NSPopUpButtonCell *actionCell = [[NSPopUpButtonCell alloc] init];
            [actionCell setAutoenablesItems:NO];
            actionCell.font = [NSFont systemFontOfSize:11];
            actionCell.controlSize = NSControlSizeSmall;
            [actionCell setBordered:NO];

            if ([track isMemberOfClass:[MP42VideoTrack class]]) {
                if ([track.URL.pathExtension caseInsensitiveCompare: @"264"] == NSOrderedSame ||
                    [track.URL.pathExtension caseInsensitiveCompare: @"h264"] == NSOrderedSame) {
                    NSInteger i = 0;
                    NSArray<NSString *> *formatArray = @[@"23.976", @"24", @"25", @"29.97", @"30", @"50", @"59.96", @"60"];
                    NSInteger tags[8] = {2398, 24, 25, 2997, 30, 50, 5994, 60};

                    for (NSString* format in formatArray) {
                        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""];
                        item.tag = tags[i++];
                        [item setEnabled:YES];
                        [actionCell.menu addItem:item];
                    }
                }
                else {
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Passthru", @"File Import action menu item.") action:NULL keyEquivalent:@""];
                    item.tag = 0;
                    [item setEnabled:YES];
                    [actionCell.menu addItem:item];

                    if (isTrackMuxable(track.format)) {
                        [item setEnabled:YES];
                    }
                    else {
                        [item setEnabled:NO];
                    }
                }
            }
            else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                NSInteger tag = 0;
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Passthru",  @"File Import action menu item.") action:NULL keyEquivalent:@""];
                item.tag = tag++;
                if (!trackNeedConversion(track.format)) {
                    [item setEnabled:YES];
                }
                else {
                    [item setEnabled:NO];
                }
                [actionCell.menu addItem:item];
                
                NSArray<NSString *> *formatArray = @[@"Tx3g"];
                for (NSString *format in formatArray) {
                    item = [[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""];
                    item.tag = tag++;
                    [item setEnabled:YES];
                    [actionCell.menu addItem:item];
                }
            }
            else if ([track isMemberOfClass:[MP42ClosedCaptionTrack class]]) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Passthru", @"File Import action menu item.") action:NULL keyEquivalent:@""];
                item.tag = 0;
                [item setEnabled:YES];
                [actionCell.menu addItem:item];
            }
            else if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                NSInteger tag = 0;
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Passthru", @"File Import action menu item.") action:NULL keyEquivalent:@""];
                item.tag = tag++;
                if (!trackNeedConversion(track.format))
                    [item setEnabled:YES];
                else
                    [item setEnabled:NO];
                [actionCell.menu addItem:item];
                
                NSArray *formatArray = @[@"AAC - Dolby Pro Logic II", @"AAC - Dolby Pro Logic", @"AAC - Stereo", @"AAC - Mono", @"AAC - Multi-channel"];
                for (NSString *format in formatArray) {
                    item = [[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""];
                    item.tag = tag++;
                    [item setEnabled:YES];
                    [actionCell.menu addItem:item];
                }

                if (track.format == kMP42AudioCodecType_AC3 ||
                    track.format == kMP42AudioCodecType_EnhancedAC3 ||
                    track.format == kMP42AudioCodecType_DTS)
                {
                    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"AAC + Passthru", @"File Import action menu item.") action:NULL keyEquivalent:@""];
                    item.tag = tag++;
                    [item setEnabled:YES];
                    [actionCell.menu addItem:item];
                }

            }
            else if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Passthru", @"File Import action menu item.") action:NULL keyEquivalent:@""];
                item.tag = 0;
                [item setEnabled:YES];
                [actionCell.menu addItem:item];
            }
            cell = actionCell;

            return cell;
        }
    }

    return tableColumn.dataCell;
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                row:(NSInteger)rowIndex
{
    id object = _tracks[rowIndex];

    if (!object) {
        return nil;
    }

    if ([object isKindOfClass:[MP42Track class]]) {
        MP42Track *track = object;

        if ([tableColumn.identifier isEqualToString: @"check"] ) {
            return _importCheckArray[rowIndex];
        }

        if ([tableColumn.identifier isEqualToString:@"trackId"]) {
            return [NSString stringWithFormat:@"%d", track.trackId];
        }

        if ([tableColumn.identifier isEqualToString:@"trackName"]) {
            return track.name;
        }

        if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
            return localizedDisplayName(track.mediaType, track.format);
        }

        if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {
            return track.timeString;
        }

        if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
            return [MP42Languages.defaultManager localizedLangForExtendedTag:track.language];
        }

        if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
            return _actionArray[rowIndex];
        }
    } else if ([tableColumn isEqual:tableView.tableColumns[1]]) {
            return object;
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString:@"check"]) {
        _importCheckArray[rowIndex] = anObject;
    }
    if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
        _actionArray[rowIndex] = anObject;
    }
}

- (BOOL)canBeChecked:(id)rowItem
{
    MP42Track *track = rowItem;
    if ([track isKindOfClass:[MP42Track class]] &&
        (isTrackMuxable(track.format) || trackNeedConversion(track.format))) {
        return YES;
    }
    return NO;
}

- (NSIndexSet *)targetRows
{
    NSIndexSet *selection = tracksTableView.selectedRowIndexes;
    NSInteger clickedRow = tracksTableView.clickedRow;

    if (clickedRow != -1 && ![selection containsIndex:clickedRow]) {
        selection = [NSIndexSet indexSetWithIndex:clickedRow];
    }

    return selection;
}

- (void)toggleSelectionCheck:(BOOL)value
{
    NSIndexSet *selection = [self targetRows];

    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if ([self canBeChecked:self->_tracks[idx]]) {
            self->_importCheckArray[idx] = @(value);
        }
    }];

    [tracksTableView reloadDataForRowIndexes:selection columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (IBAction)checkSelected:(id)sender
{
    [self toggleSelectionCheck:YES];
}

- (IBAction)uncheckSelected:(id)sender
{
    [self toggleSelectionCheck:NO];
}

- (IBAction)checkOnlyTracksWithSameLanguage:(id)sender
{
    NSIndexSet *selection = [self targetRows];
    NSMutableSet *languages = [NSMutableSet set];

    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if ([self canBeChecked:self->_tracks[idx]]) {
            MP42Track *track = self->_tracks[idx];
            [languages addObject:track.language];
        }
    }];

    NSUInteger idx = 0;
    for (MP42Track *track in _tracks) {
        if ([self canBeChecked:track] && [languages containsObject:track.language]) {
            self->_importCheckArray[idx] = @YES;
        }
        else {
            self->_importCheckArray[idx] = @NO;
        }
        idx++;
    }

    [tracksTableView reloadData];
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = anItem.action;

    if (action == @selector(uncheckSelected:) ||
        action == @selector(checkSelected:) ||
        action == @selector(checkOnlyTracksWithSameLanguage:))
        if (tracksTableView.selectedRow != -1 || tracksTableView.clickedRow != -1)
            return YES;

    return NO;
}

- (IBAction)closeWindow:(id)sender
{
    [tracksTableView setDelegate:nil];
    [tracksTableView setDataSource:nil];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)addTracks:(id)sender
{
    if (!_actionArray) { // if add tracks is called directly, need to prepare actions
        [self _prepareActionArray];
    }

    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i = 0;

    for (MP42Track *track in _tracks) {
        if ([track isKindOfClass:[MP42Track class]]) {
            if (_importCheckArray[i].boolValue) {
                NSUInteger conversion = _actionArray[i].integerValue;

                if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                    NSUInteger bitRate = [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioBitrate"] integerValue];
                    float drc = [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioDRC"] floatValue];

                    if (conversion == 6) {
                        MP42AudioTrack *audioTrack = (MP42AudioTrack *)track;
                        MP42AudioTrack *copy = [track copy];
                        MP42ConversionSettings *settings = [MP42AudioConversionSettings audioConversionWithBitRate:bitRate
                                                                                                           mixDown:SBDolbyPlIIMixdown
                                                                                                               drc:drc];
                        copy.conversionSettings = settings;

                        audioTrack.fallbackTrack = copy;
                        audioTrack.enabled = NO;

                        [tracks addObject:copy];
                    }
                    else if (conversion) {
                        NSString *mixdown = SBNoneMixdown;

                        switch (conversion) {
                            case 5:
                                mixdown = SBNoneMixdown;
                                break;
                            case 4:
                                mixdown = SBMonoMixdown;
                                break;
                            case 3:
                                mixdown = SBStereoMixdown;
                                break;
                            case 2:
                                mixdown = SBDolbyMixdown;
                                break;
                            case 1:
                            default:
                                mixdown = SBDolbyPlIIMixdown;
                                break;
                        }

                        MP42ConversionSettings *settings = [MP42AudioConversionSettings audioConversionWithBitRate:bitRate
                                                                                                           mixDown:mixdown
                                                                                                               drc:drc];
                        track.conversionSettings = settings;
                    }

                }
                else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                    if (conversion) {
                        MP42ConversionSettings *settings = [MP42ConversionSettings subtitlesConversion];
                        track.conversionSettings = settings;
                    }
                }
                else if ([track isMemberOfClass:[MP42VideoTrack class]]) {
                    if ([track.URL.pathExtension caseInsensitiveCompare:@"264"] == NSOrderedSame ||
                        [track.URL.pathExtension caseInsensitiveCompare:@"h264"] == NSOrderedSame) {
                        NSUInteger frameRate = 0;
                        switch(conversion) {
                            case 0:
                                frameRate = 2398;
                                break;
                            case 1:
                                frameRate = 24;
                                break;
                            case 2:
                                frameRate = 25;
                                break;
                            case 3:
                                frameRate = 2997;
                                break;
                            case 4:
                                frameRate = 30;
                                break;
                            case 5:
                                frameRate = 50;
                                break;
                            case 6:
                                frameRate = 5994;
                                break;
                            case 7:
                                frameRate = 60;
                                break;
                            default:
                                frameRate = 2398;
                                break;
                        }

                        track.conversionSettings = [MP42RawConversionSettings rawConversionWithFrameRate:frameRate];
                    }
                }

                [tracks addObject:track];
            }
        }
        i++;
    }

    MP42Metadata *metadata = nil;

    if (importMetadata.state) {
        metadata = _fileImporters.firstObject.metadata;
    }

    [_delegate importDoneWithTracks:tracks andMetadata:metadata];


    [tracksTableView setDelegate:nil];
    [tracksTableView setDataSource:nil];

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

@end
