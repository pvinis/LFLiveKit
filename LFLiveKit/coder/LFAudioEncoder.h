//
//  LFAudioEncoder.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFAudioFrame.h"
#import "LFLiveAudioConfiguration.h"

@protocol LFAudioEncoder;


@protocol LFAudioEncoderDelegate <NSObject>
@required
- (void)audioEncoder:(nullable id<LFAudioEncoder>)encoder audioFrame:(nullable LFAudioFrame *)frame;
@end


@protocol LFAudioEncoder <NSObject>
@required
- (void)encodeAudioData:(nullable NSData *)audioData timeStamp:(uint64_t)timeStamp;
@optional
- (nullable instancetype)initWithAudioStreamConfiguration:(nullable LFLiveAudioConfiguration *)configuration;
- (void)setDelegate:(nullable id<LFAudioEncoderDelegate>)delegate;
- (nullable NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
@end
