//
//  PYPlayer.m
//  PYAudioKit
//
//  Created by Push Chen on 5/2/13.
//  Copyright (c) 2015 PushLab.. All rights reserved.
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

@implementation PYPlayer

/*! The playing status. */
@synthesize delegate;
/*! The hls url, or file path */
@synthesize playingUrl = _playingUrl;
/*! The status of current player */
@synthesize status = _status;
/*! The duration get from the audio's metadata */
@synthesize duration = _itemDuration;
/*! Current playing progress */
@dynamic progress;
- (CGFloat)progress
{
    NSAssert(NO, @"Should override this method.");
    return 0.f;
}
/*! Is current status equal to <code>PYPlayerStatusPlaying</code> */
@dynamic isPlaying;
- (BOOL)isPlaying
{
    return _status == PYPlayerStatusPlaying;
}

// Reconnect times when playing the audio stream
/*! Reconnect count */
@synthesize reconnectCount = _reconnectCount;
/*! The time between status change from <code>PYPlayerStatusLoading</code> to <code>PYPlayerStatusReady</code> */
@synthesize connectDelay = _connectDelay;

// Play
/*! All in one, the url can be http://url or local file://path, will not seek, and auto start to play when status changed to ready. */
- (void)playUrl:(NSURL *)url
{
    //NSAssert(NO, @"Should override this method.");
    [self prepareUrl:url seekFrom:0 autoPlay:YES];
}
/*! load the audio data from the url and seek to specified position then start to play */
- (void)playUrl:(NSURL *)url seekFrom:(CGFloat)startSeek
{
    //NSAssert(NO, @"Should override this method.");
    [self prepareUrl:url seekFrom:startSeek autoPlay:YES];
}
/*! load the audio data, seek to specified position, and if <code>autoPlay</code> is set to NO, then will wait for play signal. */
- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek autoPlay:(BOOL)autoPlay
{
    NSAssert(NO, @"Should override this method.");
}

/*!
 @brief start to play an audio stream of status <code>PYPlayerStatusReady</code>
 @discussion Start seek point is only work for the first time to play item.
 */
- (void)playItem
{
    NSAssert(NO, @"Should override this method.");
}

/*! Pause current playing item but not trace as a pause action. */
- (void)stopItem
{
    NSAssert(NO, @"Should override this method.");
}

/*! When buffer is empty, try to reconnect. */
- (void)reconnect
{
    NSAssert(NO, @"Should override this method.");
}

/*! Seek the play progress to the specified progress. */
- (void)seekToProgress:(CGFloat)progress
{
    NSAssert(NO, @"Should override this method.");
}

/*! On Error Happen. */
- (void)playerErrorOccurredWithMessage:(NSString *)message;
{
    _status = PYPlayerStatusError;
    if ( [self.delegate respondsToSelector:@selector(player:failedToPlayItem:error:)] ) {
        NSError *_error = [self errorWithCode:-1 message:message];
        [self.delegate player:self failedToPlayItem:_playingUrl error:_error];
    }   
}

@end

@interface PYAudioPlayer () < PYPlayerDelegate >
{
    PYPlayer            *_internalPlayer;
}
@end

@implementation PYAudioPlayer

/*! The hls url, or file path */
- (NSURL *)playingUrl
{
    return _internalPlayer.playingUrl;
}
/*! The status of current player */
- (PYPlayerStatus)status
{
    return _internalPlayer.status;
}
/*! The duration get from the audio's metadata */
- (CGFloat)duration
{
    return _internalPlayer.duration;
}
/*! Current playing progress */
@dynamic progress;
- (CGFloat)progress
{
    return _internalPlayer.progress;
}
/*! Is current status equal to <code>PYPlayerStatusPlaying</code> */
- (BOOL)isPlaying
{
    return _internalPlayer.isPlaying;
}

