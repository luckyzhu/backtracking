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
#import "ViewController.h"
#import "UIView+Expand.h"
#import "SubStudent.h"

typedef void(^TestBlock)(void);

@interface nextViewController ()
@property(nonatomic,copy)    TestBlock block;
@property (nonatomic,strong)   Student *stu;
@property (nonatomic,strong)   Student *stu2;
@property (nonatomic,weak) NSTimer *timer;
@end

@implementation nextViewController

-(instancetype)initWithModel:(Student *)stu{
    if (self = [super init]) {
//        self.stu2 = stu;
//        NSLog(@"-111---");
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];


    SubStudent *sub = [[SubStudent alloc]init];
    Student *stu = [[Student alloc]init];

    [stu addObserver:self forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:@"fulei"];
    [sub addObserver:self forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:@"zilei"];

    stu.text = @"111";
    sub.text = @"222";

//
//    Student *stu = [[Student alloc]init];
//    stu.name = @"1111";
//    self.stu = stu;
//
//    [stu addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
//    stu.name = @"2222";


//    __block  id  weakSelf = self;


//    __block id  weakSelf = self;
//    self.block = ^{
//        NSLog(@"self----%@",weakSelf);
//        weakSelf = nil;
//    };
//
//    //必须执行block内容,才能释放对象
//    self.block();




//    __weak typeof(self)ws = self;

//    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(test) userInfo:nil repeats:YES];
//    self.timer = timer;

}

- (void)test{
    NSLog(@"-test---");
}

-(void)btnClick {

    ViewController *vc = (ViewController *)self.navigationController.viewControllers.firstObject;
    [vc.dataArray removeAllObjects];
    vc.dataArray = nil;
    NSLog(@"self.stu2.name111----%@",self.stu2.name);
    NSLog(@"--btnClick--");

}


//KVO 监听方法
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    NSLog(@"observeValueForKeyPath---%@----%@",change,context);
}


-(void)dealloc {
    
//    @try {
//        [self.stu removeObserver:self forKeyPath:@"name"];
//        [self.stu removeObserver:self forKeyPath:@"name"];
//    } @catch (NSException *exception) {
//        NSLog(@"发生了异常...");
//    }

    [self.timer invalidate];
    NSLog(@"dealloc...");
}

@end
