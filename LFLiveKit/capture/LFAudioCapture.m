//
//  LFAudioCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFAudioCapture.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NSString *const LFAudioComponentFailedToCreateNotification = @"LFAudioComponentFailedToCreateNotification";


@interface LFAudioCapture ()

@property (nonatomic, assign) AudioComponentInstance componentInstance;
@property (nonatomic, assign) AudioComponent component;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, strong, nullable) LFLiveAudioConfiguration *configuration;

@end


@implementation LFAudioCapture

- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)configuration
{
  if (self = [super init]) {
        _configuration = configuration;
        _running = NO;
        _taskQueue = dispatch_queue_create("com.youku.Laifeng.audioCapture.Queue", NULL);
        
        AVAudioSession *session = [AVAudioSession sharedInstance];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:session];

    /// [session setPreferredSampleRate:_configuration.audioSampleRate error:nil]; needed?
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
    [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];
    /// [session setActive:YES error:nil]; needed?
    
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO; ///// use voice processing subtype for more silent?
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;

    _component = AudioComponentFindNext(NULL, &acd);
  
    OSStatus status = noErr;
    status = AudioComponentInstanceNew(_component, &_componentInstance);

    if (noErr != status) {
      [self handleAudioComponentCreationFailure];
    }

    UInt32 flagOne = 1;
    
    AudioUnitSetProperty(_componentInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    
    AudioStreamBasicDescription desc = {0};
    desc.mSampleRate = _configuration.audioSampleRate;
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    desc.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;
    desc.mFramesPerPacket = 1;
    desc.mBitsPerChannel = 16;
    desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
    desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void *)(self);
    cb.inputProc = handleInputBuffer;
    AudioUnitSetProperty(_componentInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
    AudioUnitSetProperty(_componentInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
    
    status = AudioUnitInitialize(_componentInstance);

    if (noErr != status) {
      [self handleAudioComponentCreationFailure];
    }
  }
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  dispatch_sync(self.taskQueue, ^{
    if (self.componentInstance) {
      self.running = NO;//////is this calling the setter below? it should!
      AudioOutputUnitStop(_componentInstance);
      AudioComponentInstanceDispose(_componentInstance);
      self.componentInstance = nil;
      self.component = nil;
    }
  });
}

- (void)setRunning:(BOOL)running
{
  if (_running == running) return;
  _running = running;
  
  if (_running) {
    dispatch_async(self.taskQueue, ^{
      NSLog(@"MicrophoneSource: startRunning");
      AudioOutputUnitStart(self.componentInstance);
    });
  } else {
    dispatch_sync(self.taskQueue, ^{
      NSLog(@"MicrophoneSource: stopRunning");
      AudioOutputUnitStop(self.componentInstance);
    });
  }
}

- (void)handleAudioComponentCreationFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:LFAudioComponentFailedToCreateNotification object:nil];
    });
}

- (void)handleInterruption:(NSNotification *)notification {
  AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
  switch (type) {
    case AVAudioSessionInterruptionTypeBegan:
      self.running = YES;
      break;
    case AVAudioSessionInterruptionTypeEnded:
      self.running = NO;
      break;
  }
}

#pragma mark - CallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
  LFAudioCapture *source = (__bridge LFAudioCapture *)inRefCon;
  if (!source) return -1;

  AudioBuffer buffer;
  buffer.mData = NULL;
  buffer.mDataByteSize = 0;
  buffer.mNumberChannels = 1;
  
  AudioBufferList buffers;
  buffers.mNumberBuffers = 1;
  buffers.mBuffers[0] = buffer;

  OSStatus status = AudioUnitRender(source.componentInstance,
                                    ioActionFlags,
                                    inTimeStamp,
                                    inBusNumber,
                                    inNumberFrames,
                                    &buffers);

  if (source.muted) {
    for (int i = 0; i < buffers.mNumberBuffers; i++) {
      AudioBuffer ab = buffers.mBuffers[i];
      memset(ab.mData, 0, ab.mDataByteSize);
    }
  }

  if (!status) {
    if (source.delegate && [source.delegate respondsToSelector:@selector(captureOutput:audioData:)]) {
      [source.delegate captureOutput:source audioData:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];
    }
  }

  return status;
}

@end
