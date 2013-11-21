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
        if ([self selectedRow] == -1)
            NSBeep();
        else
            [delegate _deleteSelectionFromTableView:self];
        return;
    }
    else if (key == 27) {
        [self deselectAll:self];
        return;
    }
    else
        [super keyDown:event];
}

- (IBAction)delete:(id)sender
{
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_deleteSelectionFromTableView:)])
        [(SBTableView *)[self delegate] _deleteSelectionFromTableView:self];
}

- (IBAction)copy:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_copySelectionFromTableView:)])
        [(SBTableView *)[self delegate] _copySelectionFromTableView:self];
}

- (IBAction)cut:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_cutSelectionFromTableView:)])
        [(SBTableView *)[self delegate] _cutSelectionFromTableView:self];
}

- (IBAction)paste:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(_pasteToTableView:)])
        [(SBTableView *)[self delegate] _pasteToTableView:self];
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
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_deleteSelectionFromTableView:)])
            return NO;

    if (action == @selector(copy:))
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_copySelectionFromTableView:)])
            return NO;

    if (action == @selector(cut:))
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_cutSelectionFromTableView:)])
            return NO;

    if (action == @selector(paste:))
        if (![self pasteboardHasSupportedType] || ![delegate respondsToSelector:@selector(_pasteToTableView:)])
            return NO;

    return YES;
}

- (void) dealloc
{
    [_pasteboardTypes release];
    [super dealloc];
}

@end
