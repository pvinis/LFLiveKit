//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFStreamInfo.h"
#import "LFStreamingBuffer.h"
#import "LFLiveDebug.h"



@protocol LFStreamSocket;
@protocol LFStreamSocketDelegate <NSObject>

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveBufferState)status;
/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveState)status;
/** callback socket error */
- (void)socketDidError:(nullable id <LFStreamSocket>)socket error:(LFLiveSocketError)error;
@optional
/** callback debugInfo */
- (void)socketDebug:(nullable id <LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo;
@end

@protocol LFStreamSocket <NSObject>
- (void)start;
- (void)stop;
- (void)sendFrame:(nullable LFFrame *)frame;
- (void)setDelegate:(nullable id <LFStreamSocketDelegate>)delegate;
@optional
- (nullable instancetype)initWithStream:(nullable LFStreamInfo *)stream;
- (nullable instancetype)initWithStream:(nullable LFStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount;
@end
