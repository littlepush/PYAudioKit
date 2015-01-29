//
//  QTInternalHLSPlayer.m
//  QTMedia
//
//  Created by Push Chen on 4/14/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTInternalHLSPlayer.h"

NSString *const     kQTPlayerPropertyStatus         = @"status";
NSString *const     kQTPlayerPropertyDuration       = @"duration";
NSString *const     kQTPlayerPropertyBufferEmpty    = @"playbackBufferEmpty";
NSString *const     kQTPlayerPropertyTimedMetadata  = @"timedMetadata";

@interface QTInternalHLSPlayer (Internal)

// KVO Responder.
PYKVO_CHANGED_RESPONSE(_iItem, status);
PYKVO_CHANGED_RESPONSE(_iItem, duration);
PYKVO_CHANGED_RESPONSE(_iItem, playbackBufferEmpty);
PYKVO_CHANGED_RESPONSE(_iItem, timedMetadata);

- (void)_reset;

// Reset & Initial for the HLS Player.
- (void)_resetInternalPlayer;
- (void)_initInternalPlayer;

// Reset & Initial for the HLS Item.
- (void)_resetInternalItem;
- (void)_initInternalItem:(NSString *)url;

// Notification handler
- (void)_playItemDidPlayToEndHandler:(NSNotification *)notify;

// Timer handler
- (void)_progressTimerHandler:(NSTimer *)timer;

@end

@implementation QTInternalHLSPlayer

@dynamic progress;
- (CGFloat)progress
{
    if ( _status == QTPlayerStatusUnknow ) return _disconnectPosition;
    if ( _status != QTPlayerStatusPlaying ) return 0.f;
    return CMTimeGetSeconds(_iItem.currentTime);
}

- (void)_resetInternalPlayer
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    _iPlayer = nil;
    PYSingletonUnLock
}

- (void)_initInternalPlayer
{
    PYSingletonLock
    [self _resetInternalPlayer];
    _iPlayer = [AVPlayer object];
    PYSingletonUnLock
}

- (void)_resetInternalItem
{
    PYSingletonLock
    if ( _iItem == nil ) return;
    PYRemoveObserve(_iItem, kQTPlayerPropertyStatus);
    PYRemoveObserve(_iItem, kQTPlayerPropertyDuration);
    PYRemoveObserve(_iItem, kQTPlayerPropertyBufferEmpty);
    PYRemoveObserve(_iItem, kQTPlayerPropertyTimedMetadata);
    [NF_CENTER removeObserver:self
                         name:AVPlayerItemDidPlayToEndTimeNotification
                       object:_iItem];
    _iItem = nil;
    PYSingletonUnLock
}

- (void)_initInternalItem:(NSString *)url
{
    PYSingletonLock
    [self _resetInternalItem];
    _iItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:url]];
    PYObserve(_iItem, kQTPlayerPropertyDuration);
    PYObserve(_iItem, kQTPlayerPropertyStatus);
    PYObserve(_iItem, kQTPlayerPropertyBufferEmpty);
    PYObserve(_iItem, kQTPlayerPropertyTimedMetadata);
    [NF_CENTER addObserver:self
                  selector:@selector(_playItemDidPlayToEndHandler:)
                      name:AVPlayerItemDidPlayToEndTimeNotification
                    object:_iItem];
    PYSingletonUnLock
}

- (void)_playItemDidPlayToEndHandler:(NSNotification *)notify
{
    PYSingletonLock
    if ( notify.object != _iItem ) return;
    [_stopWatcher pause];
    //[_stopWatcher tick];
    [_OBJ(self.delegate)  tryPerformSelector:@selector(player:didPlayToEndOfURL:)
                                 withObject:self
                                 withObject:self.playingUrl];

    [self _reset];
    [self _resetInternalItem];
    [self _resetInternalPlayer];
    PYSingletonUnLock
}

