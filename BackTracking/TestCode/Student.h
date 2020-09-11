//
//  Student.h
//  BackTracking
//
//  Created by ZhuLuxi on 2020/7/1.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Student : NSObject
@property (nonatomic,copy) NSString *text;
@property(nonatomic,copy)    NSString *name;
@property(nonatomic,copy)    NSString *age;

- (void)studentTestMethod;

- (void)eat;

- (void)run;


@end

NS_ASSUME_NONNULL_END
