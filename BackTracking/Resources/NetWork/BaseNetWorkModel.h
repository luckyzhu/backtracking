//
//  BaseNetWorkModel.h
//  BackTracking
//
//  Created by NewBoy on 2020/8/26.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^BBAEUICallback)(id obj, NSError *error);

@interface BaseNetWorkModel : NSObject

//年份
@property(nonatomic,assign) NSInteger klineYear;

//模型
@property(nonatomic,strong) NSObject *klineModel;

//获取某个年份的数据
-(void)getKLineDataWithYear:(NSInteger)year callback:(BBAEUICallback)callback;

//加载更多
-(void)getMoreKLineDataWithCallback:(BBAEUICallback)callback;

//处理数据
-(void)getKLineHelper:(NSString *)url year:(NSInteger)year callback:(BBAEUICallback)callback;

@end

NS_ASSUME_NONNULL_END
