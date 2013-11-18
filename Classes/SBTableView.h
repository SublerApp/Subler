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
@end

@interface SBTableView : NSTableView<SBTableViewDelegate> {
    NSArray *_pasteboardTypes;
}
- (void)keyDown:(NSEvent *)event;
@property(readwrite, retain) NSArray* _pasteboardTypes;
@end

