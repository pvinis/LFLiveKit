//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"
#import "LFGPUImageEmptyFilter.h"

#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@interface LFVideoCapture ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@end

@implementation LFVideoCapture {
  BOOL usingTele;
  BOOL usingDual;
}

@synthesize brightLevel = _brightLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
    if(_gpuImageView){
        dispatch_block_t block = ^{
            [_gpuImageView removeFromSuperview];
            _gpuImageView = nil;
        };
        if ([NSThread isMainThread]) {
            block();
        } else {
            dispatch_sync(dispatch_get_main_queue(), block);
        }
    }
}

#pragma mark -- Setter Getter

- (GPUImageVideoCamera *)videoCamera{
    if(!_videoCamera){
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionBack];
      if ([_videoCamera isBuiltInDualCameraPresent]) {
        [_videoCamera switchToDualCamera];
      }
        _videoCamera.outputImageOrientation = _configuration.outputImageOrientation;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    }
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.videoCamera stopCameraCapture];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
    }
}

- (void)setRecording:(BOOL)recording {
  if (_recording == recording) return;
  _recording = recording;
  
  if (_recording) {
    [self.movieWriter startRecording];
  } else {
    [self.movieWriter finishRecording];
  }
}

- (void)setPreviewView:(UIView *)previewView
{
  if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
  [previewView insertSubview:self.gpuImageView atIndex:0];
  self.gpuImageView.frame = CGRectMake(0, 0, previewView.frame.size.width, previewView.frame.size.height);
}

- (UIView *)previewView
{
  return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition
{
  if (captureDevicePosition == self.videoCamera.cameraPosition) return;
  [self.videoCamera rotateCamera];
}

- (AVCaptureDevicePosition)captureDevicePosition
{
    return self.videoCamera.cameraPosition;
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setStabilization:(BOOL)stabilization
{
    self.videoCamera.videoCaptureConnection.preferredVideoStabilizationMode = (stabilization ? AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff);
}

- (BOOL)stabilization
{
    return (self.videoCamera.videoCaptureConnection.preferredVideoStabilizationMode != AVCaptureVideoStabilizationModeStandard);
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
  [self setZoomScale:zoomScale ramping:NO];
}

- (void)setZoomScale:(CGFloat)zoomScale ramping:(BOOL)ramping {
	if (self.videoCamera && self.videoCamera.inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
        if ([device lockForConfiguration:nil]) {
          if (ramping) {
            [device rampToVideoZoomFactor:zoomScale withRate:2.];
          } else {
            device.videoZoomFactor = zoomScale;
          }
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}


- (GPUImageView *)gpuImageView{
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;
}

-(UIImage *)currentImage{
    if(_filter){
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter*)movieWriter{
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.saveLocalVideoPath] size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
//        _movieWriter.shouldPassthroughAudio = YES; /// commented this out. its messing with the audio.
// specifically, when streaming and recording at the same time, the audio on the recording is fine but on the stream its cutting of every other second.
// without the above line, its fine for both.
        self.videoCamera.audioEncodingTarget = self.movieWriter;
    }
    return _movieWriter;
}

#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)reloadFilter{
    [self.filter removeAllTargets];
    [self.videoCamera removeAllTargets];
    [self.output removeAllTargets];
    

    self.output = [[LFGPUImageEmptyFilter alloc] init];
    self.filter = [[LFGPUImageEmptyFilter alloc] init];

  
    [self.videoCamera addTarget:self.filter];
  
  
    [self.filter addTarget:self.output];
    [self.output addTarget:self.gpuImageView];
    if(self.saveLocalVideo) [self.output addTarget:self.movieWriter];
  
  
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
  
    
    //< 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    NSLog(@"UIApplicationWillChangeStatusBarOrientationNotification. UserInfo: %@", notification.userInfo);
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];

    if(self.configuration.autorotate){
        if (self.configuration.landscape) {
            if (statusBar == UIInterfaceOrientationLandscapeLeft) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
            } else if (statusBar == UIInterfaceOrientationLandscapeRight) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
            }
        } else {
            if (statusBar == UIInterfaceOrientationPortrait) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortraitUpsideDown;
            } else if (statusBar == UIInterfaceOrientationPortraitUpsideDown) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
            }
        }
    }
}

@end
