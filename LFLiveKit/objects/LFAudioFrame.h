//
//  LFAudioFrame.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFFrame.h"

@interface LFAudioFrame : LFFrame

// flv package aac header
@property (nonatomic, strong) NSData *audioInfo;

@end
