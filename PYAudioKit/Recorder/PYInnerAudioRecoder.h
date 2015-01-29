//
//  PYInnerAudioRecoder.h
//  PYAudioKit
//
//  Created by Push Chen on 1/28/15.
//  Copyright (c) 2015 PushLab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static const int kInnerAudioBufferNumbers           = 3;

@interface PYInnerAudioRecoder : NSObject
{
    AudioStreamBasicDescription         _aqAudioDataFormat;
    AudioQueueRef                       _aqAudioQueue;
    AudioQueueBufferRef                 _aqAudioBufferList[kInnerAudioBufferNumbers];
    AudioFileID                         _aqAudioFile;
    UInt32                              _aqAudioBufferByteSize;
    SInt64                              _currentPacket;
    int                                 _lastUsedBuffer;
    BOOL                                _isRecording;
    BOOL                                _shouldWriteToFile;
    
    // Meter Table
    // Copy from Apple's Speak Here
    float                               _meterMinDecibels;
	float                               _meterDecibelResolution;
	float                               _meterScaleFactor;
	float                               *_meterTable;
    
    // Error
    OSStatus                            _lastError;
}

@property (nonatomic, readonly) BOOL        isRecording;

// Return the last error message
@property (nonatomic, readonly) NSError     *lastError;

// Get the first channel's audio weight.
@property (nonatomic, readonly) UInt16      currentWeightOfFirstChannel;

// Start the audio queue to record the audio.
// This operator will not save any data.
- (void)beginToGatherEnvorinmentAudio;

// If the audio queue has not been started, then start it.
// Otherwise just write the recorded buffer to the specified file.
- (void)recordToFile:(NSString *)filepath;

// Stop record, this will also stop the envorinment audio gathering.
- (void)stop;

// Set the record format
- (void)setAudioDataFormat:(AudioStreamBasicDescription)format;

@end