- (void)_playNextDataCenterUrlWithStatus:(QTPlayerStatus)st
{
    PYSingletonLock
    @try {
        if ( _currentUsingDC == [_dataCenterList count] ) {
            [self playerErrorOccurredWithMessage:@"No validate source in all data center"];
            return;
        }
        
        // Get the URL
        // if ( _pathGroup == nil || [_pathGroup count] == 0 ) return;
        if ( [_playPath length] == 0 ) return;
        
        // For TransCode Item, only contains one path.
        // NSMutableString *_firstPath = [NSMutableString stringWithString:[_pathGroup safeObjectAtIndex:0]];
        NSMutableString *_urlPath = [NSMutableString stringWithString:_playPath];
        BOOL _hasSp = [_urlPath rangeOfString:@"?"].location != NSNotFound;
        NSString *_spChar = (_hasSp ? @"&" : @"?");
        /*
         if ( [_externalParam length] > 0 ) {
         [_urlPath _appendFormat:@"%@%@", _spChar, _externalParam];
         _spChar = @"&";
         }
         */
        [_urlPath appendFormat:@"%@deviceid=%@", _spChar, [QTKernel currentKernel].deviceId];
        NSString *_dcIp = [_dataCenterList safeObjectAtIndex:_currentUsingDC];
        if ( [_dcIp length] == 0 ) {
            ALog(@"Data Center List Error, get empty dc node.");
            DUMPObj(_playPath);
            _currentUsingDC += 1;
            [self _playNextDataCenterUrlWithStatus:st];
            return;
        }
        _playingUrl = [NSString stringWithFormat:@"http://%@%@",
                       _dcIp, _urlPath];
        
        ALog(@"Prepare to play the url: %@", _playingUrl);
        [self _initInternalItem:_playingUrl];
        [self _initInternalPlayer];
        if ( self.delegate ) {
            [_OBJ(self.delegate) tryPerformSelector:@selector(player:willBeginToLoadURL:)
                                         withObject:self
                                         withObject:_playingUrl];
        }
        _status = st;
        [_iPlayer replaceCurrentItemWithPlayerItem:_iItem];
    }
    @catch (NSException *exception) {
        ALog(@"exception print-->%@",exception.reason);
    }
    PYSingletonUnLock
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

- (void)dealloc
{
    PYSingletonLock
    [self _reset];
    [self _resetInternalItem];
    [self _resetInternalPlayer];
    PYSingletonUnLock
}

- (void)playUrl:(NSString *)url
{
    PYSingletonLock
    @try {
        
        [self _reset];
        [self _resetInternalItem];
        [self _resetInternalPlayer];
        
        _playingUrl = [url copy];
        [self _initInternalItem:url];
        [self _initInternalPlayer];

        // Change status before loading
        _status = QTPlayerStatusLoading;
        [_OBJ(self.delegate) tryPerformSelector:@selector(player:willBeginToLoadURL:)
                                     withObject:self
                                     withObject:url];
        [_iPlayer replaceCurrentItemWithPlayerItem:_iItem];
    }
    @catch (NSException *exception) {
        ALog(@"Failed to play url: %@", exception);
    }
    PYSingletonUnLock
}

- (void)prepareForPlayingPath:(NSString *)path
                   centerList:(NSArray *)dcList
                     seekFrom:(CGFloat)startSeek
{
    PYSingletonLock
    __TRY__
    // Force to reset all info
    [self _reset];
    [self _resetInternalItem];
    [self _resetInternalPlayer];
   
    _playPath = [path copy];
    _dataCenterList = [dcList copy];
    _startSeek = startSeek;

    _status = QTPlayerStatusLoading;
    
    [_stopWatcher start];
    [self _playNextDataCenterUrlWithStatus:QTPlayerStatusLoading];
    __CATCH__
    ALog(@"Failed to prepare audio info: %@", ex);
    __END__
    
    PYSingletonUnLock
}

- (void)playItem
{
    PYSingletonLock
    if ( _status == QTPlayerStatusReady && _reconnectCount == 0 ) {
        // First time to play
        [_stopWatcher start];
        [_iPlayer play];
    } else if ( _status == QTPlayerStatusReady && _reconnectCount > 0 ) {
        [_stopWatcher start];
        [_iPlayer play];
    } else {
        // Will not happen
        return;
    }
    _status = QTPlayerStatusPlaying;
    PYSingletonUnLock
}

- (void)stopItem
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    _disconnectPosition = self.progress;
    [_iPlayer pause];
    [_iPlayer setRate:0.f];
    
    if ( [self.delegate respondsToSelector:@selector(player:pausedURL:)] ) {
        [self.delegate player:self pausedURL:_playingUrl];
    }
    
    // Reset all item
    // [self _reset];
    [_stopWatcher pause];
    [self _resetInternalItem];
    [self _resetInternalPlayer];
    
    _status = QTPlayerStatusUnknow;
    
    PYSingletonUnLock
}

- (void)reconnect
{
    PYSingletonLock
    if ( _iPlayer != nil ) return;
    _currentUsingDC = 0;
    _reconnectCount += 1;
    _status = QTPlayerStatusReconnect;
    [self _playNextDataCenterUrlWithStatus:QTPlayerStatusReconnect];
    PYSingletonUnLock
}

