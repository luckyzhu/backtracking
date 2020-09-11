//
//  NSObject+weakAssociatedPointer.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/3.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+weakAssociatedPointer.h"
#import <objc/runtime.h>

@implementation NSObject (weakAssociatedPointer)

-(void)setWeakAssociatedPointer:(id)weakAssociatedPointer {
    id __weak weakObject = weakAssociatedPointer;
    id (^block)(void) = ^{ return weakObject; };
    objc_setAssociatedObject(self, @selector(weakAssociatedPointer), block, OBJC_ASSOCIATION_COPY);
}

-(id)weakAssociatedPointer{
    id (^block)(void) = objc_getAssociatedObject(self, @selector(weakAssociatedPointer));
    return (block ? block() : nil);
}

@end
