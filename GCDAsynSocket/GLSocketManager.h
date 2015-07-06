//
//  GLSocketManager.h
//  GCDAsynSocket
//
//  Created by 苗高亮 on 15/6/23.
//  Copyright (c) 2015年 miaogaoliang. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, GLDataMessageType) {
    GLDataMessageTypeString = 1,
    GLDataMessageTypeProtobuf,
};

typedef NS_ENUM(NSUInteger, GLRequestType) {
    GLRequestTypeLogin =1,
    GLRequestTypeAll,
    GLRequestTypeHeartBeat,
};


@class GCDAsyncSocket;

@interface GLSocketManager : NSObject

+(instancetype)shared;

@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (copy, nonatomic) NSString *host;
@property (copy, nonatomic) NSString *address;
@property (assign) uint16_t port;

//建立连接
- (void)startConnect;
- (void)startConnectWithHost:(NSString *)host port:(uint16_t)port;

//登陆请求请求
- (void)userHandler:(NSString *)userinfo messageTyep:(GLRequestType)type;

@end
