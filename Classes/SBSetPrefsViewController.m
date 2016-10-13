//
//  SBSetPrefsViewController.m
//  Subler
//
//  Created by Damiano Galassi on 12/10/2016.
//
//

#import "SBSetPrefsViewController.h"

#import "SBPresetManager.h"
#import "SBMovieViewController.h"
#import <MP42Foundation/MP42Metadata.h>

@interface SBSetPrefsViewController () <NSTableViewDataSource>

@property (nonatomic, readwrite) NSPopover *popover;
@property (nonatomic, readwrite) NSInteger currentRow;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSButton *removeSetButton;

@property (nonatomic, readwrite) SBMovieViewController *controller;

@end

@implementation SBSetPrefsViewController

- (NSString *)nibName
{
    return @"SBSetPrefsViewController";
}

- (void)loadView
{
    [super loadView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTableView:)
                                                 name:@"SBPresetManagerUpdatedNotification" object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Sets

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [SBPresetManager sharedManager].presets.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *cell = nil;

    if ([tableColumn.identifier isEqualToString:@"name"]) {
        cell = [tableView makeViewWithIdentifier:@"nameCell" owner:self];
        cell.textField.stringValue = [SBPresetManager sharedManager].presets[row].presetName;
    }
    else {
        cell = [tableView makeViewWithIdentifier:@"infoCell" owner:self];
    }

    return cell;
}

- (IBAction)deletePreset:(id)sender
{
    [self closePopOver:self];

    NSInteger rowIndex = self.tableView.selectedRow;
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager removePresetAtIndex:rowIndex];
}

- (IBAction)closePopOver:(id)sender
{
    if (self.popover) {
        [self.popover close];

        self.popover = nil;
        self.controller = nil;
    }
}

- (IBAction)toggleInfoWindow:(id)sender
{
    NSInteger row = [self.tableView rowForView:sender];
    if (self.currentRow == row && _popover) {
        [self closePopOver:sender];
    }
    else {
        self.currentRow = row;
        [self closePopOver:sender];

        self.controller = [[SBMovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [self.controller setMetadata:[SBPresetManager sharedManager].presets[_currentRow]];

        self.popover = [[NSPopover alloc] init];
        self.popover.contentViewController = _controller;
        self.popover.contentSize = NSMakeSize(480.0f, 500.0f);

        [self.popover showRelativeToRect:[sender frame] ofView:sender preferredEdge:NSMaxYEdge];
    }
}

- (void)updateTableView:(id)sender
{
    [self.tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (self.tableView.selectedRow != -1) {
        self.removeSetButton.enabled = YES;
    }
    else {
        self.removeSetButton.enabled = NO;
    }
}

@end
