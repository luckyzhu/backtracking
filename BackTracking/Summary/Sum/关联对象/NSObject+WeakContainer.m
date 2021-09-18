//
//  NSObject+WeakContainer.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/4.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+WeakContainer.h"
#import <objc/runtime.h>

static NSPointerArray *gPointerArray = nil;

@implementation NSObject (WeakContainer)

- (id)weakObjInPointerArray {
    if (!gPointerArray) return nil;
    // Removes NULL values from the receiver.(sometimes doesn't work as documented)
    [gPointerArray compact];
    for (id obj in gPointerArray) {
        if (obj != NULL) {
            return objc_getAssociatedObject(self, @selector(weakObjInPointerArray));
        }
    }
    gPointerArray = nil;
    return nil;
}

- (void)setWeakObjInPointerArray:(id)weakObj {
    if (weakObj) {
        if (!gPointerArray) gPointerArray = [NSPointerArray weakObjectsPointerArray];
        [gPointerArray addPointer:(__bridge void *)weakObj];
        objc_setAssociatedObject(self, @selector(weakObjInPointerArray), weakObj, OBJC_ASSOCIATION_ASSIGN);
    }
}
@end
