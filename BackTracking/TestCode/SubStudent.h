//
//  SubStudent.h
//  BackTracking
//
//  Created by NewBoy on 2020/8/27.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "Student.h"

NS_ASSUME_NONNULL_BEGIN

@interface SubStudent : Student
@property (nonatomic,copy) NSString *subName;
@property (nonatomic,copy) NSString *name;
@property (nonatomic, weak) id weakName;
- (void)testSubStu;

@end

NS_ASSUME_NONNULL_END
