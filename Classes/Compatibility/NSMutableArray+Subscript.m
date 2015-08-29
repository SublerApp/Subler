//
//  NSMutableArray+Subscript.m
//  Subler
//

#import "NSMutableArray+Subscript.h"
#import <objc/runtime.h>

@implementation NSMutableArray (Subscript)

+ (void)load
{
    Class class = [self class];
    SEL swizzledSelector = @selector(dg_setObject:atIndexedSubscript:);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    class_addMethod([NSMutableArray class],
                    @selector(setObject:atIndexedSubscript:),
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod)
                    );
}

- (void)dg_setObject:(id)anObject atIndexedSubscript:(NSUInteger)index {
    if (anObject == nil) {
        [NSException raise:NSInvalidArgumentException format:@"setObject:atIndexedSubscript does not allow objects to be nil"];
    }
    if (index > self.count) {
        [NSException raise:NSRangeException format:@"setObject:atIndexedSubscript does not allow the index to be out of array bounds"];
    }
    if (index == self.count) {
        [self addObject:anObject];
    }
    else {
        [self replaceObjectAtIndex:index withObject:anObject];
    }
}

@end
