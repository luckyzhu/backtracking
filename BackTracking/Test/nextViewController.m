//
//  nextViewController.m
//  BackTracking
//
//  Created by ZhuLuxi on 2020/7/1.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "nextViewController.h"
#import "Student.h"
#import "NSObject+SJObserverHelper.h"
#import <objc/runtime.h>
#import <objc/message.h>


@interface nextViewController ()
@property(nonatomic,strong)    Student *stu;

@end

@implementation nextViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    Student *stu = [[Student alloc]init];
    stu.name = @"1111";
    self.stu = stu;
    
    [stu addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
    stu.name = @"2222";
    
}


//KVO 监听方法
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    NSLog(@"observeValueForKeyPath---%@",change);
}


-(void)dealloc {
    
//    @try {
//        [self.stu removeObserver:self forKeyPath:@"name"];
//        [self.stu removeObserver:self forKeyPath:@"name"];
//    } @catch (NSException *exception) {
//        NSLog(@"发生了异常...");
//    }
    
    NSLog(@"dealloc...");
}
-(void)test{
    
    NSLog(@"test方法...");
}

@end
