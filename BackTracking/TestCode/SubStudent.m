//
//  SubStudent.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/27.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "SubStudent.h"
#import <objc/runtime.h>

@implementation SubStudent
- (void)eat{
    NSLog(@"SubStudent的eat方法----");
}

- (void)run {
    NSLog(@"SubStudent的run方法----");
}

- (void)testSubStu {
    NSLog(@"SubStudent的testSubStu方法----");

}

-(void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, @selector(name), name, OBJC_ASSOCIATION_ASSIGN);
}

-(NSString *)name {
    return objc_getAssociatedObject(self, @selector(name));
}

-(void)setWeakName:(id)weakName {
    id __weak weakObject = weakName;
    id (^block)(void) = ^{ return weakObject; };
    objc_setAssociatedObject(self, @selector(weakName), block, OBJC_ASSOCIATION_COPY);
}

-(id)weakName{
    id (^block)(void) = objc_getAssociatedObject(self, @selector(weakName));
    return (block ? block() : nil);
}

@end
