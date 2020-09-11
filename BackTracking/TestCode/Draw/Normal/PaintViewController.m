//
//  PaintViewController.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/27.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "PaintViewController.h"
#import "PaintButtonsView.h"
#import "PaintDrawView.h"
#import "Masonry.h"

@interface PaintViewController ()
@property (nonatomic,strong) PaintButtonsView *buttonsView;
@property (nonatomic,strong) PaintDrawView *drawView;
@end

@implementation PaintViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.drawView = [[PaintDrawView alloc]init];
    [self.view addSubview:self.drawView];

    NSArray *buttonsArray = @[
        @"删除",
        @"打开",
        @"保存",
        @"调整",
        @"撤销",
        @"恢复",
    ];
    self.buttonsView = [[PaintButtonsView alloc]initWithButtonsArray:buttonsArray];
    [self.view addSubview:self.buttonsView];

    [self.buttonsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.view.mas_bottom).offset(-34);
        make.height.mas_equalTo(40);
    }];

    [self.drawView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.buttonsView);
    }];
}

@end
