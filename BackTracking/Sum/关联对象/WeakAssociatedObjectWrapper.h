//
//  WeakAssociatedObjectWrapper.h
//  BackTracking
//
//  Created by NewBoy on 2020/9/4.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WeakAssociatedObjectWrapper : NSObject
@property (nonatomic, weak) id object;
@end

NS_ASSUME_NONNULL_END
