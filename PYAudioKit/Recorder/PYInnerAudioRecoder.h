//
//  PYInnerAudioRecoder.h
//  PYAudioKit
//
//  Created by Push Chen on 1/28/15.
//  Copyright (c) 2015 PushLab. All rights reserved.
//

/*
 LGPL V3 Lisence
 This file is part of cleandns.
 
 PYAudioKit is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 PYData is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with cleandns.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 LISENCE FOR IPY
 COPYRIGHT (c) 2013, Push Chen.
 ALL RIGHTS RESERVED.
 
 REDISTRIBUTION AND USE IN SOURCE AND BINARY
 FORMS, WITH OR WITHOUT MODIFICATION, ARE
 PERMITTED PROVIDED THAT THE FOLLOWING CONDITIONS
 ARE MET:
 
 YOU USE IT, AND YOU JUST USE IT!.
 WHY NOT USE THIS LIBRARY IN YOUR CODE TO MAKE
 THE DEVELOPMENT HAPPIER!
 ENJOY YOUR LIFE AND BE FAR AWAY FROM BUGS.
 */

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

// @littlepush
// littlepush@gmail.com
// PYLab
