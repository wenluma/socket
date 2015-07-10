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
#import <CodedInputStream.h>
#import <CodedOutputStream.h>

#define KTIMEOUT_FISRT 2000
#define KTIMEOUT_MSG 5000

#define KTAG_POSTMAN 0
#define KTAG_MSG 1
#define KTAG_MSG_STRING_DATA 2
#define KTAG_MSG_PB_DATA 3

#define KONLINE 1
#if KONLINE
#define KPORT 10086
#define KONLINE_IP @"121.41.53.178"
#else

#define KONLINE_IP @"192.168.1.109"
//#define KONLINE_IP @"0.0.0.0"
#define KPORT 8080
#endif

@protocol BufferRealDelegate <NSObject>
- (void)pbObjsFromData:(NSData *)data;
- (void)resetDataSource:(NSData *)data;
@end

@interface BufferReal : NSObject
@property (strong, nonatomic) NSPurgeableData * realData;
@property (assign, nonatomic) int length;
@property (assign, nonatomic) int size;
@property (strong, nonatomic) NSMutableArray *array;
@property (weak, nonatomic) id<BufferRealDelegate> delegate;
@end
@implementation BufferReal

- (instancetype)initWithData:(NSData *)data length:(int)length{
    self = [super init];
    if (self) {
        _realData = [NSPurgeableData data];
        _array = [[NSMutableArray alloc] initWithCapacity:1];
        [_realData appendData:data];
        self.length = length;
    }
    return self;
}
- (instancetype)init{
    self = [super init];
    if (self) {
        _realData = [NSPurgeableData data];
        _array = [[NSMutableArray alloc] initWithCapacity:1];
    }
    return self;
}
- (void)append:(NSData *)data{
    [_realData beginContentAccess];
    [_realData appendData:data];
    [_realData endContentAccess];
    [_delegate resetDataSource:_realData];
}
- (BOOL)isEnd{
    int enableLength = _length + _size;
    BOOL hasPB= enableLength <= _realData.length && _size > 0;
    if (hasPB) {
        NSData *data = [_realData subdataWithRange:NSMakeRange(0, enableLength)];
        [_delegate pbObjsFromData:data];
        NSData *last = [_realData subdataWithRange:NSMakeRange(enableLength, _realData.length-enableLength)];
        [self reset];
        _realData = [NSPurgeableData dataWithData:last];
        [_delegate resetDataSource:_realData];
    }
    return hasPB;
}

- (void)reset{
    _realData = nil;
    _length = 0;
    _size = 0;
}
@end

@interface GLSocketManager()<GCDAsyncSocketDelegate,BufferRealDelegate>
@property (strong, nonatomic) NSTimer *heartBeat;
@property (strong, nonatomic) BufferReal *realData;
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
        _realData = [[BufferReal alloc] init];
        _realData.delegate = self;
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
    if (!_heartBeat) {
        [self setupHeartBeat];
    }
    [self checkEndDecode:data];
    [self socketReadDataWithTag:GLDataMessageTypeProtobuf];
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
    [self invaildHeartBeat];
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
#pragma mark - delegate
- (void)pbObjsFromData:(NSData *)data{
    NoticeClientMessage *msg = [self decodeWithData:data];
    if (msg) {
        if ([_delegate respondsToSelector:@selector(handleCallbackDataSource:)]) {
            [_delegate handleCallbackDataSource:msg];
        }
    }
}
- (void)resetDataSource:(NSData *)data{
    if (data.length > 0 && _realData.size < 1) {
        PBCodedInputStream *reader = [PBCodedInputStream streamWithData:data];
        int length = [reader readRawVarint32];
        _realData.length = length;
        _realData.size = [reader getCurrentPos];
    }
}
#pragma mark - encode / decode
- (NSData *)encodeMessage:(LinkServerMessage *)message{
    return [self encode:[message data]];
}
- (NSData *)encode:(NSData *)data{
    
    int size = (int)data.length;
    int headOut = computeRawVarint32Size(size);
    NSMutableData *mutData = [[NSMutableData alloc] initWithCapacity:headOut];
    Byte *buf = malloc(headOut);
    [mutData appendBytes:buf length:headOut];

    PBCodedOutputStream *writer = [PBCodedOutputStream streamWithData:mutData];
    [writer writeRawVarint32:size];
    
    NSMutableData *result = [NSMutableData data];
    [result appendData:mutData];
    [result appendData:data];
    
    free(buf);
    return result;
}

- (void)checkEndDecode:(NSData *)data{
    [_realData append:data];
    while ([_realData isEnd]) {
    }
}

- (NoticeClientMessage *)decodeWithData:(NSData *)data{
    NoticeClientMessage *message = nil;
    @try {
        PBCodedInputStream *reader = [PBCodedInputStream streamWithData:data];
        [reader readRawVarint32];
        message = [NoticeClientMessage parseFromCodedInputStream:reader];
    }
    @catch (NSException *exception) {
        [self.socket disconnect];
        [self invaildHeartBeat];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self userHandler:nil messageTyep:GLRequestTypeLogin];
        });
    }
    @finally {
    }
    return message;
}

#pragma mark - write data
- (void)socketWriteString:(NSString *)str tag:(long)tag{
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
   
    [self.socket writeData:data withTimeout:KTIMEOUT_MSG tag:tag];
    [self.socket writeData:[GCDAsyncSocket LFData] withTimeout:KTIMEOUT_MSG tag:tag];
}
- (void)socketWriteData:(NSData *)data tag:(long)tag{
    [self.socket writeData:data withTimeout:KTIMEOUT_MSG tag:tag];
    [self socketReadDataWithTag:GLDataMessageTypeProtobuf];
}

#pragma mark - read data
- (void)socketReadDataWithTag:(long)tag{
    [self.socket readDataWithTimeout:KTIMEOUT_MSG tag:tag];
}
#pragma mark - user login
- (void)userHandler:(NSString *)userinfo
      messageTyep:(GLRequestType)type{// 身份证，或者 id 号码
    LinkType link = (LinkType)type;
    if (!_userid) {
        _userid = userinfo;
    }
    LinkServerMessage *message = [[[[[LinkServerMessage builder]
                                     setUserId:userinfo]
                                    setProductType:ProductTypePtEightDotOne]
                                   setLinkType:link] build];
    
    NSData *data = [self encodeMessage:message];
    [[GLSocketManager shared] socketWriteData:data tag:GLDataMessageTypeProtobuf];
}

#pragma mark - heart beat
- (void)setupHeartBeat{// send data per 5s
    if (!_heartBeat) {
        NSUInteger type = GLRequestTypeHeartBeat;
        NSString * obj = @"";
        NSMethodSignature *signature = [self methodSignatureForSelector:@selector(userHandler:messageTyep:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:@selector(userHandler:messageTyep:)];
        [invocation setArgument:&obj atIndex:2];
        [invocation setArgument:&type atIndex:3];
        
        _heartBeat = [NSTimer scheduledTimerWithTimeInterval:KTIMEOUT_MSG/500
                                                  invocation:invocation
                                                     repeats:YES];
    }
    _heartBeat.fireDate = [NSDate dateWithTimeIntervalSinceNow:KTIMEOUT_MSG/1000];
}
- (void)invaildHeartBeat{
    if (_heartBeat) {
        [_heartBeat invalidate];
        _heartBeat = nil;
    }
}

@end
