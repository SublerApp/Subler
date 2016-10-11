//
//  SBComboBoxCellView.m
//  Subler
//
//  Created by Damiano Galassi on 11/10/2016.
//
//

#import "SBComboBoxCellView.h"

@implementation SBComboBoxCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    if (backgroundStyle == NSBackgroundStyleDark) {
        self.comboBox.textColor = [NSColor controlHighlightColor];
    }
    else {
        self.comboBox.textColor = [NSColor controlTextColor];
    }
}

@end
