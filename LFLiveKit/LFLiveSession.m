//
//  LFLiveSession.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFLiveSession.h"

#import "LFVideoCapture.h"
#import "LFAudioCapture.h"
#import "LFHardwareVideoEncoder.h"
#import "LFHardwareAudioEncoder.h"
#import "LFStreamRTMPSocket.h"


@interface LFLiveSession () <LFAudioCaptureDelegate, LFVideoCaptureDelegate, LFAudioEncodingDelegate, LFVideoEncodingDelegate, LFStreamSocketDelegate>

/// 音频配置
@property (nonatomic, strong) LFAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) LFVideoConfiguration *videoConfiguration;
/// 声音采集
@property (nonatomic, strong) LFAudioCapture *audioCaptureSource;
/// 视频采集
@property (nonatomic, strong) LFVideoCapture *videoCaptureSource;
/// 音频编码
@property (nonatomic, strong) id<LFAudioEncoding> audioEncoder;
/// 视频编码
@property (nonatomic, strong) id<LFVideoEncoding> videoEncoder;
/// 上传
@property (nonatomic, strong) id<LFStreamSocket> socket;


#pragma mark -- 内部标识
/// 调试信息
@property (nonatomic, strong) LFLiveDebug *debugInfo;
/// 流信息
@property (nonatomic, strong) LFStreamInfo *streamInfo;
/// 是否开始上传
@property (nonatomic, assign) BOOL uploading;
/// 当前状态
@property (nonatomic, assign, readwrite) LFLiveState state;
/// 当前直播type
@property (nonatomic, assign, readwrite) LFCaptureTypeMask captureType;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;


@end

/**  时间戳 */
#define NOW (CACurrentMediaTime() * 1000)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface LFLiveSession ()

/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 音视频是否对齐
@property (nonatomic, assign) BOOL AVAlignment;
/// 当前是否采集到了音频
@property (nonatomic, assign) BOOL hasCaptureAudio;
/// 当前是否采集到了关键帧
@property (nonatomic, assign) BOOL hasKeyFrameVideo;

@end

@implementation LFLiveSession

- (instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)audioConfiguration
						videoConfiguration:(nullable LFVideoConfiguration *)videoConfiguration
{
    return [self initWithAudioConfiguration:audioConfiguration
						 videoConfiguration:videoConfiguration
								captureType:LFCaptureMaskDefault];
}

- (nullable instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)audioConfiguration
								 videoConfiguration:(nullable LFVideoConfiguration *)videoConfiguration
										captureType:(LFCaptureTypeMask)captureType
{
	if (captureType & LFCaptureMaskAudio && !audioConfiguration) {
		@throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"audioConfiguration is nil " userInfo:nil];
	}
	if (captureType & LFCaptureMaskVideo && !videoConfiguration) {
		@throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"videoConfiguration is nil " userInfo:nil];
	}

    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _adaptiveBitrate = NO;
        _captureType = captureType;
    }
    return self;
}

- (void)dealloc {
    _videoCaptureSource.running = NO;
    _audioCaptureSource.running = NO;
}

#pragma mark -- CustomMethod
- (void)startLive:(LFStreamInfo *)streamInfo {
    if (!streamInfo) return;
    _streamInfo = streamInfo;
    _streamInfo.videoConfiguration = _videoConfiguration;
    _streamInfo.audioConfiguration = _audioConfiguration;
    [self.socket start];
}

- (void)stopLive {
    self.uploading = NO;
    [self.socket stop];
    self.socket = nil;
}

- (NSInteger)currentVideoBitrate
{
	return self.videoEncoder.videoBitrate;
}

- (void)setVideoBitrate:(NSInteger)bitrate
{
    self.videoEncoder.videoBitrate = bitrate;
    NSLog(@"Moved bitrate %@", @(bitrate));
}

