//
//  PYInnerAudioRecoder.m
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

#import "PYInnerAudioRecoder.h"
#import <PYCore/PYCore.h>

@interface PYInnerAudioRecoder (StaticHandler)

@property (nonatomic, readonly) AudioStreamBasicDescription    audioDataFormat;
@property (nonatomic, readonly) BOOL                    shouldWriteToFile;
@property (nonatomic, readonly) AudioFileID             audioFileId;
@property (nonatomic, readonly) UInt32                  audioBufferSize;
@property (nonatomic, readonly) AudioQueueBufferRef     lastAudioBuffer;
@property (nonatomic, assign)   SInt64                  currentPacketNumber;
@property (nonatomic, readonly) BOOL                    shouldWriteRawData;
@property (nonatomic, readonly) NSString                *filePath;

- (void)setLastAudioBuffer:(AudioQueueBufferRef)buffer;

@end

static void __innerAudioRecoderInputHanlder (
    void                                *innerAudioRecorder,
    AudioQueueRef                       inAQ,
    AudioQueueBufferRef                 inBuffer,
    const AudioTimeStamp                *inStartTime,
    UInt32                              inNumPackets,
    const AudioStreamPacketDescription  *inPacketDesc
) {
    PYInnerAudioRecoder *_recorder = (__bridge PYInnerAudioRecoder *)innerAudioRecorder;

    // Calculate the packat count
    if ( inNumPackets == 0 && _recorder.audioDataFormat.mBytesPerPacket != 0 )
        inNumPackets = inBuffer->mAudioDataByteSize / _recorder.audioDataFormat.mBytesPerPacket;
    
    if ( _recorder.shouldWriteToFile ) {
        // Write to file
        if ( _recorder.shouldWriteRawData ) {
            if ( inBuffer->mAudioDataByteSize != 0 ) {
                FILE *_f = fopen(_recorder.filePath.UTF8String, "a+");
                if ( _f != NULL ) {
                    //DUMPInt(inPacketDesc->mDataByteSize);
                    // Number of packages
                    UInt32 _np = htonl(inNumPackets);
                    fwrite(&_np, sizeof(UInt32), 1, _f);
                    UInt32 _nd = (inPacketDesc == NULL) ? 0 : _np;
                    fwrite(&_nd, sizeof(UInt32), 1, _f);
                    if ( inPacketDesc != NULL ) {
                        for ( UInt32 i = 0; i < inNumPackets; ++i ) {
                            fwrite(inPacketDesc + i, sizeof(AudioStreamPacketDescription), 1, _f);
                        }
                    }
                    // Buffer size
                    UInt32 _bs = htonl(inBuffer->mAudioDataByteSize);
                    fwrite(&_bs, sizeof(UInt32), 1, _f);
                    fwrite(inBuffer->mAudioData, sizeof(Byte), inBuffer->mAudioDataByteSize, _f);
                    fclose(_f);
                }
            }
        } else {
            if ( noErr == AudioFileWritePackets(_recorder.audioFileId,
                                                false,
                                                inBuffer->mAudioDataByteSize,
                                                inPacketDesc,
                                                _recorder.currentPacketNumber,
                                                &inNumPackets,
                                                inBuffer->mAudioData) ) {
                _recorder.currentPacketNumber += inNumPackets;
            }
        }
    }
    
    [_recorder setLastAudioBuffer:inBuffer];
    if ( _recorder.isRecording == NO ) return;
    AudioQueueEnqueueBuffer(inAQ,
                            inBuffer,
                            0,
                            NULL);
}

static void __deriveBufferSize (
    AudioQueueRef audioQueue,
    AudioStreamBasicDescription *ASBDescription,
    Float64 seconds,
    UInt32 *outBufferSize )
{
    static const int maxBufferSize = 0x5000;
    int _maxPacketSize = ASBDescription->mBytesPerPacket;
    if ( _maxPacketSize == 0 ) {
        UInt32 _maxVBRPacketSize = sizeof(_maxPacketSize);
        AudioQueueGetProperty (
                audioQueue,
                kAudioQueueProperty_MaximumOutputPacketSize,
                &_maxPacketSize,
                &_maxVBRPacketSize
        );
    }
    Float64 numBytesForTime = ASBDescription->mSampleRate * _maxPacketSize * seconds;
    *outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);
}

static OSStatus SetMagicCookieForFile (
                                       AudioQueueRef inQueue,
                                       AudioFileID   inFile
) {
    OSStatus result = noErr;
    UInt32 cookieSize;
    if (
            AudioQueueGetPropertySize (
                inQueue,
                kAudioQueueProperty_MagicCookie,
                &cookieSize
            ) == noErr
    ) {
        char* magicCookie = (char *)malloc(cookieSize);
        if (
                AudioQueueGetProperty (
                    inQueue,
                    kAudioQueueProperty_MagicCookie,
                    magicCookie,
                    &cookieSize
                ) == noErr
        ) {
            result = AudioFileSetProperty (
                        inFile,
                        kAudioFilePropertyMagicCookieData,
                        cookieSize,
                        magicCookie
                     );
        }
        free (magicCookie);
    }
    return result;
}

