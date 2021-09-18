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
#import "nextViewController.h"

#import <objc/runtime.h>
#import <malloc/malloc.h>
typedef struct {
    BOOL fin;
    size_t age;
    char c;
    NSString *str;
    NSArray *array;
} frame_header;

@interface ViewController ()<NSStreamDelegate,UITableViewDataSource,UITableViewDelegate,UICollectionViewDelegate,UICollectionViewDataSource>
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
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *testView;

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
    
    
    NSMutableDictionary *debugLog = [NSMutableDictionary dictionaryWithDictionary:nil];

    
    
    Student *p = [[Student alloc] init];
    NSLog(@"%zd %zd", class_getInstanceSize([Student class]), // 16
                  malloc_size((__bridge const void *)(p))); // 16

    
    NSLog(@"viewDidLoad");
    self.view.backgroundColor = [UIColor yellowColor];
    
    TestView *testView = [[TestView alloc]init];
    testView.backgroundColor = [UIColor redColor];
    testView.frame = CGRectMake(0, 100, self.view.bounds.size.width, 200);
    [self.view addSubview:testView];
    self.testView = testView;

    UIButton *button = [[UIButton alloc]init];
    button.frame = CGRectMake(100, 400, 50, 50);
    [button setTitle:@"按钮" forState:UIControlStateNormal];
    button.titleLabel.textColor = [UIColor blueColor];
    button.backgroundColor = [UIColor greenColor];
    [button addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
}



-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"viewWillAppear");
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"viewDidAppear");
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    NSLog(@"viewWillLayoutSubviews");
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    NSLog(@"viewDidLayoutSubviews");
}

#pragma mark -collectionview 数据源方法
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    
    return 6;   //返回section数
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return 3;  //每个section的Item数
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //创建item / 从缓存池中拿 Item
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MAINCOLLECTIONVIEWID" forIndexPath:indexPath];
    CGFloat red = (arc4random() % 255 ) / 255.0;
    CGFloat green = (arc4random() % 255 ) / 255.0;
    CGFloat blue = (arc4random() % 255 ) / 255.0;

    cell.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
    // 外界在此给Item添加模型数据
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];//取消选中
     
    NSLog(@"点击l...");
    INT16_MAX;
    [self.collectionView setContentOffset:CGPointMake(0, INT64_MAX+1) animated:YES];
    
//    NSArray *array = @[@"1",@"2"];
//
//
//    int a = 1000;
//    NSLog(@"点击2...array---%@",array[a]);
    
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


- (void)btnClick{
    
//    CGRect frame = self.testView.frame;
//    frame.size.height -= 10;
//    self.testView.frame = frame;
        
//    [self.testView setNeedsLayout];
    // viewWillLayoutSubviews 和 viewDidLayoutSubviews触发时机
    //1.改变子控件的宽度会触发
    //2.改变子控件的高度会触发
    //3.改变子控件的x和y不会触发
    
    nextViewController *vc = [[nextViewController alloc]init];
    [self.navigationController pushViewController:vc animated:YES];
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
    

    NSTimeInterval date2 = [[NSDate date] timeIntervalSince1970];
    NSLog(@"1111----%@",[NSNumber numberWithDouble:round(date2 - date)]);
}


@end
