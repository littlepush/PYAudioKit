//
//  PYInternalHLSPlayer.m
//  PYAudioKit
//
//  Created by Push Chen on 4/14/14.
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


#import "PYPlayer.h"

NSString *const     kPYPlayerPropertyStatus         = @"status";
NSString *const     kPYPlayerPropertyDuration       = @"duration";
NSString *const     kPYPlayerPropertyBufferEmpty    = @"playbackBufferEmpty";
NSString *const     kPYPlayerPropertyTimedMetadata  = @"timedMetadata";

@interface PYInternalHLSPlayer()
{
    BOOL                                _shouldAutoPlay;
    BOOL                                _isSeeking;
    CGFloat                             _startSeek;
    AVPlayer                            *_iPlayer;
    AVPlayerItem                        *_iItem;
    CGFloat                             _disconnectPosition;
    PYStopWatch                         *_delayTick;
}

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
- (void)_initInternalItem;

// Notification handler
- (void)_playItemDidPlayToEndHandler:(NSNotification *)notify;

@end

@implementation PYInternalHLSPlayer

@dynamic progress;
- (CGFloat)progress
{
    if ( _status == PYPlayerStatusInit ) return _disconnectPosition;
    if ( _status != PYPlayerStatusPlaying ) return 0.f;
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
    PYRemoveObserve(_iItem, kPYPlayerPropertyStatus);
    PYRemoveObserve(_iItem, kPYPlayerPropertyDuration);
    PYRemoveObserve(_iItem, kPYPlayerPropertyBufferEmpty);
    PYRemoveObserve(_iItem, kPYPlayerPropertyTimedMetadata);
    [NF_CENTER removeObserver:self
                         name:AVPlayerItemDidPlayToEndTimeNotification
                       object:_iItem];
    _iItem = nil;
    PYSingletonUnLock
}

- (void)_initInternalItem
{
    PYSingletonLock
    [self _resetInternalItem];
    _delayTick = [PYStopWatch object];
    [_delayTick start];
    _iItem = [AVPlayerItem playerItemWithURL:_playingUrl];
    PYObserve(_iItem, kPYPlayerPropertyDuration);
    PYObserve(_iItem, kPYPlayerPropertyStatus);
    PYObserve(_iItem, kPYPlayerPropertyBufferEmpty);
    PYObserve(_iItem, kPYPlayerPropertyTimedMetadata);
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
    //[_stopWatcher tick];
    if ( [self.delegate respondsToSelector:@selector(player:didPlayToEndOfURL:)] ) {
        [self.delegate player:self didPlayToEndOfURL:_playingUrl];
    }
    [self _reset];
    [self _resetInternalItem];
    [self _resetInternalPlayer];
    PYSingletonUnLock
}

- (void)_prepareInternalPlayerWithStatus:(PYPlayerStatus)st
{
    PYSingletonLock
    @try {
        [self _initInternalItem];
        [self _initInternalPlayer];
        
        _status = PYPlayerStatusLoading;
        if ( [self.delegate respondsToSelector:@selector(player:willBeginToLoadURL:)] ) {
            [self.delegate player:self willBeginToLoadURL:_playingUrl];
        }
        
        _status = st;
        [_iPlayer replaceCurrentItemWithPlayerItem:_iItem];
    }
    @catch (NSException *exception) {
        [self playerErrorOccurredWithMessage:exception.reason];
    }
    PYSingletonUnLock
}

