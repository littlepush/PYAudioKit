//
//  PYAudioRecorder.m
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
#import "PYAudioRecorder.h"
#import <PYCore/PYCore.h>

@interface PYAudioRecorder ()
{
    PYInnerAudioRecoder             *_innerRecoder;
    NSString                        *_saveDataPath;
    NSString                        *_tempFilePath;
    BOOL                            _isRecording;
    
    CADisplayLink                   *_displayLink;
    
    AudioStreamBasicDescription     _recordFormat;
}

- (void)_setRecordFormat:(AudioStreamBasicDescription)format;

@end

@implementation PYAudioRecorder

@synthesize tempFilePath = _tempFilePath;
@synthesize audioPath = _saveDataPath;
@synthesize isRecording = _isRecording;
@synthesize envSoundMeterRate;
@synthesize recordFormat = _recordFormat;

@synthesize delegate;

@dynamic lastError;
- (NSError *)lastError
{
    return _innerRecoder.lastError;
}

+ (instancetype)audioRecorderWithFormat:(AudioStreamBasicDescription)format
{
    PYAudioRecorder *_recorder = [PYAudioRecorder object];
    [_recorder _setRecordFormat:format];
    return _recorder;
}

- (void)_setRecordFormat:(AudioStreamBasicDescription)format
{
    [_innerRecoder setAudioDataFormat:format];
}

- (id)init
{
    self = [super init];
    if ( self ) {
        _tempFilePath = [PYCACHEPATH stringByAppendingPathComponent:PYGUID];
        _innerRecoder = [PYInnerAudioRecoder object];
        
        // Change the audio session to record
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        // Active the audio session
        NSError *_audioError = nil;
        if ( ![[AVAudioSession sharedInstance] setActive:YES error:&_audioError] ) {
            PYLog(@"%@", _audioError);
        }
        
        self.envSoundMeterRate = 0.45;
        // Set default format
        [self _setRecordFormat:aqPYAudioRecorderFormatMPEG4AAC];
    }
    return self;
}

- (void)startMeterFetching
{
    [self stopMeterFetching];
    _displayLink = [CADisplayLink
                    displayLinkWithTarget:self
                    selector:@selector(_audioPowerMeterHandler:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                       forMode:NSRunLoopCommonModes];
}

- (void)stopMeterFetching
{
    if ( _displayLink == nil ) return;
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)dealloc
{
    [self stopMeterFetching];
}

- (void)_audioPowerMeterHandler:(id)sender
{
    float _rate = (_isRecording ? 1.f : self.envSoundMeterRate );
    if ( self.delegate ) {
        if ( [self.delegate respondsToSelector:@selector(audioRecorder:updateMeter:)] ) {
            [self.delegate audioRecorder:self updateMeter:_rate];
        }
    }
}
- (BOOL)starToRecord
{
    // Start to record
    [_innerRecoder recordToFile:_tempFilePath];
    if ( _innerRecoder.lastError == nil ) {
        _isRecording = YES;
        return YES;
    }
    return NO;
}

- (NSString *)stopRecordAndSaveWithFileName:(NSString *)filename
{
    NSString *_filename = filename;
    if ( [_filename containsString:@"."] == NO ) {
        _filename = [filename stringByAppendingPathExtension:@"m4a"];
    }
    _saveDataPath = [PYDOCUMENTPATH stringByAppendingPathComponent:_filename];
    DUMPObj(_saveDataPath);
    [_innerRecoder stop];
    NSFileManager *_fm = [NSFileManager defaultManager];
    NSError *_error = nil;
    BOOL _isDic = NO;
    if ( [_fm fileExistsAtPath:_saveDataPath isDirectory:&_isDic] ) {
        if ( !_isDic ) {
            [_fm removeItemAtPath:_saveDataPath error:&_error];
        }
    }
    [_fm moveItemAtPath:_tempFilePath toPath:_saveDataPath error:&_error];
    _isRecording = NO;
    if ( _error != nil ) {
        PYLog(@"%@", _error);
    }
    [_innerRecoder beginToGatherEnvorinmentAudio];
    return _saveDataPath;
}
- (BOOL)startToGatherEnvorinmentSound
{
    int _retryTimes = 3;
    do {
        [_innerRecoder beginToGatherEnvorinmentAudio];
        if ( _innerRecoder.lastError.code == 0 ) return YES;
    } while ( (_retryTimes -= 1) >= 0 );
    return NO;
}

+ (NSString *)audioPathWithFileName:(NSString *)filename;
{
    NSString *_filename = filename;
    if ( [_filename containsString:@"."] == NO ) {
        _filename = [filename stringByAppendingPathExtension:@"m4a"];
    }
    return [PYDOCUMENTPATH stringByAppendingPathComponent:_filename];
}

@end

// @littlepush
// littlepush@gmail.com
// PYLab
