//
//  NSArray+svideo.m
//  BackTracking
//
//  Created by luxizhu on 2021/11/3.
//  Copyright © 2021 newboy. All rights reserved.
//

#import "NSArray+svideo.h"

@implementation NSArray (svideo)
- (NSArray *)uniqueMembers
{
    NSSet *set = [NSSet setWithArray:self];
    if (set.count == 0) {
        return [NSArray array];
    }
    
    NSMutableArray *finalArray = [NSMutableArray array];
    if (set.allObjects.count > 0) {
        [finalArray addObjectsFromArray:set.allObjects];
    }
    return [finalArray copy];
}
@end
