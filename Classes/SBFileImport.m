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

@implementation SBFileImport

- (instancetype)initWithURLs:(NSArray<NSURL *> *)fileURLs delegate:(id <SBFileImportDelegate>)delegate error:(NSError **)error
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
                [importer release];
                [_tracks addObjectsFromArray:importer.tracks];
            }
        }

        if (!_tracks.count) {
            [self release];
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

    for (id object in _tracks) {
        if ([object isKindOfClass:[MP42Track class]]) {

            // Set the checkbox state
            if (isTrackMuxable([object format]) || trackNeedConversion([object format])) {
                [_importCheckArray addObject:@YES];
            } else {
                [_importCheckArray addObject:@NO];
            }

            // Set the action menu selection
            // AC-3 Specific actions
            if (([[object format] isEqualToString:MP42AudioFormatAC3] || [[object format] isEqualToString:MP42AudioFormatEAC3]) &&
                [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepAC3"] boolValue] &&
                    [object fallbackTrack] == nil) {
                    [_actionArray addObject:@6];
                } else if ([object fallbackTrack]) {
                    [_actionArray addObject:@0];
                } else {
                    [_actionArray addObject:@([[[NSUserDefaults standardUserDefaults]
                                                valueForKey:@"SBAudioMixdown"] integerValue])];
                }
            }
            // DTS Specific actions
            else if ([[object format] isEqualToString:MP42AudioFormatDTS] &&
                     [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertDts"] boolValue]) {
                if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioKeepDts"] boolValue] &&
                    [object fallbackTrack] == nil) {
                    [_actionArray addObject:@6];
                } else if ([object fallbackTrack]) {
                    [_actionArray addObject:@0];
                } else {
                    [_actionArray addObject:@([[[NSUserDefaults standardUserDefaults]
                                                valueForKey:@"SBAudioMixdown"] integerValue])];
                }
            }
            // Vobsub
            else if ([[object format] isEqualToString:MP42SubtitleFormatVobSub] &&
                       [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue]) {
                [_actionArray addObject:@1];
            }
            // Generic actions
            else if (!trackNeedConversion([object format])) {
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
    for (id track in _tracks) {
        if ([track isKindOfClass:[MP42Track class]]) {
			if (![track isMemberOfClass:[MP42SubtitleTrack class]] || ![[(MP42Track *)track format] isEqualToString:MP42SubtitleFormatTx3g])
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
            [buttonCell setControlSize:NSSmallControlSize];
            [buttonCell setTitle:@""];

            buttonCell.enabled = (isTrackMuxable(track.format) || trackNeedConversion(track.format)) ? YES : NO;

            return [buttonCell autorelease];
        }

        if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
            NSPopUpButtonCell *actionCell = [[NSPopUpButtonCell alloc] init];
            [actionCell setAutoenablesItems:NO];
            [actionCell setFont:[NSFont systemFontOfSize:11]];
            [actionCell setControlSize:NSSmallControlSize];
            [actionCell setBordered:NO];

            if ([track isMemberOfClass:[MP42VideoTrack class]]) {
                if ([[track.sourceURL pathExtension] caseInsensitiveCompare: @"264"] == NSOrderedSame ||
                    [[track.sourceURL pathExtension] caseInsensitiveCompare: @"h264"] == NSOrderedSame) {
                    NSInteger i = 0;
                    NSArray<NSString *> *formatArray = @[@"23.976", @"24", @"25", @"29.97", @"30", @"50", @"59.96", @"60"];
                    NSInteger tags[8] = {2398, 24, 25, 2997, 30, 50, 5994, 60};

                    for (NSString* format in formatArray) {
                        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                        [item setTag:tags[i++]];
                        [item setEnabled:YES];
                        [[actionCell menu] addItem:item];
                    }
                }
                else {
                    NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:0];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];

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
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                if (!trackNeedConversion(track.format)) {
                    [item setEnabled:YES];
                }
                else {
                    [item setEnabled:NO];
                }
                [[actionCell menu] addItem:item];
                
                NSArray<NSString *> *formatArray = @[MP42SubtitleFormatTx3g];
                for (NSString *format in formatArray) {
                    item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:tag++];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];
                }
            }
            else if ([track isMemberOfClass:[MP42ClosedCaptionTrack class]]) {
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:0];
                [item setEnabled:YES];
                [[actionCell menu] addItem:item];
            }
            else if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                NSInteger tag = 0;
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                if (!trackNeedConversion(track.format))
                    [item setEnabled:YES];
                else
                    [item setEnabled:NO];
                [[actionCell menu] addItem:item];
                
                NSArray *formatArray = @[@"AAC - Dolby Pro Logic II", @"AAC - Dolby Pro Logic", @"AAC - Stereo", @"AAC - Mono", @"AAC - Multi-channel"];
                for (NSString *format in formatArray) {
                    item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:tag++];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];
                }

                if ([track.format isEqualTo:MP42AudioFormatAC3] ||
                    [track.format isEqualTo:MP42AudioFormatEAC3] ||
                    [track.format isEqualTo:MP42AudioFormatDTS])
                {
                    item = [[[NSMenuItem alloc] initWithTitle:@"AAC + Passthru" action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:tag++];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];
                }

            }
            else if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:0];
                [item setEnabled:YES];
                [[actionCell menu] addItem:item];
            }
            cell = actionCell;

            return [cell autorelease];
        }
    }

    return [tableColumn dataCell];
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
        if( [tableColumn.identifier isEqualToString: @"check"] )
            return [_importCheckArray objectAtIndex:rowIndex];

        if ([tableColumn.identifier isEqualToString:@"trackId"])
            return [NSString stringWithFormat:@"%d", [object trackId]];

        if ([tableColumn.identifier isEqualToString:@"trackName"])
            return [object name];

        if ([tableColumn.identifier isEqualToString:@"trackInfo"])
            return [object format];

        if ([tableColumn.identifier isEqualToString:@"trackDuration"])
            return [object timeString];

        if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
            return [object language];

        if ([tableColumn.identifier isEqualToString:@"trackAction"])
            return [_actionArray objectAtIndex:rowIndex];
    } else if ([tableColumn isEqual:[[tableView tableColumns] objectAtIndex:1]]) {
            return object;
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"]) {
        [_importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
    }
    if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
        [_actionArray replaceObjectAtIndex:rowIndex withObject:anObject];
    }
}

