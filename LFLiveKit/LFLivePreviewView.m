//
//  LFLivePreviewView.m
//  LFLiveKit
//
//  Created by Pavlos Vinieratos on 02/02/17.
//  Copyright © 2017 admin. All rights reserved.
//

#import "LFLivePreviewView.h"

@implementation LFLivePreviewView

+ (Class)layerClass
{
  return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
  return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (void)setSession:(AVCaptureSession *)session;
{
  self.videoPreviewLayer.session = session;
}

@end
