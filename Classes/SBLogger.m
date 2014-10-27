//
//  SBLogger.m
//  Subler
//
//  Created by Damiano Galassi on 26/10/14.
//
//

#import <Foundation/Foundation.h>
#import "SBLogger.h"

@interface SBLogger ()

@property (readonly) NSURL *fileURL;

@end

@implementation SBLogger

@synthesize fileURL = _fileURL;
@synthesize delegate = _delegate;

- (instancetype)initWithLogFile:(NSURL *)fileURL {
    self = [self init];

    if (self) {
        _fileURL = [fileURL copy];
    }

    return self;
}

- (NSString *)currentTime {
    time_t _now = time(NULL);
    struct tm *now  = localtime(&_now);
    char time[512];

    snprintf(time, sizeof(time), "[%02d:%02d:%02d]", now->tm_hour, now->tm_min, now->tm_sec);

    return [NSString stringWithUTF8String:time];
}

- (void)writeToLog:(NSString *)string {
    if (self.fileURL) {
        FILE *f = fopen([self.fileURL fileSystemRepresentation], "a");
        fprintf(f, "%s %s", [[self currentTime] UTF8String], [string UTF8String]);
        fclose(f);
    }

    if (self.delegate) {
        [self.delegate writeToLog:[NSString stringWithFormat:@"%@ %@", [self currentTime], string]];
    }
}

- (void)clearLog {
    if (self.fileURL) {
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
    }
}

- (void)dealloc {
    [_fileURL release];
    _fileURL = nil;

    _delegate = nil;

    [super dealloc];
}

@end
