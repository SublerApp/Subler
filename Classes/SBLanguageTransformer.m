//
//  SBLanguageTransformer.m
//  Subler
//
//  Created by Damiano Galassi on 30/11/16.
//
//

#import "SBLanguageTransformer.h"
#import <MP42Foundation/MP42Languages.h>

@interface SBLanguageTransformer ()

@property (nonatomic, readonly) MP42Languages *langManager;

@end

@implementation SBLanguageTransformer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _langManager = MP42Languages.defaultManager;
    }
    return self;
}

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    return [self.langManager localizedLangForExtendedTag:value];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)reverseTransformedValue:(id)value
{
    return [self.langManager extendedTagForLocalizedLang:value];
}

@end
