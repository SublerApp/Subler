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

void logCallback(MP4LogLevel loglevel, const char* fmt, va_list ap)
{
    if (!libraryPath) {
        NSString * libraryDir = [NSSearchPathForDirectoriesInDomains( NSLibraryDirectory,
                                                                     NSUserDomainMask,
                                                                     YES ) objectAtIndex:0];
        NSString * AppSupportDirectory = [[libraryDir stringByAppendingPathComponent:@"Application Support"]
                                          stringByAppendingPathComponent:@"MP4Dump"];
        if( ![[NSFileManager defaultManager] fileExistsAtPath:AppSupportDirectory] )
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:AppSupportDirectory
                                                       attributes:nil];
        }
        libraryPath = [[AppSupportDirectory stringByAppendingPathComponent:@"temp.txt"] retain];
        
    }

    FILE * file = fopen([libraryPath UTF8String], "a");

    vfprintf(file, fmt, ap);
    fprintf(file, "\n");

    fclose(file);

}

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    MP4LogSetLevel(MP4_LOG_INFO);
    MP4SetLogCallback(logCallback);
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

@end
