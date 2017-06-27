//
//  SBRemoteImage.h
//  Subler
//
//  Created by Damiano Galassi on 27/05/17.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SBRemoteImage : NSObject

+ (instancetype)remoteImageWithURL:(NSURL *)fullSizeURL thumbURL:(NSURL *)thumbURL providerName:(NSString *)providerName;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSURL *thumbURL;
@property (nonatomic, readonly) NSString *providerName;

@end

NS_ASSUME_NONNULL_END
