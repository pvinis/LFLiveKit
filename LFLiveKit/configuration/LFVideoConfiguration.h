//
//  LFVideoConfiguration.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


typedef NS_ENUM (NSUInteger, LFVideoSessionPreset) {
    /// 低分辨率
    LFCaptureSessionPreset360x640 = 0,
    /// 中分辨率
    LFCaptureSessionPreset540x960 = 1,
    /// 高分辨率
    LFCaptureSessionPreset720x1280 = 2,
};


typedef NS_ENUM (NSUInteger, LFVideoQuality) {
    /// 分辨率： 360 *640 帧数：15 码率：500Kps
    LFVideoQualityLow1 = 0,
    /// 分辨率： 360 *640 帧数：24 码率：800Kps
    LFVideoQualityLow2 = 1,
    /// 分辨率： 360 *640 帧数：30 码率：800Kps
    LFVideoQualityLow3 = 2,
    /// 分辨率： 540 *960 帧数：15 码率：800Kps
    LFVideoQualityMedium1 = 3,
    /// 分辨率： 540 *960 帧数：24 码率：800Kps
    LFVideoQualityMedium2 = 4,
    /// 分辨率： 540 *960 帧数：30 码率：800Kps
    LFVideoQualityMedium3 = 5,
    /// 分辨率： 720 *1280 帧数：15 码率：1000Kps
    LFVideoQualityHigh1 = 6,
    /// 分辨率： 720 *1280 帧数：24 码率：1200Kps
    LFVideoQualityHigh2 = 7,
    /// 分辨率： 720 *1280 帧数：30 码率：1200Kps
    LFVideoQualityHigh3 = 8,
    /// 默认配置
    LFVideoQualityDefault = LFVideoQualityLow2,
};


@interface LFVideoConfiguration : NSObject<NSCoding, NSCopying>

+ (instancetype)defaultConfiguration;
+ (instancetype)defaultConfigurationForQuality:(LFVideoQuality)videoQuality;

/// 视频配置(质量 & 是否是横屏)
+ (instancetype)defaultConfigurationForQuality:(LFVideoQuality)videoQuality outputImageOrientation:(UIInterfaceOrientation)outputImageOrientation;

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/// 视频的分辨率，宽高务必设定为 2 的倍数，否则解码播放时可能出现绿边(这个videoSizeRespectingAspectRatio设置为YES则可能会改变)
@property (nonatomic, assign) CGSize videoSize;

/// 输出图像是否等比例,默认为NO
@property (nonatomic, assign) BOOL videoSizeRespectingAspectRatio;

/// 视频输出方向
@property (nonatomic, assign) UIInterfaceOrientation outputImageOrientation;

/// 自动旋转(这里只支持 left 变 right  portrait 变 portraitUpsideDown)
@property (nonatomic, assign) BOOL autorotate;

/// 视频的帧率，即 fps
@property (nonatomic, assign) NSUInteger videoFrameRate;

/// 视频的最大帧率，即 fps
@property (nonatomic, assign) NSUInteger videoMaxFrameRate;

/// 视频的最小帧率，即 fps
@property (nonatomic, assign) NSUInteger videoMinFrameRate;

/// 最大关键帧间隔，可设定为 fps 的2倍，影响一个 gop 的大小
@property (nonatomic, assign) NSUInteger videoMaxKeyframeInterval;

/// 视频的码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoBitrate;

/// 视频的最大码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoMaxBitrate;

/// 视频的最小码率，单位是 bps
@property (nonatomic, assign) NSUInteger videoMinBitrate;

/// 分辨率
@property (nonatomic, assign) LFVideoSessionPreset sessionPreset;

/// ≈sde3分辨率
@property (nonatomic, assign, readonly) NSString *avSessionPreset;

/// 是否是横屏
@property (nonatomic, assign, readonly) BOOL landscape;

@end
