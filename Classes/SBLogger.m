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

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation SBLogger

- (instancetype)initWithLogFile:(NSURL *)fileURL {
    self = [self init];

    if (self) {
        _fileURL = [fileURL copy];
        _queue = dispatch_queue_create("org.subler.LogQueue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (NSString *)currentTime {
    time_t _now = time(NULL);
    struct tm *now  = localtime(&_now);
    char time[512];

    snprintf(time, sizeof(time), "[%02d:%02d:%02d]", now->tm_hour, now->tm_min, now->tm_sec);

    return @(time);
}

- (void)writeToLog:(NSString *)string {
    dispatch_sync(self.queue, ^{
        if (self.fileURL) {
            FILE *f = fopen(self.fileURL.fileSystemRepresentation, "a");
            if (f) {
                fprintf(f, "%s %s", [self currentTime].UTF8String, string.UTF8String);
                fprintf(f, "\n");
                fclose(f);
            }
        }

        if (self.delegate) {
            [self.delegate writeToLog:[NSString stringWithFormat:@"%@ %@", [self currentTime], string]];
            [self.delegate writeToLog:@"\n"];
        }
    });
}

- (void)writeErrorToLog:(NSError *)error {
    if (error.localizedDescription) {
        [self writeToLog:error.localizedDescription];
    }
    if (error.localizedRecoverySuggestion) {
        [self writeToLog:error.localizedRecoverySuggestion];
    }
}

- (void)clearLog {
    if (self.fileURL) {
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
    }
}

- (void)dealloc {
    _delegate = nil;
}

@end
