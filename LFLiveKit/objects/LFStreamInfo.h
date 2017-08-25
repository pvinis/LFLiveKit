//
//  LFStreamInfo.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LFAudioConfiguration.h"
#import "LFVideoConfiguration.h"

typedef NS_ENUM(NSUInteger, LFLiveState) {
    // prepared
    LFLiveStateReady = 0,
    // connecting
    LFLiveStatePending = 1,
    // connected
    LFLiveStateStart = 2,
    // has been disconnected
    LFLiveStateStop = 3,
    // connection error
    LFLiveStateError = 4,
    // is reconnecting
    LFLiveStateReconnecting = 5,
};

typedef NS_ENUM(NSUInteger, LFLiveSocketError) {
//    LFLiveSocketErrorPreviewView = 201,          /// 预览失败
//    LFLiveSocketErrorGetStreamInfo = 202,        /// 获取流媒体信息失败
//    LFLiveSocketErrorConnectSocket = 203,        /// 连接socket失败
//    LFLiveSocketErrorVerification = 204,         /// 验证服务器失败
    LFLiveSocketErrorReconnectTimeout = 205, // reconnecting to server timed out
};


@interface LFStreamInfo : NSObject

@property (nonatomic, copy) NSString *streamId;

#pragma mark -- FLV
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;

#pragma mark -- RTMP
@property (nonatomic, copy) NSString *url;          // upload address

@property (nonatomic, strong) LFAudioConfiguration *audioConfiguration;
@property (nonatomic, strong) LFVideoConfiguration *videoConfiguration;

@end
