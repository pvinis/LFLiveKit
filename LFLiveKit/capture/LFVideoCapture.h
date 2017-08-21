//
//  LFVideoCapture.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "LFVideoConfiguration.h"

@class LFVideoCapture;


@protocol LFVideoCaptureDelegate <NSObject>

- (void)captureOutput:(nullable LFVideoCapture *)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer;

@end


@interface LFVideoCapture : NSObject

@property (nullable, nonatomic, weak) id<LFVideoCaptureDelegate> delegate;

// The running control start capture or stop capture
@property (nonatomic, assign) BOOL running;

/** The previewView will show OpenGL ES view*/
@property (null_resettable, nonatomic, strong) UIView *previewView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/** The torch control capture flash is on or off */
@property (nonatomic, assign) BOOL torch;

/** The mirror control mirror of front camera is on or off */
@property (nonatomic, assign) BOOL mirror;

@property (nonatomic, assign) BOOL stabilization;

/** The torch control camera zoom scale default 1.0, between 1.0 ~ 3.0 */
@property (nonatomic, assign) CGFloat zoomScale;
- (void)setZoomScale:(CGFloat)zoomScale
			 ramping:(BOOL)ramping;

/** The videoFrameRate control videoCapture output data count */
@property (nonatomic, assign) NSInteger videoFrameRate;

/* The currentImage is videoCapture shot */
@property (nonatomic, strong, nullable) UIImage *currentImage;

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
- (nullable instancetype)initWithVideoConfiguration:(nullable LFVideoConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end
