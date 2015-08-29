//
//  NSMutableDictionary+Subscript.m
//  Subler
//

#import "NSMutableDictionary+Subscript.h"
#import <objc/runtime.h>

@implementation NSMutableDictionary (Subscript)

+ (void)load {
    Class class = [self class];
    SEL swizzledSelector = @selector(dg_setObject:forKeyedSubscript:);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    class_addMethod([NSMutableDictionary class],
                    @selector(setObject:forKeyedSubscript:),
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod)
                    );
}

- (void)dg_setObject:(id)object forKeyedSubscript:(id < NSCopying >)aKey {
    [self setObject:object forKey:aKey];
}

@end
