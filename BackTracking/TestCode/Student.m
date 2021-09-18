//
//  Student.m
//  BackTracking
//
//  Created by ZhuLuxi on 2020/7/1.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "Student.h"

@implementation Student

- (void)studentTestMethod {
    
    NSLog(@"调用student的studentTestMethod");
}

-(void)dealloc {

    NSLog(@"Student释放了----");
}

//- (BOOL)allowsWeakReference{
//
//    return  NO;
//}

//+(BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
//{
//    return NO;
//}

//- (void)eat{
//    NSLog(@"Student的eat方法----%@",self.name);
//}

- (void)run {
    NSLog(@"Student的run方法----");
}

- (void)test123
{
    NSLog(@"test123----");
}
@end