- (void)_seekWithProgress:(CGFloat)progress shouldAutoPlay:(BOOL)autoPlay
{
    PYSingletonLock
    if ( _isSeeking || _iPlayer == nil ) return;
    CMTime _time = CMTimeMake(progress, 1);
    _status = QTPlayerStatusSeek;
    _isSeeking = YES;
    
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToSeekToProgress:)] ) {
        [self.delegate player:self willBeginToSeekToProgress:progress];
    }
    
    __weak QTInternalHLSPlayer *_wSelf = self;
    [_stopWatcher pause];
    [_iItem seekToTime:_time completionHandler:^(BOOL finished) {
        if ( _wSelf == nil ) return;
        @synchronized( _wSelf ) {
            __strong QTInternalHLSPlayer *_sSelf = _wSelf;
            _sSelf->_isSeeking = NO;
            
            if ( finished == YES ) {
                if ( autoPlay ) {
                    // Begin to play
                    [_sSelf->_stopWatcher start];
                    [_sSelf->_iPlayer play];
                    _status = QTPlayerStatusPlaying;
                } else {
                    _status = QTPlayerStatusReady;
                    [_OBJ(_wSelf.delegate)
                     tryPerformSelector:@selector(player:isReadyForPlaying:)
                     withObject:_sSelf
                     withObject:_sSelf->_playingUrl];
                }
            } else {
                [_wSelf playerErrorOccurredWithMessage:@"Failed to seek"];
            }
        }
    }];

    PYSingletonUnLock
}

- (void)seekWithProgress:(CGFloat)progress
{
    [self _seekWithProgress:progress shouldAutoPlay:YES];
}

PYKVO_CHANGED_RESPONSE(_iItem, status)
{
    AVPlayerStatus _st = [newValue intValue];
    ALog(@"HLSPlayer status changed to: %d", (int)_st);
    if ( _st == AVPlayerStatusReadyToPlay ) {
        // Ready to player
        if ( _status == QTPlayerStatusLoading ) {
            ALog(@"HLS Player status is loading");
            _connectDelay = [_stopWatcher tick];
            if ( _startSeek > 0 && !isnan(_itemDuration) && _itemDuration > 0 ) {
                [self _seekWithProgress:_startSeek shouldAutoPlay:NO];
                return;
            }
        }
        if ( _status == QTPlayerStatusReconnect ) {
            ALog(@"HLS Player status is reconnect");
            if ( isnan(_itemDuration) || _itemDuration == 0.f ) {
                ALog(@"current item is live stream");
                // Live Stream
                // Do nothing...
            } else {
                ALog(@"after reconnect, try to seek to progress: %f", _disconnectPosition);
                [self seekWithProgress:_disconnectPosition];
                return;
            }
        }
        _status = QTPlayerStatusReady;
        if ( self.delegate ) {
            [_OBJ(self.delegate) tryPerformSelector:@selector(player:isReadyForPlaying:)
                                         withObject:self withObject:_playingUrl];
        }
        return;
    }
    
    if ( _st == AVPlayerStatusFailed ) {
        // Failed to player
        ALog(@"Failed to play item with error: %@", [_iItem.error localizedDescription]);
        if ( _currentUsingDC == [_dataCenterList count] - 1 ) {
            [self playerErrorOccurredWithMessage:_iItem.error.localizedDescription];
        } else {
            _currentUsingDC += 1;
            //[self _reset];
            [self _playNextDataCenterUrlWithStatus:_status];
        }
        return;
    }
    
    if ( _st == AVPlayerStatusUnknown ) {
        ALog(@"... I don't know how to process this situation..."
              @"may be we should throw an exception to gather information.");
        [self raiseExceptionWithMessage:@"AVPlayerStatus changes to Unknow, what should I do?"];
    }
}

PYKVO_CHANGED_RESPONSE(_iItem, duration)
{
    _itemDuration = CMTimeGetSeconds(_iPlayer.currentItem.duration);
    if ( isnan(_itemDuration) ) {
        _itemDuration = 0.f;
    }
    ALog(@"duration change to: %f", _itemDuration);
    if ( [self.delegate respondsToSelector:@selector(player:durationUpdate:)] ) {
        [self.delegate player:self durationUpdate:_itemDuration];
    }
}

PYKVO_CHANGED_RESPONSE(_iItem, playbackBufferEmpty)
{
    BOOL _isEmpty = _iItem.isPlaybackBufferEmpty;

    if ( _isEmpty ) {
        if ( _isSeeking ) {
            ALog(@"Seeking, empty buffer...");
            return;
        }
        _disconnectPosition = self.progress;
        if ( isnan(_itemDuration) ) {
            // Live Stream
            ALog(@"the item's buffer become empty...maybe because of the network status change");
            [self reconnect];
        } else {
            if ( abs((int)_itemDuration - (int)self.progress) > 10 ) {
                [self reconnect];
            } else {
                ALog(@"Item will play to end, so the buffer become empty");
            }
        }
    } else {
        ALog(@"Item's buffer not empty");
    }
}

PYKVO_CHANGED_RESPONSE(_iItem, timedMetadata)
{
    ALog(@"%@", _iItem.timedMetadata);
}

@end
