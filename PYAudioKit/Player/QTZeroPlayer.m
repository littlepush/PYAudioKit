//
//  QTZeroPlayer.m
//  QTMedia
//
//  Created by Push Chen on 4/30/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTZeroPlayer.h"

static void HandleOutputBuffer (
                                void                 *aqData,
                                AudioQueueRef        inAQ,
                                AudioQueueBufferRef  inBuffer
)
{
    QTZeroPlayer *_zeroPlayer = (__bridge QTZeroPlayer *)aqData;

    UInt32 numBytesReadFromFile;
    UInt32 numPackets = _zeroPlayer->_numPacketsToRead;

ReadFromFile:
    AudioFileReadPackets (
                          _zeroPlayer->_audioFile,
                          false,
                          &numBytesReadFromFile,
                          _zeroPlayer->_packetDescs,
                          _zeroPlayer->_currentPacket,
                          &numPackets,
                          inBuffer->mAudioData
                          );
    if ( numPackets > 0 ) {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        AudioQueueEnqueueBuffer (
                                 _zeroPlayer->_audioQueue,
                                 inBuffer,
                                 (_zeroPlayer->_packetDescs ? numPackets : 0),
                                 _zeroPlayer->_packetDescs
                                 );
        _zeroPlayer->_currentPacket += numPackets;
    } else {
        _zeroPlayer->_currentPacket = 0;
        numPackets = _zeroPlayer->_numPacketsToRead;
        // Re-open the file
        [_zeroPlayer _openAudioFile];
        goto ReadFromFile;
    }
}

void DeriveBufferSize (
                       AudioStreamBasicDescription *pASBDesc,
                       UInt32                      maxPacketSize,
                       Float64                     seconds,
                       UInt32                      *outBufferSize,
                       UInt32                      *outNumPacketsToRead
) {
    static const int maxBufferSize = 0x50000;
    static const int minBufferSize = 0x4000;
    
    if (pASBDesc->mFramesPerPacket != 0) {
        Float64 numPacketsForTime =
        pASBDesc->mSampleRate / pASBDesc->mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        *outBufferSize =
        maxBufferSize > maxPacketSize ?
        maxBufferSize : maxPacketSize;
    }
    
    if (
        *outBufferSize > maxBufferSize &&
        *outBufferSize > maxPacketSize
        )
        *outBufferSize = maxBufferSize;
    else {
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;
}

@implementation QTZeroPlayer

@synthesize isRunning = _isRunning;

- (void)_openAudioFile
{
    if ( _audioFile != NULL ) {
        AudioFileClose(_audioFile);
        _audioFile = NULL;
    }
    // Open the audio file
    CFURLRef audioFileURL =
    CFURLCreateFromFileSystemRepresentation (
                                             NULL,
                                             (const UInt8 *)_audioFilePath.UTF8String,
                                             _audioFilePath.length,
                                             false
                                             );
    AudioFileOpenURL (
                      audioFileURL,
                      kAudioFileReadPermission,
                      0,
                      &_audioFile
                      );
    
    CFRelease(audioFileURL);
}

- (void)_initAudioQueue
{
    
    UInt32 dataFormatSize = sizeof (_audioDataFormat);
    AudioFileGetProperty (
                          _audioFile,
                          kAudioFilePropertyDataFormat,
                          &dataFormatSize,
                          &_audioDataFormat
                          );
    
    // Create audio queue
    AudioQueueNewOutput (
                         &_audioDataFormat,
                         HandleOutputBuffer,
                         (__bridge void *)self,
                         CFRunLoopGetCurrent(),
                         kCFRunLoopCommonModes,
                         0,
                         &_audioQueue
                         );
    // Get buffer size
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof(maxPacketSize);
    AudioFileGetProperty (
                          _audioFile,
                          kAudioFilePropertyPacketSizeUpperBound,
                          &propertySize,
                          &maxPacketSize
                          );
    
    DeriveBufferSize (
                      &_audioDataFormat,
                      maxPacketSize,
                      0.5,
                      &_bufferByteSize,
                      &_numPacketsToRead
                      );
    
    bool isFormatVBR = (
                        _audioDataFormat.mBytesPerPacket == 0 ||
                        _audioDataFormat.mFramesPerPacket == 0
                        );
    
    if (isFormatVBR) {
        _packetDescs =
        (AudioStreamPacketDescription*) malloc (
                                                _numPacketsToRead * sizeof (AudioStreamPacketDescription)
                                                );
    } else {
        _packetDescs = NULL;
    }
    // Magic cookie
    UInt32 cookieSize = sizeof (UInt32);
    bool couldNotGetProperty =
    AudioFileGetPropertyInfo (
                              _audioFile,
                              kAudioFilePropertyMagicCookieData,
                              &cookieSize,
                              NULL
                              );
    
    if (!couldNotGetProperty && cookieSize) {
        char* magicCookie =
        (char *) malloc (cookieSize);
        
        AudioFileGetProperty (
                              _audioFile,
                              kAudioFilePropertyMagicCookieData,
                              &cookieSize,
                              magicCookie
                              );
        
        AudioQueueSetProperty (
                               _audioQueue,
                               kAudioQueueProperty_MagicCookie,
                               magicCookie,
                               cookieSize
                               );
        
        free (magicCookie);
    }
    
    // Alloc buffer
    _currentPacket = 0;
    
    for (int i = 0; i < NUM_BUFFERS; ++i) {
        AudioQueueAllocateBuffer (
                                  _audioQueue,
                                  _bufferByteSize,
                                  &_audioBuffer[i]
                                  );
        
        HandleOutputBuffer (
                            (__bridge void *)self,
                            _audioQueue,
                            _audioBuffer[i]
                            );
    }
    
    // Volumn
    Float32 gain = 0.f;
    AudioQueueSetParameter (
                            _audioQueue,
                            kAudioQueueParam_Volume,
                            gain
                            );
}

- (instancetype)initWithAudioFilePath:(NSString *)path
{
    self = [super init];
    if ( self ) {
        _audioFilePath = [path copy];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}
- (void)play
{
    //BEGIN_MAINTHREAD_INVOKE
    if ( _isRunning ) return;
    [self _openAudioFile];
    [self _initAudioQueue];
    AudioQueueStart(_audioQueue, NULL);
    _isRunning = YES;
    //END_MAINTHREAD_INVOKE
}

- (void)stop
{
    //BEGIN_MAINTHREAD_INVOKE
    if ( !_isRunning ) return;
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose (
                       _audioQueue,
                       true
                       );
    AudioFileClose (_audioFile);
    _audioQueue = NULL;
    free (_packetDescs);
    _isRunning = NO;
    //END_MAINTHREAD_INVOKE
}

@end
