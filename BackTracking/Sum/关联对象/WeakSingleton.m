//
//  WeakSingleton.m
//  BackTracking
//
//  Created by NewBoy on 2020/9/4.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "WeakSingleton.h"

@implementation WeakSingleton
+ (instancetype)sharedWeakInstance {
    static __weak id weakObj = nil;
    id strongObj = weakObj;
    @synchronized (self) {
        if (!strongObj) {
            strongObj = [[self class] new];
            weakObj = strongObj;
        }
    }
    return strongObj;
}
@end
