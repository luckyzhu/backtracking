//
//  PaintDrawView.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/27.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "PaintDrawView.h"
@interface PaintDrawView()
@property (nonatomic,strong) NSMutableArray *lineArray;
@end

@implementation PaintDrawView

-(NSMutableArray *)lineArray {
    if (_lineArray == nil) {
        _lineArray = [NSMutableArray array];
    }
    return _lineArray;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    //1、每次触摸的时候都应该去创建一条贝塞尔曲线
     UIBezierPath *path = [UIBezierPath new];
    //2、移动画笔
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    [path moveToPoint:point];
    //设置线宽
    path.lineWidth = 2;
    [self.lineArray addObject:path];
}

//持续画
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    UIBezierPath *path = self.lineArray.lastObject;
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    [path addLineToPoint:point];
    //重新绘制
    [self setNeedsDisplay];
}


- (void)drawRect:(CGRect)rect{
    //遍历数组，绘制曲线
    if(self.lineArray.count > 0){
        for (UIBezierPath *path in self.lineArray) {
            [[UIColor redColor] setStroke];
            [path setLineCapStyle:kCGLineCapRound];
            [path stroke];
        }
    }
}

@end
