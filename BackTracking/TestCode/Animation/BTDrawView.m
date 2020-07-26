//
//  BTDrawView.m
//  testOC2
//
//  Created by NewBoy on 2020/7/17.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "BTDrawView.h"
@interface BTDrawView()
@property (nonatomic,strong) UIImageView *imageView;
@property (nonatomic,strong) UILabel *textLabel;
@end

@implementation BTDrawView

-(instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.lineColor = [UIColor blackColor];
        self.font = [UIFont systemFontOfSize:17.0];
        self.lineWidth = 2.0;
        self.adjustWhenBeyond = YES;
        self.textColor = [UIColor blackColor];
        self.clipsToBounds = NO;
    }
    return self;
}

-(UILabel *)textLabel {
    if (_textLabel == nil) {
        _textLabel = [[UILabel alloc]init];
    }
    return _textLabel;
}

-(UIImageView *)imageView {
    if (_imageView == nil) {
        _imageView = [[UIImageView alloc]init];
        [self addSubview:_imageView];
    }
    return _imageView;
}

-(void)setImage:(UIImage *)image {
    _image = image;
    self.imageView.image = _image;
}

-(void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];

    //调整y和高度
    CGRect frame = self.frame;
    frame.origin.y -= self.lineWidth;
    frame.size.height += self.lineWidth *2;
    self.frame = frame;

    if (self.radius == 0) {
        self.radius = (self.frame.size.width > self.frame.size.height  ? self.frame.size.height : self.frame.size.width) / 2 - self.lineWidth ;
    }

    if (self.adjustWhenBeyond) {
        //根据text算文本的大小
        CGFloat width =  [self.text sizeWithAttributes:@{
            NSFontAttributeName : self.font,
        }].width;

        CGFloat finalWidth = self.radius * 3 + width ;
        CGRect frame = self.frame;
        frame.size.width = finalWidth;
        self.frame = frame;
    }

    self.imageView.frame = CGRectMake(0, 0, self.radius * 2, self.radius * 2);
    self.imageView.center = CGPointMake(self.radius, self.frame.size.height / 2);
}

- (void)drawRect:(CGRect)rect {

    UIBezierPath* path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(rect.size.width - self.radius - self.lineWidth, rect.size.height / 2)
                                                        radius:self.radius
                                                    startAngle:M_PI * 3/2
                                                      endAngle:M_PI * 1/2
                                                     clockwise:YES];
    path.lineWidth = self.lineWidth;

    CGFloat topPointY = (rect.size.height / 2 - self.radius);
    [path moveToPoint:CGPointMake(self.radius, topPointY)];
    [path addLineToPoint:CGPointMake(rect.size.width - self.radius, topPointY)];

    CGFloat bottomPointY = (rect.size.height / 2 + self.radius);
    [path moveToPoint:CGPointMake(self.radius, bottomPointY)];
    [path addLineToPoint:CGPointMake(rect.size.width - self.radius, bottomPointY)];
    [self.lineColor set];
    [path stroke];

    if (self.text.length > 0) {
        CGFloat height =  [self.text sizeWithAttributes:@{
            NSFontAttributeName : self.font,
        }].height;

        CGFloat width =  [self.text sizeWithAttributes:@{
            NSFontAttributeName : self.font,
        }].width;

        [self.text drawInRect:CGRectMake(self.radius * 2, (self.frame.size.height - height) / 2, width, height) withAttributes:@{
            NSForegroundColorAttributeName : self.textColor,
            NSFontAttributeName : self.font,
        }];
    }

}

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint leftP = [self convertPoint:point toView:self.imageView];
    if ([self.imageView pointInside:leftP withEvent:event]) {
        return YES;
    }
    return NO;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.leftImageViewDidClick) {
        self.leftImageViewDidClick();
    }

}

@end
