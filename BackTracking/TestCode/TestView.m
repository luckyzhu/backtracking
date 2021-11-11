//
//  TestView.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/26.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "TestView.h"

@implementation TestView

-(instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        UILabel *coverView = [[UILabel alloc]init];
        coverView.backgroundColor = [UIColor lightGrayColor];
//        coverView.frame = CGRectMake(50,50, 20, 20);
//        [self  addSubview:coverView];
        self.coverView = coverView;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapClick)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSaveGState(context);
    CGContextAddRect(context, CGRectMake(50,50, 20, 20));
    CGContextSetFillColorWithColor(context, [UIColor yellowColor].CGColor);
    CGContextFillRect(context, CGRectMake(50,50, 20, 20));
    CGContextRestoreGState(context);



    CGContextSaveGState(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height);
    CGContextSetStrokeColorWithColor(context,[UIColor redColor].CGColor);
    CGContextSetLineWidth(context, 10);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);



//    [self sendSubviewToBack:self.coverView];

//    self.coverView.text = @"123";
//    [self.coverView drawRect:CGRectMake(50,50, 20, 20)];
//    coverView.backgroundColor = [UIColor lightGrayColor];

}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    NSLog(@"layoutSubviews-----");
}

- (void)tapClick
{
    NSLog(@"tapClick-----");
    
    if ([self.delegate respondsToSelector:@selector(test1)]) {
        [self.delegate test1];
    }
}

@end
