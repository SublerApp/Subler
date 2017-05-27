//
//  SBRemoteImage.m
//  Subler
//
//  Created by Damiano Galassi on 27/05/17.
//
//

#import "SBRemoteImage.h"

@implementation SBRemoteImage

- (instancetype)initWithURL:(NSURL *)fullSizeURL thumbURL:(NSURL *)thumbURL providerName:(NSString *)providerName
{
    self = [super init];
    if (self)
    {
        _URL = fullSizeURL;
        _thumbURL = thumbURL;
        _providerName = providerName;
    }
    return self;
}

+ (instancetype)remoteImageWithURL:(NSURL *)fullSizeURL thumbURL:(NSURL *)thumbURL providerName:(NSString *)providerName
{
    return [[self alloc] initWithURL:fullSizeURL thumbURL:thumbURL providerName:providerName];
}

@end
