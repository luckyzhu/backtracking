//
//  NSObject+weakTwo.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/4.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+weakTwo.h"
#import <objc/runtime.h>
#import "WeakAssociatedObjectWrapper.h"


@implementation NSObject (weakTwo)
-(void)setWeakObj:(id)weakObj{
    WeakAssociatedObjectWrapper *wrapper = [WeakAssociatedObjectWrapper new];
    wrapper.object = weakObj;
    objc_setAssociatedObject(self, @selector(weakObj), wrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(id)weakObj{
    WeakAssociatedObjectWrapper *wrapper = objc_getAssociatedObject(self, _cmd);
    return wrapper.object;
}
@end
