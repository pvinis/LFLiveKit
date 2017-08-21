//
//  LFAudioEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LFAudioFrame.h"
#import "LFAudioConfiguration.h"


@protocol LFAudioEncoding;


// get frame back after encoding
@protocol LFAudioEncodingDelegate <NSObject>

@required
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame;

@end


// encoder interface
@protocol LFAudioEncoding <NSObject>

@required
- (void)encodeAudioData:(nullable NSData*)audioData timeStamp:(uint64_t)timeStamp;

@optional
- (nullable instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)configuration;
- (void)setDelegate:(nullable id<LFAudioEncodingDelegate>)delegate;
- (nullable NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
- (void)stopEncoder;

@end
