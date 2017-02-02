//
//  LFLivePreviewView.h
//  LFLiveKit
//
//  Created by Pavlos Vinieratos on 02/02/17.
//  Copyright © 2017 admin. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

@interface LFLivePreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) AVCaptureSession *session;

@end