- (void)toggleSelectionCheck:(BOOL)value
{
    NSIndexSet *selection = [tracksTableView selectedRowIndexes];
    NSInteger clickedRow = [tracksTableView clickedRow];

    if (clickedRow != -1 && ![selection containsIndex:clickedRow]) {
        selection = [NSIndexSet indexSetWithIndex:clickedRow];
    }

    [selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [_importCheckArray replaceObjectAtIndex:idx withObject:@(value)];
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

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];

    if (action == @selector(uncheckSelected:) || action == @selector(checkSelected:))
        if ([tracksTableView selectedRow] != -1 || [tracksTableView clickedRow] != -1)
            return YES;

    return NO;
}

- (IBAction)closeWindow:(id)sender
{
    [tracksTableView setDelegate:nil];
    [tracksTableView setDataSource:nil];
    [NSApp endSheet:[self window] returnCode:NSOKButton];
    [[self window] orderOut:self];
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
            if ([[_importCheckArray objectAtIndex: i] boolValue]) {
                NSUInteger conversion = [[_actionArray objectAtIndex:i] integerValue];

                if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                    if (conversion == 6) {
                        MP42AudioTrack *copy = [track copy];
                        [copy setNeedConversion:YES];
                        [copy setMixdownType:SBDolbyPlIIMixdown];

                        [(MP42AudioTrack *)track setFallbackTrack:copy];

                        [tracks addObject:copy];
                        [copy release];
                    } else if (conversion) {
                        [track setNeedConversion:YES];
                    }

                    switch (conversion) {
                        case 6:
                            [track setEnabled:NO];
                            break;
                        case 5:
                            [(MP42AudioTrack *)track setMixdownType:nil];
                            break;
                        case 4:
                            [(MP42AudioTrack *)track setMixdownType:SBMonoMixdown];
                            break;
                        case 3:
                            [(MP42AudioTrack *)track setMixdownType:SBStereoMixdown];
                            break;
                        case 2:
                            [(MP42AudioTrack *)track setMixdownType:SBDolbyMixdown];
                            break;
                        case 1:
                        default:
                            [(MP42AudioTrack *)track setMixdownType:SBDolbyPlIIMixdown];
                            break;
                    }
                } else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                    if (conversion) {
                        [track setNeedConversion:YES];
                    }
                } else if ([track isMemberOfClass:[MP42VideoTrack class]]) {
                    if ([[track.sourceURL pathExtension] caseInsensitiveCompare:@"264"] == NSOrderedSame ||
                        [[track.sourceURL pathExtension] caseInsensitiveCompare:@"h264"] == NSOrderedSame) {
                        switch(conversion) {
                            case 0:
                                track.trackId = 2398;
                                break;
                            case 1:
                                track.trackId = 24;
                                break;
                            case 2:
                                track.trackId = 25;
                                break;
                            case 3:
                                track.trackId = 2997;
                                break;
                            case 4:
                                track.trackId = 30;
                                break;
                            case 5:
                                track.trackId = 50;
                                break;
                            case 6:
                                track.trackId = 5994;
                                break;
                            case 7:
                                track.trackId = 60;
                                break;
                            default:
                                track.trackId = 2398;
                                break;
                        }
                    }
                }

                [tracks addObject:track];
            }
        }
        i++;
    }

    MP42Metadata *metadata = nil;

    if ([importMetadata state]) {
        metadata = [[[[_fileImporters firstObject] metadata] retain] autorelease];
    }

    [_delegate importDoneWithTracks:tracks andMetadata: metadata];

    [tracks release];

    [tracksTableView setDelegate:nil];
    [tracksTableView setDataSource:nil];

    [NSApp endSheet:[self window] returnCode:NSOKButton];
}

- (void)dealloc
{
    [_fileURLs release];
    [_fileImporters release];
    [_tracks release];

    [_importCheckArray release];
    [_actionArray release];

    [super dealloc];
}

@end
