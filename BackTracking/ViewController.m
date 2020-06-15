//
//  ViewController.m
//  BackTracking
//
//  Created by NewBoy on 2020/6/12.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Contacts.app"]) {
        NSLog(@"越狱手机...");
    }else{
        NSLog(@"非越狱手机...");
    }
    

}


@end
