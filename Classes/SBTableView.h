//
//  SBTableView.h
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

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
    NSArray<NSString *> *_pasteboardTypes;
    NSInteger _defaultEditingColumn;
}
@property(nonatomic, readwrite, copy) NSArray<NSString *> *pasteboardTypes;
@property(nonatomic, readwrite) NSInteger defaultEditingColumn;
@end

NS_ASSUME_NONNULL_END
