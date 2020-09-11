//
//  NSObject+Weak.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/3.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+Weak.h"
#import <objc/runtime.h>

@implementation NSObject (Weak)
- (void)setObject:(id)object {
    id __weak weakObject = object;
    id (^block)(void) = ^{ return weakObject; };
    objc_setAssociatedObject(self, @selector(object), block, OBJC_ASSOCIATION_COPY);
}

- (id)object {
    id (^block)(void) = objc_getAssociatedObject(self, @selector(object));
    return (block ? block() : nil);
}

@end
