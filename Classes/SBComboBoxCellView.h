//
//  SBComboBoxCellView.h
//  Subler
//
//  Created by Damiano Galassi on 11/10/2016.
//
//

#import <Cocoa/Cocoa.h>

@interface SBComboBoxCellView : NSTableCellView

@property (nonatomic, nullable, assign) IBOutlet NSComboBox *comboBox;

@end
