//
//  ForwarNetWork.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/26.
//  Copyright © 2020 newboy. All rights reserved.
//  

#import "ForwarDayModel.h"

@implementation ForwarDayModel
//-(void)getKLineDataWithYear:(NSInteger)year callback:(BBAEUICallback)callback{
////    self.klineYear = year;
//    //传前复权_日k的URL
//    //数据处理交由BaseModel处理
//    [self getKLineHelper:@"前复权URL" year:year callback:^(id  _Nonnull obj, NSError * _Nonnull error) {
//
//    }];
//}


-(void)setFirstYear:(NSUInteger)year{
    self.klineYear = year;
}


//加载更多
-(void)getMoreKLineDataWithCallback:(BBAEUICallback)callback{

    //每加载成功一次
    self.klineYear -= 1;

    [self getKLineHelper:@"前复权URL" year:self.klineYear callback:^(id  _Nonnull obj, NSError * _Nonnull error) {


    }];
}

@end
