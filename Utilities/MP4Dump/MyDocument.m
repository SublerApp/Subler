//
//  MyDocument.m
//  MP4Dump
//
//  Created by Damiano Galassi on 27/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
#include "mp4v2.h"

extern NSString *libraryPath;

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers,
    // you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"LogLevel"])
        [logLevelButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"LogLevel"]];
    [super windowControllerDidLoadNib:aController];
    [textView setFont:[NSFont fontWithName:@"Monaco" size:10]];
    [textView setString:@""];
    [textView insertText:result];
    [textView setContinuousSpellCheckingEnabled:NO];
}

- (BOOL) loadFileDump:(NSURL *)absoluteURL error:(NSError **)outError
{
    MP4FileHandle fileHandle = MP4Read([[absoluteURL path] UTF8String]);

    MP4Dump(fileHandle, 0);

    MP4Close(fileHandle, 0);
    result = [NSString stringWithContentsOfFile:libraryPath encoding:NSASCIIStringEncoding error:outError];

    if([[NSFileManager defaultManager] isDeletableFileAtPath:libraryPath])
        [[NSFileManager defaultManager] removeItemAtPath:libraryPath error:nil];

    if (result)
        return YES;
    else
        return NO;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ( outError != NULL && ![self loadFileDump:absoluteURL error:outError]) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];

        return NO;
	}

    if([[NSFileManager defaultManager] isDeletableFileAtPath:libraryPath])
        [[NSFileManager defaultManager] removeItemAtPath:libraryPath error:nil];

    return YES;
}

- (IBAction) setLogLevel: (id) sender
{
    NSInteger level = [sender tag];
    [[NSUserDefaults standardUserDefaults] setInteger:level forKey:@"LogLevel"];
    MP4LogSetLevel(level);

    if ([self loadFileDump:[self fileURL] error:nil]) {
        [textView setString:@""]; 
        [textView insertText:result];
    }
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
}

@end
