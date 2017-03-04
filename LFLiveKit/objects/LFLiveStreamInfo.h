//
//  LFLiveStreamInfo.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFLiveAudioConfiguration.h"
#import "LFLiveVideoConfiguration.h"

typedef NS_ENUM (NSUInteger, LFLiveState) {
  LFLiveReady = 0,
  LFLivePending ,
  LFLiveStart,
  LFLiveStop,
  LFLiveError,
  LFLiveRefresh,
};

typedef NS_ENUM (NSUInteger, LFLiveSocketErrorCode) {
  LFLiveSocketErrorPreview = 201,
  LFLiveSocketErrorGetStreamInfo,
  LFLiveSocketErrorConnectSocket,
  LFLiveSocketErrorVerification,
  LFLiveSocketErrorReconnectTimeout,
};

@interface LFLiveStreamInfo : NSObject

@property (nonatomic, copy) NSString *streamId;

#pragma mark - FLV
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
#pragma mark - RTMP
@property (nonatomic, copy) NSString *url;

@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;
@property (nonatomic, strong) LFLiveVideoConfiguration *videoConfiguration;

@end
