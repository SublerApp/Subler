//
//  SBMetadataDefaultSet.m
//  Subler
//
//  Created by Damiano Galassi on 28/07/2016.
//
//

#import "SBMetadataDefaultItem.h"

@implementation SBMetadataDefaultItem

- (instancetype)initWithKey:(NSString *)key value:(NSArray *)value
{
    self = [super init];
    if (self) {
        _key = [key copy];
        _value = [value copy];
    }
    return self;
}

+ (instancetype)itemWithKey:(NSString *)key value:(NSArray *)value
{
    return [[self alloc] initWithKey:key value:value];
}

@end
