//
//  ViewController.m
//  BackTracking
//
//  Created by NewBoy on 2020/6/12.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "ViewController.h"
#import "BTThread.h"


typedef struct {
    BOOL fin;
    size_t age;
    char c;
    NSString *str;
    NSArray *array;
} frame_header;

@interface ViewController ()<NSStreamDelegate>

@property(nonatomic,strong)     NSMutableData *data;
@property(nonatomic,strong)    NSOutputStream *outPutSteam;
@property(nonatomic,strong)     NSInputStream *inPutSteam;
@property(nonatomic,strong)    dispatch_group_t waitGroup;
@property(nonatomic,assign)    int  num;
@property(nonatomic,copy)    NSString *str;
@end

@implementation ViewController
@synthesize str = _testStr;

//- (void)setStr:(NSString *)str {
//
//    _testStr = str;
//
//}
//
//-(NSString *)str {
//
//    return @"哈哈哈哈";
//}




- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.waitGroup = dispatch_group_create();
        
//    //线程
//    BTThread *thread = [[BTThread alloc]initWithTarget:self selector:@selector(todoSth) object:nil];
////    [thread start];

    NSString *key = @"HTTP/1.1 101 Switching Protocols";
    NSData *data =[key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"%s %s", [key UTF8String], data.bytes);
 
    frame_header header = {1,99,'acb',@"字符",@[@"1",@"2",@"3"]};
    
    [self _handleFrameHeader:header];
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
