//
//  IYNAudioRecording.m
//  IYNAudioExample
//
//  Created by qiyun on 17/1/12.
//  Copyright © 2017年 qiyun. All rights reserved.
//

#import "IYNAudioRecording.h"

@implementation IYNAudioRecording{
    
    int _sampleRate;
    ALbyte buffer[22050];
}

- (id)initWithSampleRate:(int)sampleRate{
    
    if (self == [super init]) {
        
        _sampleRate = sampleRate;
        
        ALCdevice *device = alcCaptureOpenDevice(NULL, sampleRate, AL_FORMAT_STEREO16, sampleRate/10);
        if (alGetError() != AL_NO_ERROR) {
            
            return NULL;
        }
        
        alcCaptureStart(device);
        
        while (true) {
            alcGetIntegerv(device, ALC_CAPTURE_SAMPLES, (ALCsizei)sizeof(ALint), &sampleRate);
            alcCaptureSamples(device, (ALCvoid *)buffer, sampleRate);
            
            // ... do something with the buffer
            
            if (!buffer) break;
        }
        
        alcCaptureStop(device);
        alcCaptureCloseDevice(device);
        
    }
    return self;
}

@end
