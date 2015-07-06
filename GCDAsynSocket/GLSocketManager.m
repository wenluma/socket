//
//  GLSocketManager.m
//  GCDAsynSocket
//
//  Created by kaxiaoer on 15/6/23.
//  Copyright (c) 2015年 miaogaoliang. All rights reserved.
//

#import "GLSocketManager.h"
#import "GCDAsyncSocket.h"
#import <netinet/in.h>
#import <arpa/inet.h>

#import <SkaCmBase.pb.h>

#define KTIMEOUT_FISRT 2000
#define KTIMEOUT_MSG 5000

#define KTAG_POSTMAN 0
#define KTAG_MSG 1
#define KTAG_MSG_STRING_DATA 2
#define KTAG_MSG_PB_DATA 3

#define KONLINE 0
#if KONLINE
#define KPORT 10086
#define KONLINE_IP @"121.41.53.178"
#else
#define KONLINE_IP @"192.168.1.118"
#define KPORT 10086
#endif

@interface GLSocketManager()<GCDAsyncSocketDelegate>

- (void)startConnect;
- (void)startConnectWithHost:(NSString *)host port:(uint16_t)port;
- (void)socketWriteString:(NSString *)str tag:(long)tag;
- (void)socketWriteData:(NSData *)data tag:(long)tag;//pb data
- (void)socketReadDataWithTag:(long)tag;

@end

@implementation GLSocketManager
+(instancetype)shared{
    static GLSocketManager * sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[GLSocketManager alloc] init];
    });
    return sharedManager;
}
- (instancetype)init{
    self = [super init];
    if (self) {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
    delegateQueue:dispatch_get_main_queue()];
        self.host = KONLINE_IP;
        self.port = KPORT;
//        self.host = @""
        
//        NSError *err = nil;
//        
//        uint16_t thePort = htons(1234);
//        
//        struct sockaddr_in ip;
//        ip.sin_family = AF_INET;
//        ip.sin_port = htons(thePort);
//        inet_pton(AF_INET, "192.168.2.5", &ip.sin_addr);
//
//        NSData* host = [NSData dataWithBytes:&ip length:ip.sin_len];
//
//        if(![self.socket connectToAddress:host error:&err]) {
//            NSLog(@"Failed to connect... %@", err);
//        }

    }
    return self;
}

#pragma mark - gcdayncsocket delegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    NSLog(host,nil);
}
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{


    
    @try {
        NoticeClientMessage *message = [NoticeClientMessage parseFromData:data];
        NSLog(message.accountId, nil);
        [self socketReadDataWithTag:tag];
    }
    @catch (NSException *exception) {
        NSLog([exception description], nil);
        [sock disconnect];
    }
    @finally {
        
    }
}
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(@"write");
}
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocke{
    NSLog([newSocke description],nil);
}
- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock{
    NSLog(@"close");
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog([err description],nil);
}
#pragma mark - start
- (void)startConnect{
    [self startConnectWithHost:self.host port:self.port];
}

- (void)startConnectWithHost:(NSString *)host port:(uint16_t)port{
    if (![self.socket isConnected]) {
        NSError * __autoreleasing err = nil;
        [self.socket connectToHost:host onPort:port withTimeout:KTIMEOUT_FISRT error:&err];
    }
}

#pragma mark - write data
- (void)socketWriteString:(NSString *)str tag:(long)tag{
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
   
    [self.socket writeData:data withTimeout:KTIMEOUT_MSG tag:tag];
    [self.socket writeData:[GCDAsyncSocket LFData] withTimeout:KTIMEOUT_MSG tag:tag];
}
- (void)socketWriteData:(NSData *)data tag:(long)tag{
    [self.socket writeData:data withTimeout:KTIMEOUT_MSG tag:tag];
}
#pragma mark - read data
- (void)socketReadDataWithTag:(long)tag{
    [self.socket readDataWithTimeout:KTIMEOUT_MSG tag:tag];
}
#pragma mark - user login
- (void)userHandler:(NSString *)userinfo
      messageTyep:(GLRequestType)type{// 身份证，或者 id 号码
    LinkType link = (LinkType)type;
    LinkServerMessage *message = [[[[[LinkServerMessage builder]
                                     setUserId:userinfo]
                                    setProductType:ProductTypePtEightDotOne]
                                   setLinkType:link] build];
    [[GLSocketManager shared] socketWriteData:[message data] tag:GLDataMessageTypeProtobuf];
}

- (void)startHeartBeat{// send data per 5s
    [self userHandler:@"" messageTyep:GLRequestTypeHeartBeat];
}
@end
