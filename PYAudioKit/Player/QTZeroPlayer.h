//
//  QTZeroPlayer.h
//  QTMedia
//
//  Created by Push Chen on 4/30/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioFile.h>

#define NUM_BUFFERS 3

@interface QTZeroPlayer : NSObject
{
    @public
    AudioStreamBasicDescription         _audioDataFormat;
    AudioQueueRef                       _audioQueue;
    AudioQueueBufferRef                 _audioBuffer[NUM_BUFFERS];
    AudioFileID                         _audioFile;
    UInt32                              _bufferByteSize;
    SInt64                              _currentPacket;
    UInt32                              _numPacketsToRead;
    AudioStreamPacketDescription        *_packetDescs;
    
    BOOL                                _isRunning;
    NSString                            *_audioFilePath;
}

@property (nonatomic, readonly) BOOL        isRunning;
- (void)_openAudioFile;
- (instancetype)initWithAudioFilePath:(NSString *)path;
- (void)play;
- (void)stop;

@end