- (void)_reset
{
    PYSingletonLock
    _shouldAutoPlay = NO;
    _playingUrl = nil;
    _status = PYPlayerStatusInit;
    _itemDuration = 0.f;
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

- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek autoPlay:(BOOL)autoPlay
{
    PYSingletonLock
    @try {
        [self _reset];
        [self _resetInternalItem];
        [self _resetInternalPlayer];
        
        _shouldAutoPlay = autoPlay;
        _startSeek = startSeek;
        _playingUrl = [url copy];
        [self _prepareInternalPlayerWithStatus:PYPlayerStatusLoading];
    } @catch( NSException *ex ) {
        [self playerErrorOccurredWithMessage:ex.reason];
    }
    PYSingletonUnLock
}

- (void)playItem
{
    PYSingletonLock
    if ( _status == PYPlayerStatusReady ) {
        // First time to play
        [_iPlayer play];
    } else {
        // Which should not happen
        return;
    }
    _status = PYPlayerStatusPlaying;
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
    [self _resetInternalItem];
    [self _resetInternalPlayer];
    
    _startSeek = 0;
    _isSeeking = NO;
    _shouldAutoPlay = NO;
    
    _status = PYPlayerStatusInit;
    PYSingletonUnLock
}

- (void)reconnect
{
    PYSingletonLock
    if ( _iPlayer != nil ) return;
    _reconnectCount += 1;
    _status = PYPlayerStatusReconnecting;
    _shouldAutoPlay = YES;
    [self _prepareInternalPlayerWithStatus:PYPlayerStatusReconnecting];
    PYSingletonUnLock
}

- (void)_seekToProgress:(CGFloat)progress shouldAutoPlay:(BOOL)autoPlay
{
    PYSingletonLock
    if ( _isSeeking || _iPlayer == nil ) return;
    CMTime _time = CMTimeMake(progress, 1);
    
    // Delegate
    _status = PYPlayerStatusSeeking;
    _isSeeking = YES;
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToSeekToProgress:)] ) {
        [self.delegate player:self willBeginToSeekToProgress:progress];
    }
    
    __weak PYInternalHLSPlayer *_wSelf = self;
    [_iItem seekToTime:_time completionHandler:^(BOOL finished) {
        if ( _wSelf == nil ) return;
        @synchronized( _wSelf ) {
            __strong PYInternalHLSPlayer *_sSelf = _wSelf;
            if ( _sSelf == nil ) return;
            
            _sSelf->_isSeeking = NO;
            
            if ( finished == YES ) {
                _status = PYPlayerStatusReady;
                if ( autoPlay ) {
                    // Begin to play
                    [_wSelf playItem];
                } else {
                    if ( [_wSelf.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
                        [_wSelf.delegate player:_sSelf isReadyForPlaying:_sSelf.playingUrl];
                    }
                }
            } else {
                [_wSelf playerErrorOccurredWithMessage:@"Failed to seek"];
            }
        }
    }];

    PYSingletonUnLock
}

- (void)seekToProgress:(CGFloat)progress
{
    [self _seekToProgress:progress shouldAutoPlay:YES];
}

PYKVO_CHANGED_RESPONSE(_iItem, status)
{
    AVPlayerStatus _st = [newValue intValue];
    if ( _st == AVPlayerStatusReadyToPlay ) {
        // Ready to player
        if ( _status == PYPlayerStatusLoading ) {
            _connectDelay = [_delayTick tick];
            if ( _startSeek > 0 && !isnan(_itemDuration) && _itemDuration > 0 ) {
                [self _seekToProgress:_startSeek shouldAutoPlay:NO];
                return;
            }
        }
        if ( _status == PYPlayerStatusReconnecting ) {
            if ( isnan(_itemDuration) || _itemDuration == 0.f ) {
                ALog(@"current item is live stream");
                // Live Stream
                // Do nothing...
            } else {
                ALog(@"after reconnect, try to seek to progress: %f", _disconnectPosition);
                [self seekToProgress:_disconnectPosition];
                return;
            }
        }
        _status = PYPlayerStatusReady;
        if ( [self.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
            [self.delegate player:self isReadyForPlaying:_playingUrl];
        }
        if ( _shouldAutoPlay ) {
            [self playItem];
        }
        return;
    }
    
    if ( _st == AVPlayerStatusFailed ) {
        // Failed to player
        ALog(@"Failed to play item with error: %@", [_iItem.error localizedDescription]);
        [self playerErrorOccurredWithMessage:_iItem.error.localizedDescription];
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

// @littlepush
// littlepush@gmail.com
// PYLab
