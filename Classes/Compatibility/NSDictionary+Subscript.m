//
//  NSDictionary+Subscript.m
//  Subler
//

#import "NSDictionary+Subscript.h"
#import <objc/runtime.h>

@implementation NSDictionary (Subscript)

+ (void)load {
    Class class = [self class];
    SEL swizzledSelector = @selector(dg_objectForKeyedSubscript:);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    class_addMethod([NSDictionary class],
                    @selector(objectForKeyedSubscript:),
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod)
                    );
}

-(id)dg_objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

@end