#pragma mark -- PrivateMethod
- (void)pushSendBuffer:(LFFrame*)frame
{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

#pragma mark -- CaptureDelegate
- (void)captureOutput:(nullable LFAudioCapture *)capture audioData:(nullable NSData*)audioData {
    if (self.uploading) [self.audioEncoder encodeAudioData:audioData timeStamp:NOW];
}

- (void)captureOutput:(nullable LFVideoCapture *)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer {
    if (self.uploading) [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
}

#pragma mark -- EncoderDelegate
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame {
    //上传  时间戳对齐
    if (self.uploading) {
        self.hasCaptureAudio = YES;
        if (self.AVAlignment) [self pushSendBuffer:frame];
    }
}

- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame {
    //上传 时间戳对齐
    if (self.uploading){
        if(frame.isKeyFrame && self.hasCaptureAudio) self.hasKeyFrameVideo = YES;
        if (self.AVAlignment) [self pushSendBuffer:frame];
    }
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    if (status == LFLiveStateStart) {
        if (!self.uploading) {
            self.AVAlignment = NO;
            self.hasCaptureAudio = NO;
            self.hasKeyFrameVideo = NO;
            self.relativeTimestamps = 0;
            self.uploading = YES;
        }
    } else if(status == LFLiveStateStop || status == LFLiveStateError) {
        self.uploading = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = status;
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:liveStateDidChange:)]) {
            [self.delegate liveSession:self liveStateDidChange:status];
        }
    });
}

- (void)socketDidError:(nullable id<LFStreamSocket>)socket error:(LFLiveSocketError)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:socketError:)]) {
            [self.delegate liveSession:self socketError:error];
        }
    });
}

- (void)socketDebug:(nullable id<LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo {
    self.debugInfo = debugInfo;
    if (self.showDebugInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:debugInfo:)]) {
                [self.delegate liveSession:self debugInfo:debugInfo];
            }
        });
    }
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFBufferState)status
{
    if (self.captureType & LFCaptureMaskVideo && self.adaptiveBitrate) {
        NSUInteger videoBitrate = [self.videoEncoder videoBitrate];
        if (status == LFBufferStateEmptying) {
            if (videoBitrate < _videoConfiguration.videoMaxBitrate) {
                videoBitrate = videoBitrate + 50 * 1000;
                [self.videoEncoder setVideoBitrate:videoBitrate];
                NSLog(@"Increase bitrate %@", @(videoBitrate));
            }
        } else {
            if (videoBitrate > self.videoConfiguration.videoMinBitrate) {
                videoBitrate = videoBitrate - 100 * 1000;
                [self.videoEncoder setVideoBitrate:videoBitrate];
                NSLog(@"Decrease bitrate %@", @(videoBitrate));
            }
        }
    }
}

#pragma mark -- Getter Setter
- (void)setRunning:(BOOL)running
{
    if (_running == running) return;
    _running = running;

	self.videoCaptureSource.running = _running;
    self.audioCaptureSource.running = _running;

    // when stop running => stop recording too
	if (!_running) {
		self.recording = _running;
	}
}

- (void)setRecording:(BOOL)recording
{
	if (_recording == recording) return;
	_recording = recording;

    // if not running, when start recording => start running too
    if (!_running) {
        self.running = _recording;
    }

	self.videoCaptureSource.recording = _recording;
}

- (void)setPreviewView:(UIView *)previewView
{
    [self.videoCaptureSource setPreviewView:previewView];
}

