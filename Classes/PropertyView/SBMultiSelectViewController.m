//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBMultiSelectViewController.h"

@implementation SBMultiSelectViewController {
    IBOutlet NSTextField *label;
}

- (void)loadView
{
    [super loadView];
    
    if (self.numberOfTracks == 1) {
        label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"1 track selected", nil)];
    } else {
        label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"%lu tracks selected", nil) , self.numberOfTracks];
    }
    
}

- (void)setNumberOfTracks:(NSUInteger) numberOfTracks
{
    _numberOfTracks = numberOfTracks;
}

@end