static BOOL _recorder_setMagicCookieForRawFile(AudioQueueRef inQueue, FILE *file) {
    UInt32 _cookieSize;
    if ( AudioQueueGetPropertySize(inQueue, kAudioQueueProperty_MagicCookie, &_cookieSize) == noErr ) {
        char *_magicCookie = (char *)malloc(_cookieSize);
        if ( AudioQueueGetProperty(inQueue, kAudioQueueProperty_MagicCookie, _magicCookie, &_cookieSize) == noErr ) {
            UInt32 _s = htonl(_cookieSize);
            fwrite(&_s, sizeof(UInt32), 1, file);
            fwrite(_magicCookie, sizeof(char), _cookieSize, file);
        }
        free ( _magicCookie );
        return YES;
    }
    return NO;
}

static char *FormatError(char *str, OSStatus error)
{
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    return str;
}

@implementation PYInnerAudioRecoder

@synthesize isRecording = _isRecording;

- (id)init
{
    self = [super init];
    if ( self ) {
        // Initialize the meter table
        _meterMinDecibels = -80.f;
        _meterDecibelResolution = _meterMinDecibels / (400 - 1);
        _meterScaleFactor = 1.f / _meterDecibelResolution;
        
#define __dbToAmp(d)    pow(10.f, 0.05 * d)
        _meterTable = (float *)malloc(400 * sizeof(float));
        
        double minAmp = __dbToAmp(_meterMinDecibels);
        double ampRange = 1. - minAmp;
        double invAmpRange = 1. / ampRange;
        
        double rroot = 1. / 2.f;
        for (size_t i = 0; i < 400; ++i) {
            double decibels = i * _meterDecibelResolution;
            double amp = __dbToAmp(decibels);
            double adjAmp = (amp - minAmp) * invAmpRange;
            _meterTable[i] = pow(adjAmp, rroot);
        }
#undef __dbToAmp
        
        // Set default format
        _aqAudioDataFormat.mSampleRate       = 16000;
        _aqAudioDataFormat.mFormatID         = kAudioFormatMPEG4AAC;
        _aqAudioDataFormat.mFormatFlags      = 0;
        _aqAudioDataFormat.mFramesPerPacket  = 0;
        _aqAudioDataFormat.mChannelsPerFrame = 2;
        _aqAudioDataFormat.mBitsPerChannel   = 0;
        _aqAudioDataFormat.mBytesPerPacket   = 0;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    free(_meterTable);
}

@dynamic lastError;
- (NSError *)lastError
{
    char _errMsg[6];
    FormatError(_errMsg, _lastError);
    NSString *_errStr = [NSString stringWithUTF8String:_errMsg];
    return [self errorWithCode:_lastError message:_errStr];
}

@dynamic currentWeightOfFirstChannel;
- (UInt16)currentWeightOfFirstChannel
{
    if ( _isRecording == NO ) return 0;
    static AudioQueueLevelMeterState   _chan_lvls[2];
    
    UInt32 data_sz = sizeof(AudioQueueLevelMeterState) * 2;
    OSStatus status = AudioQueueGetProperty(
                                            _aqAudioQueue,
                                            kAudioQueueProperty_CurrentLevelMeterDB,
                                            &(_chan_lvls[0]),
                                            &data_sz);
    if (status != noErr) return 0;

    Float32 _allPower = 0;
    for (int i = 0; i < 2; i++) {
        if (_chan_lvls) {
            _allPower += _chan_lvls[i].mPeakPower;
        }
    }
    if ( _allPower < _meterMinDecibels ) return 0.f;
    if ( _allPower >= 0.f ) return UINT16_MAX;
    int _index = (int)(_allPower * _meterScaleFactor);
    return (uint16_t)(65535.f * _meterTable[_index]);
}

- (void)beginToGatherEnvorinmentAudio
{
    if ( _isRecording ) return;
    
    // Create the new audio queue
    _lastError = AudioQueueNewInput(
                                    &_aqAudioDataFormat,
                                    __innerAudioRecoderInputHanlder,
                                    ((__bridge void *)self),
                                    NULL,
                                    kCFRunLoopCommonModes,
                                    0,
                                    &_aqAudioQueue
                       );
    if ( _lastError != noErr ) return;
    
    // Get Buffer Size
    __deriveBufferSize(_aqAudioQueue, &_aqAudioDataFormat, 0.5, &_aqAudioBufferByteSize);
    for ( int i = 0; i < kInnerAudioBufferNumbers; ++i ) {
        // Allocate the buffer
        _lastError = AudioQueueAllocateBuffer(_aqAudioQueue, _aqAudioBufferByteSize, &_aqAudioBufferList[i]);
        if ( _lastError != noErr ) {
            for ( int f = i - 1; f >= 0; --f ) {
                AudioQueueFreeBuffer(_aqAudioQueue, _aqAudioBufferList[f]);
            }
            AudioQueueDispose(_aqAudioQueue, true);
            return;
        }
        
        // Enqueue the buffer
        _lastError = AudioQueueEnqueueBuffer(_aqAudioQueue, _aqAudioBufferList[i], 0, NULL);
        if ( _lastError != noErr ) {
            for ( int f = i; f >= 0; --f ) {
                AudioQueueFreeBuffer(_aqAudioQueue, _aqAudioBufferList[f]);
            }
            AudioQueueDispose(_aqAudioQueue, true);
            return;
        }
    }
    
    // Set Metering
    UInt32 _val = 1;
    _lastError = AudioQueueSetProperty(
                                       _aqAudioQueue,
                                       kAudioQueueProperty_EnableLevelMetering,
                                       &_val,
                                       sizeof(UInt32));
    if ( _lastError != noErr ) {
        for ( int i = 0; i < kInnerAudioBufferNumbers; ++i ) {
            AudioQueueFreeBuffer(_aqAudioQueue, _aqAudioBufferList[i]);
        }
        AudioQueueDispose(_aqAudioQueue, true);
        return;
    }
    
//    int _retryTimes = 3;
//    do {
        _lastError = AudioQueueStart(_aqAudioQueue, NULL);
//        if ( _lastError == noErr ) break;
//        _retryTimes -= 1;
//    } while ( _retryTimes > 0 );
    if ( _lastError != noErr ) {
        for ( int i = 0; i < kInnerAudioBufferNumbers; ++i ) {
            AudioQueueFreeBuffer(_aqAudioQueue, _aqAudioBufferList[i]);
        }
        AudioQueueDispose(_aqAudioQueue, true);
        return;
    }
    _currentPacket = 0;
    _isRecording = YES;
}

- (void)recordToFile:(NSString *)filepath withType:(AudioFileTypeID)fileType
{
    if ( !_isRecording ) {
        [self beginToGatherEnvorinmentAudio];
        if ( _lastError != 0 ) return;
    }
    // Set the file path, create the audio file, and set the flag to write to file.
    AudioFileTypeID _fileType = fileType;
    _shouldWriteRawData = NO;
    _filePath = [filepath copy];
    
    if ( _fileType == 0 ) {
        _shouldWriteRawData = YES;
        FILE *_f = fopen(filepath.UTF8String, "a+");
        _recorder_setMagicCookieForRawFile(_aqAudioQueue, _f);
        fclose(_f);
    } else {
        CFURLRef _audioFileUrl = CFURLCreateFromFileSystemRepresentation(NULL,
                                                                         (const UInt8 *)filepath.UTF8String,
                                                                         filepath.length,
                                                                         false);
        _lastError = AudioFileCreateWithURL(_audioFileUrl,
                                            _fileType,
                                            &_aqAudioDataFormat,
                                            kAudioFileFlags_EraseFile,
                                            &_aqAudioFile);
        if ( _lastError != 0 ) return;
        
        SetMagicCookieForFile(_aqAudioQueue, _aqAudioFile);
    }
    _shouldWriteToFile = YES;
}

- (void)stop
{
    if ( _isRecording == NO ) return;
    // Stop the queue
    AudioQueueStop(_aqAudioQueue, true);
    // Dispose data
    AudioQueueDispose(_aqAudioQueue, true);
    // Close file
    if ( _aqAudioFile != NULL ) {
        AudioFileClose( _aqAudioFile );
    }
    
    _isRecording = NO;
}

- (void)setAudioDataFormat:(AudioStreamBasicDescription)format
{
    memcpy(&_aqAudioDataFormat, &format, sizeof(AudioStreamBasicDescription));
}

@end

@implementation PYInnerAudioRecoder (StaticHandler)

@dynamic audioDataFormat;
- (AudioStreamBasicDescription)audioDataFormat
{
    return _aqAudioDataFormat;
}

@dynamic shouldWriteToFile;
- (BOOL)shouldWriteToFile
{
    return _shouldWriteToFile;
}

@dynamic audioFileId;
- (AudioFileID)audioFileId
{
    return _aqAudioFile;
}

@dynamic audioBufferSize;
- (UInt32)audioBufferSize
{
    return _aqAudioBufferByteSize;
}

@dynamic lastAudioBuffer;
- (AudioQueueBufferRef)currentAudioBuffer
{
    return _aqAudioBufferList[_lastUsedBuffer];
}

@dynamic shouldWriteRawData;
- (BOOL)shouldWriteRawData
{
    return _shouldWriteRawData;
}

@dynamic filePath;
- (NSString *)filePath
{
    return _filePath;
}

- (void)setLastAudioBuffer:(AudioQueueBufferRef)buffer
{
    for ( int i = 0; i < kInnerAudioBufferNumbers; ++i ) {
        if ( _aqAudioBufferList[i] == buffer ) {
            _lastUsedBuffer = i;
            break;
        }
    }
}

@dynamic currentPacketNumber;
- (SInt64)currentPacketNumber
{
    return _currentPacket;
}
- (void)setCurrentPacketNumber:(SInt64)currentPacketNumber
{
    _currentPacket = currentPacketNumber;
}

@end

// @littlepush
// littlepush@gmail.com
// PYLab
