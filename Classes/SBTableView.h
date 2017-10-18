//
//  SBTableView.h
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SBTableViewDelegate <NSTableViewDelegate>
@optional
- (void)_deleteSelectionFromTableView:(NSTableView *)tableView;
- (void)_copySelectionFromTableView:(NSTableView *)tableView;
- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
- (void)_pasteToTableView:(NSTableView *)tableView;

@end

@interface SBTableView : NSTableView

@property (nonatomic, readwrite, copy) NSArray<NSString *> *pasteboardTypes;
@property (nonatomic, readwrite) NSInteger defaultEditingColumn;

@property (nonatomic, readonly, copy) NSIndexSet *targetedRowIndexes;


@end

NS_ASSUME_NONNULL_END
