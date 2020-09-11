//
//  NSObject+weakAssociatedPointer.h
//  BackTracking
//
//  Created by NewBoy on 2020/9/3.
//  Copyright © 2020 newboy. All rights reserved.
//

/*
 关联对象增加weak策略
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (weakAssociatedPointer)
@property (nonatomic,copy) id weakAssociatedPointer;
@end

NS_ASSUME_NONNULL_END
