//
//  NSArray+Subscripting.m
//  Subler
//

#import "NSArray+Subscripting.h"
#import <objc/runtime.h>

@implementation NSArray (Subscripting)

+ (void)load
{
    Class class = [self class];
    SEL swizzledSelector = @selector(dg_objectAtIndexedSubscript:);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    class_addMethod([NSArray class],
                @selector(objectAtIndexedSubscript:),
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
                );
}

- (id)dg_objectAtIndexedSubscript:(NSInteger)index {
    return [self objectAtIndex:index];
}

@end
