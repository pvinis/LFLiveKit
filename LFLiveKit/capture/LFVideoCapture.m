//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"

#import "LFLiveConstants.h"
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
@property (nonatomic, strong) LFVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@end


@implementation LFVideoCapture

@synthesize torch = _torch;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
		[self setZoomScale:1.0 ramping:NO];
        self.mirror = YES;
    }
    return self;
}

- (void)dealloc
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
    if(_gpuImageView){
        [_gpuImageView removeFromSuperview];
        _gpuImageView = nil;
    }
}

#pragma mark -- Setter Getter

- (GPUImageVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionBack];
        _videoCamera.outputImageOrientation = _configuration.outputImageOrientation;
        _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    }
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
	if (!_running) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[UIApplication sharedApplication].idleTimerDisabled = NO;
		});
        [self.videoCamera stopCameraCapture];

        // if not running, when start recording => start running too
		self.recording = _running;
    } else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[UIApplication sharedApplication].idleTimerDisabled = YES;
		});
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
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

	if (_recording) {
		if (self.saveLocalVideo) {
			[self.movieWriter startRecording];
		}
	} else {
		if (self.saveLocalVideo) {
			self.videoCamera.audioEncodingTarget = nil;
			GPUImageMovieWriter *targetToRemove = self.movieWriter;
			[self.movieWriter finishRecordingWithCompletionHandler:^{
				[self didFinishRecording];
				[NSNotificationCenter.defaultCenter postNotificationName:LFApplicationDidFinishRecordingNotification
																													object:nil];
			}];
			[self.output removeTarget:targetToRemove];
		}
	}
}

- (void)resetMovieWriter
{
	self.movieWriter = nil;
}

- (void)setPreviewView:(UIView *)previewView {
	if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
	[previewView insertSubview:self.gpuImageView atIndex:0];
	self.gpuImageView.frame = CGRectMake(0, 0, previewView.frame.size.width, previewView.frame.size.height);
}

- (UIView *)previewView
{
	return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == self.videoCamera.cameraPosition) return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self reloadMirror];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret = NO;
    if (!self.videoCamera.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.inputCamera) {
        if (self.videoCamera.inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.inputCamera lockForConfiguration:&err]) {
                [self.videoCamera.inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.inputCamera unlockForConfiguration];
                ret = (self.videoCamera.inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)setStabilization:(BOOL)stabilization
{
	if (self.videoCamera.videoCaptureConnection.isVideoStabilizationSupported) {
		self.videoCamera.videoCaptureConnection.preferredVideoStabilizationMode = (
			stabilization ?
			AVCaptureVideoStabilizationModeStandard :
			AVCaptureVideoStabilizationModeOff);
	}
}

- (BOOL)stabilization
{
	return !(self.videoCamera.videoCaptureConnection.preferredVideoStabilizationMode == AVCaptureVideoStabilizationModeOff);
}

- (void)setZoomScale:(CGFloat)zoomScale
			 ramping:(BOOL)ramping
{
	if (self.videoCamera && self.videoCamera.inputCamera) {
		AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
		if ([device lockForConfiguration:nil]) {
			if (ramping) {
				CGFloat next = MIN(device.activeFormat.videoMaxZoomFactor, 2.0);
				[device rampToVideoZoomFactor:zoomScale withRate:next];
			} else {
				device.videoZoomFactor = zoomScale;
			}
			[device unlockForConfiguration];
			_zoomScale = zoomScale;
		}
	}
}

- (void)setZoomScale:(CGFloat)zoomScale
{
	[self setZoomScale:zoomScale ramping:YES];
}

- (CGFloat)zoomScale
{
    return _zoomScale;
}

- (void)focusAtPoint:(CGPoint)point
{
	AVCaptureDevice *camera = self.videoCamera.inputCamera;

	NSError *err = nil;
	if ([camera lockForConfiguration:&err]) {
		if ([camera isFocusPointOfInterestSupported]) {
			[camera setFocusPointOfInterest:point];
		}
		if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
			camera.focusMode = AVCaptureFocusModeAutoFocus;
		}

		if ([camera isExposurePointOfInterestSupported]) {
			[camera setExposurePointOfInterest:point];
		}
		if ([camera isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
			camera.exposureMode = AVCaptureExposureModeAutoExpose;
		}

		[camera unlockForConfiguration];
	}
}

- (void)autofocus
{
	AVCaptureDevice *camera = self.videoCamera.inputCamera;

	NSError *err = nil;
	if ([camera lockForConfiguration:&err]) {
		if ([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
			camera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
		}

		if ([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
			camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
		}

		[camera unlockForConfiguration];
	}
}

- (GPUImageView *)gpuImageView
{
    if (!_gpuImageView) {
		__block GPUImageView *view;
		if ([NSThread isMainThread]) {
			view = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
			[view setFillMode:kGPUImageFillModePreserveAspectRatio];
			[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		} else {
			dispatch_sync(dispatch_get_main_queue(), ^{
				view = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
				[view setFillMode:kGPUImageFillModePreserveAspectRatio];
				[view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
			});
		}
		_gpuImageView = view;
    }
    return _gpuImageView;
}

- (UIImage *)currentImage
{
    if (_filter) {
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter *)movieWriter
{
	if (!_movieWriter) {
		_movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoUrl size:self.configuration.videoSize];
		_movieWriter.encodingLiveVideo = YES;
		_movieWriter.shouldPassthroughAudio = YES;
		self.videoCamera.audioEncodingTarget = self.movieWriter;
		[self.output addTarget:self.movieWriter];
	}
	return _movieWriter;
}

- (void)didFinishRecording
{
	if (self.saveLocalVideoCompletionHandler) {
		self.saveLocalVideoCompletionHandler(self.movieWriter.movieURL);
	}

	_movieWriter = nil;
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

- (void)reloadFilter {
	[self.filter removeAllTargets];
	[self.videoCamera removeAllTargets];
	[self.output removeAllTargets];

	self.output = [[LFGPUImageEmptyFilter alloc] init];
	self.filter = [[LFGPUImageEmptyFilter alloc] init];

	/// 调节镜像
	[self reloadMirror];

	[self.videoCamera addTarget:self.filter];

	[self.filter addTarget:self.output];
	[self.output addTarget:self.gpuImageView];
	if (self.saveLocalVideo) self.movieWriter;

	[self.filter forceProcessingAtSize:self.configuration.videoSize];
	[self.output forceProcessingAtSize:self.configuration.videoSize];

	// 输出数据
	__weak typeof(self) _self = self;
	[self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
		[_self processVideo:output];
	}];
}

- (void)reloadMirror {
	if (self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront) {
		self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
	} else {
		self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
	}
}

#pragma mark Notification

- (void)didEnterBackground:(NSNotification *)notification
{
	if (!self.running) return;

	UIApplication.sharedApplication.idleTimerDisabled = NO;
	[self.videoCamera pauseCameraCapture];
	runSynchronouslyOnVideoProcessingQueue(^{
		glFinish();
	});
}

- (void)willEnterForeground:(NSNotification *)notification
{
	if (!self.running) return;

	[self.videoCamera resumeCameraCapture];
	UIApplication.sharedApplication.idleTimerDisabled = YES;

	[NSNotificationCenter.defaultCenter postNotificationName:LFApplicationWillEnterForegroundNotification object:nil];
}

- (void)statusBarChanged:(NSNotification *)notification
{
    NSLog(@"UIApplicationWillChangeStatusBarOrientationNotification. UserInfo: %@", notification.userInfo);
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];

    if (self.configuration.autorotate) {
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
