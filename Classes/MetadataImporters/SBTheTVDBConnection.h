//
//  SBTheTVDBConnection.h
//  Subler
//
//  Created by Damiano Galassi on 24/05/17.
//
//

#import <Foundation/Foundation.h>

@interface SBTheTVDBConnection : NSObject

@property (class, readonly) SBTheTVDBConnection *defaultManager;

@property (nonatomic, readonly) NSArray<NSString *> *languagues;

- (NSData *)requestData:(NSURL *)url language:(NSString *)language;

@end
