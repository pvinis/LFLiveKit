//
//  LFAudioCapture.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFLiveAudioConfiguration.h"

@class LFAudioCapture;

extern NSString *_Nullable const LFAudioComponentFailedToCreateNotification;


@protocol LFAudioCaptureDelegate <NSObject>

- (void)captureOutput:(nullable LFAudioCapture *)capture audioData:(nullable NSData*)audioData;

@end


@interface LFAudioCapture : NSObject

@property (nullable, nonatomic, weak) id<LFAudioCaptureDelegate> delegate;

@property (nonatomic, assign) BOOL muted;

@property (nonatomic, assign) BOOL running;

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end
