//
//  AppDelegate.m
//  MP4Dump
//
//  Created by Damiano Galassi on 17/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#include "mp4v2.h"

NSString *libraryPath = nil;

static void logCallback(MP4LogLevel loglevel, const char *fmt, va_list ap)
{
    if (!libraryPath) {
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                   NSUserDomainMask,
                                                                   YES).firstObject;
        NSString *AppSupportDirectory = [[libraryDir stringByAppendingPathComponent:@"Application Support"]
                                          stringByAppendingPathComponent:@"MP4Dump"];

        if (![NSFileManager.defaultManager fileExistsAtPath:AppSupportDirectory]) {
            [NSFileManager.defaultManager createDirectoryAtPath:AppSupportDirectory
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:NULL];
        }
        libraryPath = [AppSupportDirectory stringByAppendingPathComponent:@"temp.txt"];
        
    }

    FILE *file = fopen(libraryPath.fileSystemRepresentation, "a");

    vfprintf(file, fmt, ap);
    fprintf(file, "\n");

    fclose(file);
}

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    MP4SetLogCallback(logCallback);
    MP4LogSetLevel(MP4_LOG_INFO);
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"MP42LogLevel" : @3}];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

@end
