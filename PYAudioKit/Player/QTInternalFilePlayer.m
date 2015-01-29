//
//  QTInternalFilePlayer.m
//  QTMedia
//
//  Created by Push Chen on 4/14/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTInternalFilePlayer.h"

@implementation QTInternalFilePlayer

@dynamic progress;
- (CGFloat)progress
{
    if ( _iPlayer == nil ) return 0.f;
    return _iPlayer.currentTime;
}
- (void)_reset
{
    PYSingletonLock
    _playingUrl = @"";
    _playPath = @"";
    //_dataCenterList = nil;
    _currentUsingDC = 0;
    _status = QTPlayerStatusUnknow;
    _itemDuration = 0.f;
    
    _startSeek = 0;
    _isSeeking = 0;

    _reconnectCount = 0;
    _connectDelay = 0;
    PYSingletonUnLock
}

- (BOOL)_internalLoadFilePlayUrlAndShouldAutoPlay:(BOOL)autoPlay
{
    NSError *_error = nil;
    _status = QTPlayerStatusLoading;
    [_OBJ(self.delegate) tryPerformSelector:@selector(player:willBeginToLoadURL:)
                                 withObject:self
                                 withObject:_playingUrl];
    NSURL *_fileUrl = [NSURL URLWithString:_playingUrl];
    _iPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_fileUrl error:&_error];
    _iPlayer.delegate = self;
    if ( _error != nil ) {
        ALog(@"Load file<%@> error: %@", _playingUrl, _error.localizedDescription);
        [self playerErrorOccurredWithMessage:_error.localizedDescription];
        return NO;
    }
    _status = QTPlayerStatusReady;

    if ( autoPlay ) {
        [self playItem];
    }
    return YES;
}

- (NSString *)_formatFileUrl:(NSString *)url
{
    NSMutableArray *_components = [NSMutableArray arrayWithArray:[url pathComponents]];
    NSString *_firstItem = [_components safeObjectAtIndex:0];
    if ( [_firstItem length] == 0 ) return url;
    if ( [_firstItem rangeOfString:@"file:"].location != NSNotFound ) {
        [_components removeObjectAtIndex:0];
    } else if ( [_firstItem rangeOfString:@"localhost"].location != NSNotFound ) {
        [_components removeObjectAtIndex:0];
    }
    [_components insertObject:@"file://" atIndex:0];
    return [_components componentsJoinedByString:@"/"];
}

- (void)playUrl:(NSString *)url
{
    PYSingletonLock
    if ( _iPlayer != nil ) [self stopItem];
    
    _playPath = [url copy];
    _playingUrl = [self _formatFileUrl:_playPath];
    [self _internalLoadFilePlayUrlAndShouldAutoPlay:YES];
    PYSingletonUnLock
}

- (void)prepareForPlayingPath:(NSString *)path centerList:(NSArray *)dclist seekFrom:(CGFloat)startSeek
{
    PYSingletonLock
    if ( _iPlayer != nil ) return;
    
    [self _reset];
    _playPath = [path copy];
    _playingUrl = [self _formatFileUrl:_playPath];
    _startSeek = startSeek;
    
    if ( [self _internalLoadFilePlayUrlAndShouldAutoPlay:NO] == NO ) return;
    
    if ( startSeek > 0 ) {
        [_iPlayer setCurrentTime:startSeek];
    }
    [_OBJ(self.delegate) tryPerformSelector:@selector(player:isReadyForPlaying:)
                                 withObject:self
                                 withObject:_playingUrl];
    
    PYSingletonUnLock
}

- (void)playItem
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    if ( _iPlayer.isPlaying ) return;
    if ( _reconnectCount == 0 ) {
        [_stopWatcher start];
    } else {
        [_stopWatcher start];
    }
    _status = QTPlayerStatusPlaying;
    [_iPlayer play];
    PYSingletonUnLock
}

- (void)stopItem
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    _stopPosition = [_iPlayer currentTime];
    [_iPlayer pause];
    [_iPlayer stop];
    // Release the player
    _iPlayer = nil;
    
    if ( [self.delegate respondsToSelector:@selector(player:pausedURL:)] ) {
        [self.delegate player:self pausedURL:_playingUrl];
    }
    [_stopWatcher pause];
    _status = QTPlayerStatusUnknow;
    PYSingletonUnLock
}

- (void)reconnect
{
    PYSingletonLock
    if ( [self _internalLoadFilePlayUrlAndShouldAutoPlay:NO] == NO ) return;
    [_iPlayer setCurrentTime:_stopPosition];
    [_OBJ(self.delegate) tryPerformSelector:@selector(player:isReadyForPlaying:)
                                 withObject:self
                                 withObject:_playingUrl];
    PYSingletonUnLock
}

- (void)seekWithProgress:(CGFloat)progress
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToSeekToProgress:)] ) {
        [self.delegate player:self willBeginToSeekToProgress:progress];
    }
    [_iPlayer setCurrentTime:progress];
    PYSingletonUnLock
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    PYSingletonLock
    [self stopItem];
    [_OBJ(self.delegate)
     tryPerformSelector:@selector(player:didPlayToEndOfURL:)
     withObject:self
     withObject:self.playingUrl];
    PYSingletonUnLock
}

@end
