//
//  PaintButtonsView.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/27.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "PaintButtonsView.h"
#import "Masonry.h"

@interface PaintButtonsView()

@property (nonatomic,copy) NSArray *buttonsArray;

@end
@implementation PaintButtonsView

- (instancetype)initWithButtonsArray:(NSArray *)buttonsArray {

    if (self = [super init]) {

        self.buttonsArray = buttonsArray;

        [self configUI];
    }

    return self;
}

- (void)configUI {
    UIButton *lastBtn;
    for (NSString *str  in self.buttonsArray) {
        UIButton *button = [[UIButton alloc]init];
        [button setTitle:str forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [self addSubview:button];

        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.mas_equalTo(self);
            make.left.mas_equalTo(lastBtn == nil ? self.mas_left : lastBtn.mas_right);
        }];
        lastBtn = button;
    }
}

-(void)layoutSubviews {
    [super layoutSubviews];

    for (UIButton *button in self.subviews) {
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo(self.mas_width).multipliedBy(1.0 / self.subviews.count);
        }];
    }
}

@end
