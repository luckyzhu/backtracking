//
//  ViewController.h
//  BackTracking
//
//  Created by NewBoy on 2020/6/12.
//  Copyright © 2020 newboy. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void (^testBlcok)(void);

@interface ViewController : UIViewController
@property (nonatomic,strong) NSMutableArray *dataArray;
@property (nonatomic,strong) NSMutableArray *data2Array;

@end

