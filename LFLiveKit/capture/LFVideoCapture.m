//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"

@interface LFVideoCapture ()

@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

//@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic) dispatch_queue_t sessionQueue;

@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;

@end

@implementation LFVideoCapture
@synthesize brightLevel = _brightLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];

        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.session stopRunning];
}


/////			if ( [UIDevice currentDevice].isMultitaskingSupported ) {
//////self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];


#pragma mark -- Setter Getter

- (dispatch_queue_t)sessionQueue
{
  if (!_sessionQueue) {
    _sessionQueue = dispatch_queue_create("session queueueueue", DISPATCH_QUEUE_SERIAL);
  }
  return _sessionQueue;
}

- (AVCaptureSession *)session
{
  if (!_session) {
    _session = [[AVCaptureSession alloc] init];
    self.previewView.session = _session;

    dispatch_async(self.sessionQueue, ^{
      [self configSession];
    });
  }
  return _session;
}

- (void)configSession
{
  [self.session beginConfiguration];

  self.session.sessionPreset = AVCaptureSessionPreset1280x720;////////

  AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera
                                                                    mediaType:AVMediaTypeVideo
                                                                     position:AVCaptureDevicePositionBack];
  if (!videoDevice) {
    videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                     mediaType:AVMediaTypeVideo
                                                      position:AVCaptureDevicePositionBack];
  }

  NSError *error = nil;
  AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                                                 error:&error];
  if (!videoDeviceInput) {
    NSLog(@"could not create device input: %@", error);
    [self.session commitConfiguration];
    return;
  }
  if ([self.session canAddInput:videoDeviceInput]) {
    [self.session addInput:videoDeviceInput];
    self.videoDeviceInput = videoDeviceInput;
    dispatch_async(dispatch_get_main_queue(), ^{

      UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
      AVCaptureVideoOrientation initialOrientation = AVCaptureVideoOrientationPortrait;/////////////////
      if (statusBarOrientation != UIInterfaceOrientationUnknown) {
        initialOrientation = (AVCaptureVideoOrientation)statusBarOrientation;//////////////
      }
      self.previewView.videoPreviewLayer.connection.videoOrientation = initialOrientation;
    });
  } else {
    NSLog(@"cannot add device input to session");
    ///setupResult = configFailed;
    [self.session commitConfiguration];
    return;
  }

  //////audiodevice?
  [self.session commitConfiguration];
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
      [self.session stopRunning];
        if(self.saveLocalVideo) [self.movieWriter finishRecording];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
      [self.session startRunning];
        if(self.saveLocalVideo) [self.movieWriter startRecording];
    }
}

- (AVCaptureDevicePosition)captureDevicePosition {
  return self.videoDeviceInput.device.position;
}

- (void)setStabilization:(BOOL)stabilization
{
  if (stabilization == self.stabilization) return;

  self.previewView.videoPreviewLayer.connection.preferredVideoStabilizationMode = (stabilization ?
                                                                                   AVCaptureVideoStabilizationModeStandard : AVCaptureVideoStabilizationModeOff);
}

- (BOOL)stabilization
{
  return (self.previewView.videoPreviewLayer.connection.preferredVideoStabilizationMode != AVCaptureVideoStabilizationModeStandard);
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
  AVCaptureDevice *device = self.videoDeviceInput.device;
  if ([device lockForConfiguration:nil]) {
    device.videoZoomFactor = zoomScale;
    [device unlockForConfiguration];
    _zoomScale = zoomScale;
  }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (GPUImageMovieWriter*)movieWriter{
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.saveLocalVideoPath] size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
        _movieWriter.shouldPassthroughAudio = YES;
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

//- (void)reloadFilter{
//    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
//        [_self processVideo:output];
//    }];
//}


#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
//    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
//    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

@end
