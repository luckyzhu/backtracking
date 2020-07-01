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
@end

@implementation ViewController
@synthesize str = _testStr;


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.waitGroup = dispatch_group_create();

    UITableView *tableview = [[UITableView alloc]initWithFrame:CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-64)];
    tableview.delegate = self;
    tableview.dataSource = self;
    [self.view addSubview:tableview];
    
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    [button setTitle:@"按钮一" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonDidClick) forControlEvents:UIControlEventTouchUpInside];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
}

- (void)buttonDidClick {
    
    nextViewController *nextVc = [[nextViewController alloc]init];
    [self.navigationController pushViewController:nextVc animated:YES];
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


@end
