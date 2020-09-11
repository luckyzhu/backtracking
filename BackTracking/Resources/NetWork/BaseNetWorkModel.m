//
//  BaseNetWorkModel.m
//  BackTracking
//
//  Created by NewBoy on 2020/8/26.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "BaseNetWorkModel.h"

@implementation BaseNetWorkModel

-(instancetype)init {
    if (self = [super init]) {
        // self.klineYear 等于当前年
    }
    return self;
}

//根据传入的url 进行数据处理
-(void)getKLineHelper:(NSString *)url year:(NSInteger)year callback:(BBAEUICallback)callback{

    //处理从服务端返回的数据,得到对应的数据模型
    //处理数据模型

}

@end
