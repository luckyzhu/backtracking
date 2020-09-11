//
//  LXTestObj.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/24.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "LXTestObj.h"

@implementation LXTestObj
-(NSMutableArray *)testArray {
    if (_testArray == nil) {
        _testArray = [NSMutableArray array];
    }
    return _testArray;
}
@end
