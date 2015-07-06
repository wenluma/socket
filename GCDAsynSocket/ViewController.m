//
//  ViewController.m
//  GCDAsynSocket
//
//  Created by kaxiaoer on 15/6/23.
//  Copyright (c) 2015年 miaogaoliang. All rights reserved.
//

#import "ViewController.h"
#import "GLSocketManager.h"
#import <SkaCmBase.pb.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[GLSocketManager shared] startConnect];
//    [[GLSocketManager shared] socketWriteString:@"hello" tag:1];
    
    for (int i=0; i<10; i++) {
        LinkServerMessage *message = [[[[[LinkServerMessage builder]
                                         setUserId:@"1234567890ytrewqrw"]
                                        setProductType:ProductTypePtEightDotOne]
                                       setLinkType:LinkTypeLtcHeartbeat] build];
    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
