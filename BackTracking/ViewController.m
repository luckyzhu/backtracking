//
//  ViewController.m
//  BackTracking
//
//  Created by NewBoy on 2020/6/12.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "ViewController.h"
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import "nextViewController.h"
#import "Student.h"
#import "UIView+Expand.h"
#import "LXTestObj.h"
#import "TestView.h"
#import "ForwarDayModel.h"
#import "BaseNetWorkModel.h"
#import "SubStudent.h"
#import "NSObject+cat.h"
#import "NSObject+Weak.h"
#import "NSObject+weakAssociatedPointer.h"
#import "NSObject+Default.h"
#import "NSObject+weakTwo.h"
#import "NSObject+WeakContainer.h"

typedef struct {
    BOOL fin;
    size_t age;
    char c;
    NSString *str;
    NSArray *array;
} frame_header;

@interface ViewController ()<NSStreamDelegate,UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong)     NSMutableData *data;
@property(nonatomic,strong)    NSOutputStream *outPutSteam;
@property(nonatomic,strong)     NSInputStream *inPutSteam;
@property(nonatomic,strong)    dispatch_group_t waitGroup;
@property(nonatomic,assign)    int  num;
@property(nonatomic,copy)    NSString *str;
@property(nonatomic) long long isVip;
@property (nonatomic,weak) UILabel *label;
@property (nonatomic,weak) UILabel *label2;
@property (nonatomic,weak) UIView *coverView;
@property (nonatomic,weak) UIView *coverView2;
@property (nonatomic,strong) Student *stu;
@property (nonatomic,strong) ForwarDayModel *forwarddDayModel;
@property (nonatomic,strong) BaseNetWorkModel *baseModel;
@property (nonatomic,strong) BaseNetWorkModel *currentModel;
@property (nonatomic, strong) NSArray *myNumberArr;
@property (nonatomic, weak) NSObject *obj;
@property (nonatomic, assign) NSObject *obj2;
@property (nonatomic, strong) NSThread *thread;

@end

@implementation ViewController
-(NSMutableArray *)data2Array {
    if (_data2Array == nil) {
        _data2Array = [NSMutableArray array];
    }
    return _data2Array;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"测试git amend ----- 22323233423");
    
}

- (void)test {
    NSLog(@"2");
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {

    NSLog(@"--observeValueForKeyPath--%@----%@",keyPath,change);
}

- (id)testBlock{

    __block int val = 10;
    return  ^{
        val ++;
           NSLog(@"--testBlock作为返回值--");
    };
}

//- (id)getBlockArray {
//    int val = 10;
//    return [[NSArray alloc]initWithObjects:[^{
//        NSLog(@"11---%ld",val);
//    } copy], [^{
//        NSLog(@"11---%ld",val);
//    } copy],nil];
//}


- (void)btnClick {

//    NSLog(@"--buttonDidClick--");

    nextViewController *nextVc = [[nextViewController alloc]initWithModel:self.dataArray.firstObject];
    [self.navigationController pushViewController:nextVc animated:YES];

//    buttton.selected = ! buttton.selected;
//    if (buttton.selected) {
//        [UIView animateWithDuration:3.0 animations:^{
//             self.label.transform = CGAffineTransformIdentity;
////            self.label.transform = CGAffineTransformConcat( CGAffineTransformMakeScale(0, 0), CGAffineTransformTranslate(self.label.transform, 0, self.label.frame.size.height / 2));
//            self.label.alpha = 1;
//        }];
//    }else{
//        [UIView animateWithDuration:3.0 animations:^{
//            self.label.transform = CGAffineTransformMakeScale(1, 1);
//            self.label.alpha = 1;
//        }];
//    }

//
//    buttton.selected = ! buttton.selected;
//    if (buttton.selected) {
//
//        [UIView animateWithDuration:5.0 animations:^{
//            CGRect frame = self.label.frame;
//            frame.origin.x = 200;
//            self.label.frame = frame;
//
////            self.label2.frame = CGRectMake(0, 0, 0, 30);
//
//        }];
//
////        [UIView animateWithDuration:1.0 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
////            self.coverView.frame = CGRectMake(0, 0, 100, 0);
////        } completion:^(BOOL finished) {
////
////        }];
//    }else{
//        [UIView animateWithDuration:5.0 animations:^{
//            CGRect frame = self.label.frame;
//            frame.origin.x = 0;
//            self.label.frame = frame;
//
////            self.label.frame = CGRectMake(0, 0, 100, 30);
////            self.label2.frame = CGRectMake(0, 0, 100, 30);
//        }];
//        [UIView animateWithDuration:1.0 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.coverView.frame = CGRectMake(0, 0, 100, 30);
//        } completion:^(BOOL finished) {
//
//        }];
//    }

}


-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return 2;
}

- (void)switchClick:(UISwitch *)sw {
    
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:@"bt_auto_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellId = @"tweak_chat_id";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    NSInteger sectionCount = [self numberOfSectionsInTableView:tableView];
    if (indexPath.section == sectionCount-1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"tweak微信01";
            UISwitch *swit = [[UISwitch alloc]init];
            [swit addTarget:self action:@selector(switchClick:) forControlEvents:UIControlEventValueChanged];
            swit.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"bt_auto_key"];
            cell.accessoryView = swit;
        }else{
            cell.textLabel.text = @"tweak微信02";
        }
    cell.imageView.image = [UIImage imageWithContentsOfFile:@"/123.png"];
        return cell;
    }
    
    return cell;
    
}



- (void)todoSth {
    dispatch_group_enter(self.waitGroup);
    NSLog(@"todoSth----%@",[NSThread currentThread]);
    self.num = 100;
    dispatch_group_leave(self.waitGroup);

}

- (void)_handleFrameHeader:(frame_header)frame_header {
    
    
    NSLog(@"1111----%@",frame_header.array);
}

- (void)testCode
{
    // Do any additional setup after loading the view.
    NSTimeInterval date = [[NSDate date] timeIntervalSince1970];
    sleep(2.3934848);
    UIButton *button = [[UIButton alloc]init];
    [button expandWidth:30 leftExpandWidth:30];
    button.frame = CGRectMake(100, 400, 50, 50);
    [button setTitle:@"按钮" forState:UIControlStateNormal];
    button.titleLabel.textColor = [UIColor redColor];
    button.backgroundColor = [UIColor blueColor];
    [button addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
    button.exclusiveTouch = YES;
    [self.view addSubview:button];

    NSTimeInterval date2 = [[NSDate date] timeIntervalSince1970];
    NSLog(@"1111----%@",[NSNumber numberWithDouble:round(date2 - date)]);
}


@end
