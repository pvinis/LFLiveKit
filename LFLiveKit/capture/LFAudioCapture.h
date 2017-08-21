//
//  LFAudioCapture.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LFAudioConfiguration.h"

#pragma mark -- AudioCaptureNotification
extern NSString *_Nullable const LFAudioComponentFailedToCreateNotification;

@class LFAudioCapture;


@protocol LFAudioCaptureDelegate <NSObject>

- (void)captureOutput:(nullable LFAudioCapture *)capture audioData:(nullable NSData*)audioData;

@end


@interface LFAudioCapture : NSObject

@property (nullable, nonatomic, weak) id<LFAudioCaptureDelegate> delegate;

@property (nonatomic, assign) BOOL muted;

// The running control start capture or stop capture
@property (nonatomic, assign) BOOL running;

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFAudioConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end
