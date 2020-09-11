//
//  NSObject+Default.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/3.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+Default.h"
#import <objc/runtime.h>

@implementation NSObject (Default)
- (void)setStrongObj:(id)strongObj {
    objc_setAssociatedObject(self, @selector(strongObj), strongObj, OBJC_ASSOCIATION_ASSIGN);
}

- (id)strongObj {
    return objc_getAssociatedObject(self, @selector(strongObj));
}
@end
