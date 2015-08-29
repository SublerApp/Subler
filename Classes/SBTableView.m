//
//  SBTableView.m
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBTableView.h"


@implementation SBTableView

@synthesize defaultEditingColumn = _defaultEditingColumn;
@synthesize pasteboardTypes = _pasteboardTypes;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _pasteboardTypes = [@[] retain];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _pasteboardTypes = [@[] retain];
    }
    return self;
}

- (void)keyDown:(NSEvent *)event
{
    id delegate = [self delegate];

    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    if ((key == NSEnterCharacter || key == NSCarriageReturnCharacter) &&
        _defaultEditingColumn > 0) {
        [self editColumn:_defaultEditingColumn row:[self selectedRow] withEvent:nil select:YES];
        [self editColumn:1 row:[self selectedRow] withEvent:nil select:YES];
    } else if ((key == NSDeleteCharacter || key == NSDeleteFunctionKey) &&
               [delegate respondsToSelector:@selector(_deleteSelectionFromTableView:)]) {
        if ([self selectedRow] == -1) {
            NSBeep();
        } else {
            [delegate _deleteSelectionFromTableView:self];
        }
        return;
    } else if (key == 27 && [self selectedRow] != -1) {
        [self deselectAll:self];
    } else {
        [super keyDown:event];
    }
}

- (IBAction)delete:(id)sender
{
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_deleteSelectionFromTableView:)])
        [(id <SBTableViewDelegate>)[self delegate] _deleteSelectionFromTableView:self];
}

- (IBAction)copy:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_copySelectionFromTableView:)])
        [(id <SBTableViewDelegate>)[self delegate] _copySelectionFromTableView:self];
}

- (IBAction)cut:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_cutSelectionFromTableView:)])
        [(id <SBTableViewDelegate>)[self delegate] _cutSelectionFromTableView:self];
}

- (IBAction)paste:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(_pasteToTableView:)])
        [(id <SBTableViewDelegate>)[self delegate] _pasteToTableView:self];
}

- (BOOL)pasteboardHasSupportedType {
    // has the pasteboard got a type we support?
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *bestType = [pb availableTypeFromArray:_pasteboardTypes];
    return (bestType != nil);
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    id delegate = [self delegate];
    SEL action = [item action];

    if (action == @selector(delete:))
        if ([self selectedRow] == -1 ||
            ![delegate respondsToSelector:@selector(_deleteSelectionFromTableView:)])
            return NO;

    if (action == @selector(copy:))
        if ([self selectedRow] == -1 ||
            ![delegate respondsToSelector:@selector(_copySelectionFromTableView:)])
            return NO;

    if (action == @selector(cut:))
        if ([self selectedRow] == -1 ||
            ![delegate respondsToSelector:@selector(_cutSelectionFromTableView:)])
            return NO;

    if (action == @selector(paste:))
        if (![self pasteboardHasSupportedType] ||
            ![delegate respondsToSelector:@selector(_pasteToTableView:)])
            return NO;

    return YES;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row
{
    if (![[self delegate] respondsToSelector:@selector(tableView:spanForTableColumn:row:)]) {
        return [super frameOfCellAtColumn:column row:row];
    }

    NSInteger colspan = [(id <SBTableViewDelegate>)[self delegate]
               tableView:self
               spanForTableColumn:
               [[self tableColumns] objectAtIndex:column]
               row:row];
    if (colspan == 0) {
        return NSZeroRect;
    }
    if (colspan == 1) {
        return [super frameOfCellAtColumn:column row:row];
    } else {
        // 2 or more, it's responsibility of delegate to provide reasonable number
        NSRect merged = [super frameOfCellAtColumn:column row:row];
        // start out with this one
        for (NSInteger i = 1; i < colspan; i++ ) {
            // start from next one
            NSRect next = [super frameOfCellAtColumn:column+i row:row];
            merged = NSUnionRect(merged,next);
        }
        return merged;
    }
}

- (void)drawRow:(NSInteger)inRow clipRect:(NSRect)inClipRect
{
    NSRect newClipRect = inClipRect;

    if ([[self delegate] respondsToSelector:@selector(tableView:spanForTableColumn:row:)]) {
        NSInteger colspan = 0;
        NSInteger firstCol = [[self columnIndexesInRect:inClipRect] firstIndex];
        // Does the FIRST one of these have a zero-colspan? If so, extend range.
        while (colspan == 0) {
            colspan = [(id <SBTableViewDelegate>)[self delegate]
                       tableView:self
                       spanForTableColumn:[[self tableColumns] objectAtIndex:firstCol]
                       row:inRow];
            if (colspan == 0) {
                firstCol--;
                newClipRect = NSUnionRect(newClipRect, [self frameOfCellAtColumn:firstCol row:inRow]);
            }
        }
    }

    [super drawRow:inRow clipRect:newClipRect];
}

- (void)dealloc
{
    [_pasteboardTypes release];
    _pasteboardTypes = nil;

    [super dealloc];
}

@end
