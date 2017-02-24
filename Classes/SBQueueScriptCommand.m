//
//  SBQueueScriptCommand.m
//  Subler
//
//  Created by Damiano Galassi on 02/02/17.
//
//

#import "SBQueueScriptCommand.h"
#import "SBQueueController.h"

@implementation SBQueueScriptCommand

- (id)performDefaultImplementation
{
    NSArray<NSURL *> *args = [self directParameter];

    [SBQueueController.sharedManager addItemsFromURLs:args atIndex:0];

    return nil;
}

@end

@implementation SBQueueStartScriptCommand

- (id)performDefaultImplementation
{
    [SBQueueController.sharedManager start:self];
    [self suspendExecution];
    return nil;
}

@end

@implementation SBQueueStopScriptCommand

- (id)performDefaultImplementation
{
    [SBQueueController.sharedManager stop:self];
    return nil;
}

@end
