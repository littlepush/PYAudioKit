//
//  PYInternalFilePlayer.m
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

@interface PYInternalFilePlayer() <AVAudioPlayerDelegate>
{
    AVAudioPlayer           *_iPlayer;
    CGFloat                 _stopPosition;
}

@end

@implementation PYInternalFilePlayer

@dynamic progress;
- (CGFloat)progress
{
    if ( _iPlayer == nil ) return 0.f;
    return _iPlayer.currentTime;
}

- (void)_reset
{
    PYSingletonLock
    _playingUrl = nil;
    _status = PYPlayerStatusInit;
    _itemDuration = 0.f;
    _reconnectCount = 0;
    _connectDelay = 0;
    PYSingletonUnLock
}

- (BOOL)_internalLoadFilePlayUrlAndShouldAutoPlay
{
    NSError *_error = nil;
    _status = PYPlayerStatusLoading;
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToLoadURL:)] ) {
        [self.delegate player:self willBeginToLoadURL:_playingUrl];
    }
    if ( [_playingUrl isFileURL] == NO ) {
        NSString *_formatedUrl = [self _formatFileUrl:_playingUrl.absoluteString];
        _playingUrl = [NSURL URLWithString:_formatedUrl];
    }
    _iPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_playingUrl error:&_error];
    if ( _error != nil ) {
        ALog(@"Load file<%@> error: %@", _playingUrl, _error.localizedDescription);
        [self playerErrorOccurredWithMessage:_error.localizedDescription];
        return NO;
    }
    _iPlayer.delegate = self;
    _status = PYPlayerStatusReady;
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

- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek autoPlay:(BOOL)autoPlay
{
    PYSingletonLock
    if ( _iPlayer != nil ) return;
    [self _reset];
    
    _playingUrl = [url copy];
    
    if ( [self _internalLoadFilePlayUrlAndShouldAutoPlay] == NO ) return;
    if ( startSeek > 0 ) {
        [_iPlayer setCurrentTime:startSeek];
    }
    
    if ( [self.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
        [self.delegate player:self isReadyForPlaying:url];
    }
    
    if ( autoPlay ) {
        [self playItem];
    }
    PYSingletonUnLock
}

- (void)playItem
{
    PYSingletonLock
    if ( _iPlayer == nil ) return;
    if ( _iPlayer.isPlaying ) return;
    _status = PYPlayerStatusPlaying;
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
    _status = PYPlayerStatusInit;
    PYSingletonUnLock
}

- (void)reconnect
{
    PYSingletonLock
    if ( [self _internalLoadFilePlayUrlAndShouldAutoPlay] == NO ) return;
    [_iPlayer setCurrentTime:_stopPosition];
    if ( [self.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
        [self.delegate player:self isReadyForPlaying:_playingUrl];
    }
    [self playItem];
    PYSingletonUnLock
}

- (void)seekToProgress:(CGFloat)progress
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
    if ( [self.delegate respondsToSelector:@selector(player:didPlayToEndOfURL:)] ) {
        [self.delegate player:self didPlayToEndOfURL:_playingUrl];
    }
    PYSingletonUnLock
}

@end

// @littlepush
// littlepush@gmail.com
// PYLab
