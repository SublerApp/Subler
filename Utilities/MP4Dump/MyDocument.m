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

- (instancetype)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"LogLevel"]) {
        [logLevelButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"LogLevel"]];
    }

    [self _resetTextView];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:result];
    [textView.textStorage appendAttributedString:attributedString];
}

- (void)_resetTextView
{
    textView.font = [NSFont fontWithName:@"Monaco" size:10];
    textView.string = @"";
    [textView setContinuousSpellCheckingEnabled:NO];
}

- (BOOL)_loadFileDump:(NSURL *)absoluteURL error:(NSError **)outError
{
    MP4FileHandle fileHandle = MP4Read(absoluteURL.fileSystemRepresentation);

    MP4Dump(fileHandle, 0);

    MP4Close(fileHandle, 0);
    result = [NSString stringWithContentsOfFile:libraryPath encoding:NSASCIIStringEncoding error:outError];

    if ([[NSFileManager defaultManager] isDeletableFileAtPath:libraryPath])
        [[NSFileManager defaultManager] removeItemAtPath:libraryPath error:nil];

    if (result) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if (outError != NULL && ![self _loadFileDump:absoluteURL error:outError]) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];

        return NO;
	}

    if ([[NSFileManager defaultManager] isDeletableFileAtPath:libraryPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:libraryPath error:nil];
    }

    return YES;
}

- (IBAction)setLogLevel:(id)sender
{
    MP4LogLevel level = (MP4LogLevel)[sender tag];
    [[NSUserDefaults standardUserDefaults] setInteger:level forKey:@"LogLevel"];
    MP4LogSetLevel(level);

    if ([self _loadFileDump:self.fileURL error:nil]) {
        [self _resetTextView];
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:result];
        [textView.textStorage appendAttributedString:attributedString];
    }
}

@end
