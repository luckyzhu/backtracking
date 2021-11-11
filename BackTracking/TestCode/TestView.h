//
//  TestView.h
//  BackTracking
//
//  Created by NewBoy on 2020/8/26.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol TestViewDelegate <NSObject>

- (void)test1;
- (void)test2;
- (void)test3;
- (void)test4;

@end

@interface TestView : UIView
@property (nonatomic,weak) id<TestViewDelegate> delegate;
@property (nonatomic,strong)  UILabel *coverView;
@end

NS_ASSUME_NONNULL_END
