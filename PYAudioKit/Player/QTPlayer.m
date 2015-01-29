//
//  QTPlayer.m
//  QTRadioModel
//
//  Created by Push Chen on 5/2/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayer.h"

@implementation QTPlayer

@synthesize mediaInfo = _playingMediaInfo;
@synthesize agentIdentify;

@synthesize delegate;
@synthesize playingUrl = _playingUrl;
@synthesize playPath = _playPath;

@dynamic usingDataCenter;
- (NSString *)usingDataCenter {
    return [_dataCenterList safeObjectAtIndex:_currentUsingDC];
}

@synthesize status = _status;
@synthesize duration = _itemDuration;
//@synthesize progress = _progress;
@dynamic progress;
- (CGFloat)progress
{
    NSAssert(NO, @"Should override this method.");
    return 0.f;
}
- (CGFloat)playedTime
{
    return [_stopWatcher tick] / 1000;  // ms -> s
}
@dynamic isPlaying;
- (BOOL)isPlaying
{
    return _status == QTPlayerStatusPlaying;
}

@synthesize reconnectCount = _reconnectCount;
@synthesize connectDelay = _connectDelay;

- (id)init
{
    self = [super init];
    if ( self ) {
        _stopWatcher = [PYStopWatch object];
    }
    return self;
}

// Play
- (void)playUrl:(NSString *)url __ABSTRACT_METHOD__;
- (void)playFile:(NSString *)filePath __deprecated __ABSTRACT_METHOD__;
- (void)prepareForPlayingItem:(QTMediaInfo *)mediaInfo
                 usePathGroup:(NSArray *)pathGroup
                externalParam:(NSString *)param
               dataCenterList:(NSArray *)dcList
                    startSeek:(CGFloat)startSeek __ABSTRACT_METHOD__;

- (void)prepareForPlayingPath:(NSString *)path 
                   centerList:(NSArray *)dclist 
                     seekFrom:(CGFloat)startSeek __ABSTRACT_METHOD__;

- (void)playItem __ABSTRACT_METHOD__;

// Pause current playing statue
- (void)pauseItem __deprecated __ABSTRACT_METHOD__;

- (void)stopItem __ABSTRACT_METHOD__;

// Check current playing status and try to resume the play status.
// Specially, when the user switch in the background, and get intepreted.
- (void)reconnect __ABSTRACT_METHOD__;

// Seek the play progress to the specified progress.
- (void)seekWithProgress:(CGFloat)progress __ABSTRACT_METHOD__;

// On Error Happen.
- (void)playerErrorOccurredWithMessage:(NSString *)message
{
    _status = QTPlayerStatusError;
    if ( [self.delegate respondsToSelector:@selector(player:failedToPlayItem:error:)] ) {
        NSError *_error = [self errorWithCode:-1 message:message];
        [self.delegate player:self failedToPlayItem:_playPath error:_error];
    }   
}

@end
