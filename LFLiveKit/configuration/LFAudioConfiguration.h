//
//  LFAudioConfiguration.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM (NSUInteger, LFAudioBitrate) {
    LFAudioBitrate32Kbps  = 32000,
    LFAudioBitrate64Kbps  = 64000,
    LFAudioBitrate96Kbps  = 96000,
    LFAudioBitrate128Kbps = 128000,
    LFAudioBitrateDefault = LFAudioBitrate96Kbps,
};


typedef NS_ENUM (NSUInteger, LFAudioSampleRate) {
    LFAudioSampleRate16000Hz = 16000,
    LFAudioSampleRate44100Hz = 44100,
    LFAudioSampleRate48000Hz = 48000,
    LFAudioSampleRateDefault = LFAudioSampleRate44100Hz,
};


typedef NS_ENUM (NSUInteger, LFAudioQuality) {
    /// 低音频质量 audio sample rate: 16KHz audio bitrate: numberOfChannels 1 : 32Kbps  2 : 64Kbps
    LFAudioQualityLow = 0,
    /// 中音频质量 audio sample rate: 44.1KHz audio bitrate: 96Kbps
    LFAudioQualityMedium = 1,
    /// 高音频质量 audio sample rate: 44.1MHz audio bitrate: 128Kbps
    LFAudioQualityHigh = 2,
    /// 超高音频质量 audio sample rate: 48KHz, audio bitrate: 128Kbps
    LFAudioQualityVeryHigh = 3,
    /// 默认音频质量 audio sample rate: 44.1KHz, audio bitrate: 96Kbps
    LFAudioQualityDefault = LFAudioQualityHigh,
};


@interface LFAudioConfiguration : NSObject <NSCoding, NSCopying>

+ (instancetype)defaultConfiguration;
+ (instancetype)defaultConfigurationForQuality:(LFAudioQuality)audioQuality;

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/// 声道数目(default 2)
@property (nonatomic, assign) NSUInteger numberOfChannels;
/// 采样率
@property (nonatomic, assign) LFAudioSampleRate audioSampleRate;
/// 码率
@property (nonatomic, assign) LFAudioBitrate audioBitrate;
/// flv编码音频头 44100 为0x12 0x10
@property (nonatomic, assign, readonly) char *asc;
/// 缓存区长度
@property (nonatomic, assign,readonly) NSUInteger bufferLength;

@end
