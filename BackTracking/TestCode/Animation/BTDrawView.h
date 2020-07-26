//
//  BTDrawView.h
//  testOC2
//
//  Created by NewBoy on 2020/7/17.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN
typedef void(^ImageBlock)(void);
@interface BTDrawView : UIView

@property (nonatomic,strong) NSString *text;
@property (nonatomic,strong) UIColor *textColor;
@property (nonatomic,strong) UIColor *lineColor;
@property (nonatomic,assign) CGFloat radius;
@property (nonatomic,assign) CGFloat lineWidth;
@property (nonatomic,assign) UIFont *font;
@property (nonatomic,strong) UIImage *image;
/** 默认为YES,文本宽度超出父控件时,调整父控件的宽度*/
@property (nonatomic,assign) BOOL adjustWhenBeyond;

@property (nonatomic,copy) ImageBlock leftImageViewDidClick;
@end

NS_ASSUME_NONNULL_END
