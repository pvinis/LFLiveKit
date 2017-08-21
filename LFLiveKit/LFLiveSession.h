//
//  LFLiveSession.h
//  LFLiveKit
//
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "LFStreamInfo.h"
#import "LFVideoFrame.h"
#import "LFAudioConfiguration.h"
#import "LFVideoConfiguration.h"
#import "LFLiveDebug.h"


typedef NS_ENUM(NSInteger, LFCaptureType) {
    LFCaptureAudio,  // capture only audio
    LFCaptureVideo,  // capture only video
};



typedef NS_OPTIONS(NSInteger, LFCaptureTypeMask) {
    LFCaptureMaskAudio   = 1 << LFCaptureAudio,                      // only inner capture audio (no video)
    LFCaptureMaskVideo   = 1 << LFCaptureVideo,                      // only inner capture video (no audio)
    LFCaptureMaskAll     = LFCaptureMaskAudio | LFCaptureMaskVideo,  // inner capture audio and video
    LFCaptureMaskDefault = LFCaptureMaskAll,                         // default is inner capture audio and video
};


@class LFLiveSession;


@protocol LFLiveSessionDelegate <NSObject>

@optional
// live status changed will callback
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state;
// live debug info callback
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo;
// callback socket error
- (void)liveSession:(nullable LFLiveSession *)session socketError:(LFLiveSocketError)socketError;

@end


@interface LFLiveSession : NSObject

@property (nullable, nonatomic, weak) id<LFLiveSessionDelegate> delegate;

// The running control start capture or stop capture
@property (nonatomic, assign) BOOL running;

// The previewView will show OpenGL ES view
@property (nonatomic, strong, null_resettable) UIView *previewView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

@property (nonatomic, assign) BOOL stabilization;

// The torch control camera zoom scale default 1.0, between 1.0 ~ 3.0
@property (nonatomic, assign) CGFloat zoomScale;
- (void)setZoomScale:(CGFloat)zoomScale
			 ramping:(BOOL)ramping;

/** The torch control capture flash is on or off */
@property (nonatomic, assign) BOOL torch;

/** The mirror control mirror of front camera is on or off */
@property (nonatomic, assign) BOOL mirror;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic, assign) BOOL muted;

/*  The adaptiveBitrate control auto adjust bitrate. Default is NO */
@property (nonatomic, assign) BOOL adaptiveBitrate;

/** The stream control upload and package*/
@property (nullable, nonatomic, strong, readonly) LFStreamInfo *streamInfo;

/** The status of the stream .*/
@property (nonatomic, assign, readonly) LFLiveState state;

/** The captureType control inner or outer audio and video .*/
@property (nonatomic, assign, readonly) LFCaptureTypeMask captureType;

/** The showDebugInfo control streamInfo and uploadInfo(1s) *.*/
@property (nonatomic, assign) BOOL showDebugInfo;

/** The reconnectInterval control reconnect timeInterval(重连间隔) *.*/
@property (nonatomic, assign) NSUInteger reconnectInterval;

/** The reconnectCount control reconnect count (重连次数) *.*/
@property (nonatomic, assign) NSUInteger reconnectCount;

/* The currentImage is videoCapture shot */
@property (nonatomic, strong,readonly ,nullable) UIImage *currentImage;

/* The saveLocalVideo is save the local video */
@property (nonatomic, assign) BOOL saveLocalVideo;

/* The saveLocalVideoPath is save the local video url */
@property (nonatomic, strong, nullable) NSURL *saveLocalVideoUrl;

@property (nonatomic, copy, nullable) void (^saveLocalVideoCompletionHandler)(NSURL *fileUrl);

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)audioConfiguration
								 videoConfiguration:(nullable LFVideoConfiguration *)videoConfiguration;

/**
 The designated initializer. Multiple instances with the same configuration will make the
 capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)audioConfiguration
								 videoConfiguration:(nullable LFVideoConfiguration *)videoConfiguration
										captureType:(LFCaptureTypeMask)captureType NS_DESIGNATED_INITIALIZER;

/** The start stream .*/
- (void)startLive:(nonnull LFStreamInfo *)streamInfo;

/** The stop stream .*/
- (void)stopLive;

/*
// support outer input yuv or rgb video(set LFLiveCaptureTypeMask) .
- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer;

// support outer input pcm audio(set LFLiveCaptureTypeMask) .
- (void)pushAudio:(nullable NSData*)audioData;
*/

- (void)setVideoBitrate:(NSInteger)bitrate;

@end

