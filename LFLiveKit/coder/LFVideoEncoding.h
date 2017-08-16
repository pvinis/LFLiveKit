//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LFVideoFrame.h"
#import "LFVideoConfiguration.h"


@protocol LFVideoEncoding;


// encoder work after callback
@protocol LFVideoEncodingDelegate <NSObject>

@required
- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame;

@end


// encoder interface
@protocol LFVideoEncoding <NSObject>

@required
- (void)encodeVideoData:(nullable CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;

@optional
@property (nonatomic, assign) NSInteger videoBitrate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable LFVideoConfiguration *)configuration;
- (void)setDelegate:(nullable id<LFVideoEncodingDelegate>)delegate;
- (void)stopEncoder;

@end
