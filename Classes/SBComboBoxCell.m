//
//  SBComboBoxCell.m
//  Subler
//
//  Created by Damiano Galassi on 10/11/16.
//
//

#import "SBComboBoxCell.h"

@interface SBComboBoxCell ()

@property (nonatomic) NSBackgroundStyle SB_originalBackgroundStyle;

@end

@implementation SBComboBoxCell

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    if (backgroundStyle == NSBackgroundStyleDark) {
        self.textColor = [NSColor controlHighlightColor];
    }
    else {
        self.textColor = [NSColor controlTextColor];
    }
}

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj;
{
    self.SB_originalBackgroundStyle = self.backgroundStyle;

    self.backgroundStyle = NSBackgroundStyleLight;
    self.drawsBackground = YES;

    return [super setUpFieldEditorAttributes:textObj];
}

- (void)endEditing:(NSText *)textObj
{
    [super endEditing:textObj];
    self.drawsBackground = NO;
    self.backgroundStyle = self.SB_originalBackgroundStyle;
}

@end