- (UIView *)previewView {
    return self.videoCaptureSource.previewView;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition
{
    [self.videoCaptureSource setCaptureDevicePosition:captureDevicePosition];
}

- (AVCaptureDevicePosition)captureDevicePosition
{
    return self.videoCaptureSource.captureDevicePosition;
}

- (BOOL)saveLocalVideo
{
    return self.videoCaptureSource.saveLocalVideo;
}

- (void)setSaveLocalVideo:(BOOL)saveLocalVideo
{
    [self.videoCaptureSource setSaveLocalVideo:saveLocalVideo];
}

- (NSURL *)saveLocalVideoUrl
{
    return self.videoCaptureSource.saveLocalVideoUrl;
}

- (void)setSaveLocalVideoUrl:(NSURL *)saveLocalVideoUrl
{
    [self.videoCaptureSource setSaveLocalVideoUrl:saveLocalVideoUrl];
}

- (void (^)(NSURL *fileUrl))saveLocalVideoCompletionHandler
{
	return self.videoCaptureSource.saveLocalVideoCompletionHandler;
}

- (void)setSaveLocalVideoCompletionHandler:(void (^)(NSURL *))saveLocalVideoCompletionHandler
{
	self.videoCaptureSource.saveLocalVideoCompletionHandler = saveLocalVideoCompletionHandler;
}

- (void)setStabilization:(BOOL)stabilization
{
	self.videoCaptureSource.stabilization = stabilization;
}

- (BOOL)stabilization
{
	return self.videoCaptureSource.stabilization;
}

- (void)setZoomScale:(CGFloat)zoomScale
			 ramping:(BOOL)ramping
{
	[self.videoCaptureSource setZoomScale:zoomScale ramping:ramping];
}

- (void)setZoomScale:(CGFloat)zoomScale
{
	[self.videoCaptureSource setZoomScale:zoomScale ramping:YES];
}

- (CGFloat)zoomScale
{
    return self.videoCaptureSource.zoomScale;
}

- (void)setTorch:(BOOL)torch
{
    [self.videoCaptureSource setTorch:torch];
}

- (BOOL)torch
{
    return self.videoCaptureSource.torch;
}

- (void)setMirror:(BOOL)mirror
{
    [self.videoCaptureSource setMirror:mirror];
}

- (BOOL)mirror
{
    return self.videoCaptureSource.mirror;
}

- (void)setMuted:(BOOL)muted
{
    [self.audioCaptureSource setMuted:muted];
}

- (BOOL)muted
{
    return self.audioCaptureSource.muted;
}

- (nullable UIImage *)currentImage
{
    return self.videoCaptureSource.currentImage;
}

- (LFAudioCapture *)audioCaptureSource
{
    if (!_audioCaptureSource) {
        if (self.captureType & LFCaptureMaskAudio) {
            _audioCaptureSource = [[LFAudioCapture alloc] initWithAudioConfiguration:_audioConfiguration];
            _audioCaptureSource.delegate = self;
        }
    }
    return _audioCaptureSource;
}

- (LFVideoCapture *)videoCaptureSource
{
    if (!_videoCaptureSource) {
        if(self.captureType & LFCaptureMaskVideo){
            _videoCaptureSource = [[LFVideoCapture alloc] initWithVideoConfiguration:_videoConfiguration];
            _videoCaptureSource.delegate = self;
        }
    }
    return _videoCaptureSource;
}

- (id<LFAudioEncoding>)audioEncoder
{
    if (!_audioEncoder) {
        _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioConfiguration:_audioConfiguration];
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (id<LFVideoEncoding>)videoEncoder
{
    if (!_videoEncoder) {
		_videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        [_videoEncoder setDelegate:self];
    }
    return _videoEncoder;
}

- (id<LFStreamSocket>)socket
{
    if (!_socket) {
        _socket = [[LFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:self.reconnectInterval reconnectCount:self.reconnectCount];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (LFStreamInfo *)streamInfo
{
    if (!_streamInfo) {
        _streamInfo = [[LFStreamInfo alloc] init];
    }
    return _streamInfo;
}

- (dispatch_semaphore_t)lock
{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp
{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (BOOL)AVAlignment
{
    if (self.captureType & LFCaptureMaskAudio &&
		self.captureType & LFCaptureMaskVideo) {
		if (self.hasCaptureAudio && self.hasKeyFrameVideo) {
			return YES;
		} else {
			return NO;
		}
    }
	return YES;
}

@end