// Reconnect times when playing the audio stream
/*! Reconnect count */
- (int)reconnectCount
{
    return _internalPlayer.reconnectCount;
}
/*! The time between status change from <code>PYPlayerStatusLoading</code> to <code>PYPlayerStatusReady</code> */
- (CGFloat)connectDelay
{
    return _internalPlayer.connectDelay;
}

/*! load the audio data, seek to specified position, and if <code>autoPlay</code> is set to NO, then will wait for play signal. */
- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek autoPlay:(BOOL)autoPlay
{
    //NSAssert(NO, @"Should override this method.");
    NSString *_url = [url absoluteString];
    
    NSRange _httpRange = [_url rangeOfString:@"http://"];
    NSRange _httpsRnage = [_url rangeOfString:@"https://"];
    if ( _httpRange.location == 0 || _httpsRnage.location == 0 ) {
        _internalPlayer = [PYInternalHLSPlayer object];
    } else {
        _internalPlayer = [PYInternalFilePlayer object];
    }
    _internalPlayer.delegate = self;
    [_internalPlayer prepareUrl:url seekFrom:startSeek autoPlay:autoPlay];
}

/*!
 @brief start to play an audio stream of status <code>PYPlayerStatusReady</code>
 @discussion Start seek point is only work for the first time to play item.
 */
- (void)playItem
{
    PYSingletonLock
    if ( _internalPlayer == nil ) return;
    
    [_internalPlayer playItem];
    PYSingletonUnLock
}

/*! Pause current playing item but not trace as a pause action. */
- (void)stopItem
{
    PYSingletonLock
    if ( _internalPlayer == nil ) return;
    [_internalPlayer stopItem];
    PYSingletonUnLock
}

/*! When buffer is empty, try to reconnect. */
- (void)reconnect
{
    PYSingletonLock
    if ( _internalPlayer == nil ) return;
    [_internalPlayer reconnect];
    PYSingletonUnLock
}

/*! Seek the play progress to the specified progress. */
- (void)seekToProgress:(CGFloat)progress
{
    PYSingletonLock
    [_internalPlayer seekToProgress:progress];
    PYSingletonUnLock
}

// Before playing an item, try to pre-load the item.
- (void)player:(PYPlayer *)player willBeginToLoadURL:(NSURL *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToLoadURL:)] ) {
        [self.delegate player:self willBeginToLoadURL:url];
    }
}

// When start to seek item, tell the delegate
- (void)player:(PYPlayer *)player willBeginToSeekToProgress:(CGFloat)progress
{
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToSeekToProgress:)] ) {
        [self.delegate player:self willBeginToSeekToProgress:progress];
    }
}

// Did finish loading item, and everything is ready for playing.
- (void)player:(PYPlayer *)player isReadyForPlaying:(NSURL *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
        [self.delegate player:self isReadyForPlaying:url];
    }
}

// Update the duration of the item.
- (void)player:(PYPlayer *)player durationUpdate:(CGFloat)duration
{
    if ( [self.delegate respondsToSelector:@selector(player:durationUpdate:)] ) {
        [self.delegate player:self durationUpdate:duration];
    }
}

// Item has been paused ( by user or by system )
- (void)player:(PYPlayer *)player pausedURL:(NSURL *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:pausedURL:)] ) {
        [self.delegate player:self pausedURL:url];
    }
}

// Play to end of the item.
- (void)player:(PYPlayer *)player didPlayToEndOfURL:(NSURL *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:didPlayToEndOfURL:)] ) {
        [self.delegate player:self didPlayToEndOfURL:url];
    }
}

// On error to play the specified item.
- (void)player:(PYPlayer *)player failedToPlayItem:(NSURL *)playUrl error:(NSError *)error
{
    if ( [self.delegate respondsToSelector:@selector(player:failedToPlayItem:error:)] ) {
        [self.delegate player:self failedToPlayItem:playUrl error:error];
    }
}

@end

// @littlepush
// littlepush@gmail.com
// PYLab
