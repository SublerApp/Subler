//
//  SBTableView.h
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SBTableViewDelegate
@optional
- (void)_deleteSelectionFromTableView:(NSTableView *)tableView;
- (void)_copySelectionFromTableView:(NSTableView *)tableView;
- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
- (void)_pasteToTableView:(NSTableView *)tableView;

- (NSInteger)tableView:(NSTableView *)tableView
    spanForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row;
@end

@interface SBTableView : NSTableView {
    NSArray *_pasteboardTypes;
    NSInteger _defaultEditingColumn;
}
- (void)keyDown:(NSEvent *)event;
@property(readwrite, retain) NSArray *pasteboardTypes;
@property(readwrite) NSInteger defaultEditingColumn;
@end

