//
//  SBView.m
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBView.h"

@implementation SBView

- (void)setViewController:(NSViewController *)newController
{
    if (viewController)
    {
        NSResponder *controllerNextResponder = viewController.nextResponder;
        super.nextResponder = controllerNextResponder;
        [viewController setNextResponder:nil];
    }
    
    viewController = newController;
    
    if (newController)
    {
        NSResponder *ownNextResponder = self.nextResponder;
        super.nextResponder = viewController;
        viewController.nextResponder = ownNextResponder;
    }
}

- (void)setNextResponder:(NSResponder *)newNextResponder
{
    if (viewController)
    {
        viewController.nextResponder = newNextResponder;
        return;
    }
    
    super.nextResponder = newNextResponder;
}

@end
