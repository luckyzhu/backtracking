//
//  YogaViewController.m
//  BackTracking
//
//  Created by luxizhu on 2021/5/7.
//  Copyright © 2021 newboy. All rights reserved.
//

#import "YogaViewController.h"
#import "UIView+Yoga.h"
#import "Yoga.h"

#define buttonWidth 50
#define buttonHeight 50

@interface YogaViewController ()
@property (nonatomic,strong) UIView *rightView;
@property (nonatomic,strong) UIView *leftView;
@property (nonatomic,strong) UIButton *button4;
@property (nonatomic,strong) UIView *contentView;

@end

@implementation YogaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view configureLayoutWithBlock:^(YGLayout * layout) {
        layout.isEnabled = YES;
        layout.width = YGPointValue(self.view.bounds.size.width);
        layout.height = YGPointValue(self.view.bounds.size.height);
    }];

    UIView *contentView = [[UIView alloc]init];
    contentView.backgroundColor = [UIColor clearColor];
    [contentView configureLayoutWithBlock:^(YGLayout * layout) {
        layout.isEnabled = YES;
        layout.height = YGPointValue(self.view.bounds.size.height - 50 - 34);
        layout.flexDirection = YGFlexDirectionRowReverse; //主轴方向:右边视图指定宽度,剩下的宽度全部给左边
    }];
    [self.view addSubview:contentView];
    self.contentView = contentView;
    
    UIView *bottomView = [[UIView alloc]init];
    bottomView.backgroundColor = [UIColor redColor];
    [bottomView configureLayoutWithBlock:^(YGLayout * layout) {
        layout.isEnabled = YES;
        layout.height = YGPointValue(50);
    }];
    [self.view addSubview:bottomView];
    
    //右边view
    UIView *rightView = [[UIView alloc]init];
    rightView.backgroundColor = [UIColor lightGrayColor];
    rightView.yoga.isEnabled = YES;
    rightView.yoga.width = YGPointValue(buttonWidth * 2);
//    rightView.yoga.height = YGPercentValue(100); //和父视图高度一样
    rightView.yoga.flexDirection = YGFlexDirectionColumnReverse; //从下面往上面布局
    rightView.yoga.alignItems = YGAlignFlexEnd; //垂直于主轴的布局方式
    rightView.yoga.paddingRight = YGPointValue(20);//内边距20
    [contentView addSubview:rightView];
    self.rightView = rightView;
    [self addRightSubViews];
    
    //左边view
    UIView *leftView = [[UIView alloc]init];
    leftView.backgroundColor = [UIColor darkGrayColor];
    leftView.yoga.isEnabled = YES;
    leftView.yoga.flexGrow = 1; //剩余的宽度全部给左边
    leftView.yoga.flexDirection = YGFlexDirectionColumnReverse; //从下面往上面布局
    [contentView addSubview:leftView];
    self.leftView = leftView;
    [self addLeftSubViews];

    //计算布局
    [self.view.yoga applyLayoutPreservingOrigin:YES];
}

- (void)addRightSubViews
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor darkGrayColor];
    [button setTitle:@"音乐" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    button.yoga.isEnabled = YES;
    button.yoga.marginBottom = YGPointValue(34);
    button.yoga.height = YGPointValue(buttonHeight);
    button.yoga.width = YGPercentValue(100);
    [self.rightView addSubview:button];

    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeCustom];
    button2.backgroundColor = [UIColor darkGrayColor];
    [button2 setTitle:@"转发" forState:UIControlStateNormal];
    [button2 setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    button2.yoga.isEnabled = YES;
    button2.yoga.marginBottom = YGPointValue(10);
    button2.yoga.width = YGPointValue(buttonWidth);
    button2.yoga.height = YGPointValue(buttonHeight);
    [self.rightView addSubview:button2];
    
    UIButton *button3 = [UIButton buttonWithType:UIButtonTypeCustom];
    button3.backgroundColor = [UIColor darkGrayColor];
    [button3 setTitle:@"评论" forState:UIControlStateNormal];
    [button3 setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [button3 addTarget:self action:@selector(button3DidClick) forControlEvents:UIControlEventTouchUpInside];
    button3.yoga.isEnabled = YES;
    button3.yoga.marginBottom = YGPointValue(10);
    button3.yoga.width = YGPointValue(buttonWidth);
    button3.yoga.height = YGPointValue(buttonHeight);
    [self.rightView addSubview:button3];
    
    UIButton *button4 = [UIButton buttonWithType:UIButtonTypeCustom];
    button4.backgroundColor = [UIColor darkGrayColor];
    [button4 setTitle:@"点赞" forState:UIControlStateNormal];
    [button4 setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.rightView addSubview:button4];
    self.button4 = button4;
    self.button4.yoga.isEnabled = YES;
    self.button4.yoga.marginBottom = YGPointValue(20);
    self.button4.yoga.width = YGPointValue(buttonWidth);
    self.button4.yoga.height = YGPointValue(buttonHeight);
}

- (void)addLeftSubViews
{
    UIView *bottomView = [[UIView alloc]init];
    bottomView.backgroundColor = [UIColor blueColor];
    bottomView.yoga.isEnabled = YES;
    bottomView.yoga.width = YGPercentValue(100);
    bottomView.yoga.height = YGPointValue(260);
    [self.leftView addSubview:bottomView];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor lightGrayColor];
    [button setTitle:@"横屏" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    button.yoga.isEnabled = YES;
    button.yoga.marginBottom = YGPointValue(200);
    button.yoga.height = YGPointValue(buttonHeight);
    button.yoga.width = YGPointValue(buttonWidth);
    [self.leftView addSubview:button];
}

- (void)button3DidClick
{
    self.button4.yoga.height = YGPointValue(buttonHeight * 2);
    [self.rightView.yoga applyLayoutPreservingOrigin:YES];
}
@end
