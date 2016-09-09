//
//  SBLogger.m
//  Subler
//
//  Created by Damiano Galassi on 26/10/14.
//
//

#import <Foundation/Foundation.h>
#import <MP42Foundation/MP42Logging.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBLogger : NSObject <MP42Logging>

@property (atomic, unsafe_unretained, readwrite, nullable) id <MP42Logging> delegate;

- (instancetype)initWithLogFile:(NSURL *)fileURL;
- (void)clearLog;

@end

NS_ASSUME_NONNULL_END
