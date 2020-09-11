//
//  UIView+Expand.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/20.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "UIView+Expand.h"
#import <objc/runtime.h>

static const NSString *topExpandWidthKey = @"topExpandWidthKey";
static const NSString *leftExpandWidthKey = @"leftExpandWidthKey";

@interface UIView()
@property (nonatomic,assign) CGFloat topExpandWidth;
@property (nonatomic,assign) CGFloat leftExpandWidth;
@end

@implementation UIView (Expand)

-(void)setTopExpandWidth:(CGFloat)topExpandWidth {
    objc_setAssociatedObject(self, &topExpandWidthKey, @(topExpandWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(CGFloat)topExpandWidth {
    NSNumber *num = (NSNumber *)objc_getAssociatedObject(self,&topExpandWidthKey);
    return num.floatValue;
}

-(void)setLeftExpandWidth:(CGFloat)leftExpandWidth{
    objc_setAssociatedObject(self, &leftExpandWidthKey, @(leftExpandWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(CGFloat)leftExpandWidth {
    NSNumber *num = (NSNumber *)objc_getAssociatedObject(self,&leftExpandWidthKey);
    return num.floatValue;
}

-(void)expandWidth:(CGFloat)topExpandWidth leftExpandWidth:(CGFloat)leftExpandWidth {
    self.topExpandWidth = topExpandWidth;
    self.leftExpandWidth = leftExpandWidth;
}

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect bounds = self.bounds;
    CGFloat widthDelta = - self.leftExpandWidth;
    CGFloat heightDelta = - self.topExpandWidth;
    bounds = CGRectInset(bounds,  widthDelta, heightDelta);
    return CGRectContainsPoint(bounds, point);
}

@end
