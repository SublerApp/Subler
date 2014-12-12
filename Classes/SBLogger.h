//
//  SBLogger.m
//  Subler
//
//  Created by Damiano Galassi on 26/10/14.
//
//

#import <Foundation/Foundation.h>
#import <MP42Foundation/MP42Logging.h>

@interface SBLogger : NSObject <MP42Logging> {
    NSURL *_fileURL;
    id <MP42Logging> _delegate;
}

@property (assign, readwrite) id <MP42Logging> delegate;

- (instancetype)initWithLogFile:(NSURL *)fileURL;

- (void)clearLog;

@end
