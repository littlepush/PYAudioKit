//
//  QTHLSPlayer.m
//  QTRadioModel
//
//  Created by Push Chen on 5/6/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTHLSPlayer.h"
#import "QTMediaCenter.h"
#import "QTInternalFilePlayer.h"
#import "QTInternalHLSPlayer.h"
#import <CoreMedia/CoreMedia.h>

@implementation QTHLSPlayer

// Return all selected player's item.
- (NSString *)playPath
{
    return _selectedPlayer.playPath;
}

- (NSString *)playingUrl
{
    return _selectedPlayer.playingUrl;
}
- (NSString *)usingDataCenter
{
    return _selectedPlayer.usingDataCenter;
}
- (QTPlayerStatus)status
{
    return _selectedPlayer.status;
}
- (CGFloat)duration
{
    return _selectedPlayer.duration;
}
- (CGFloat)progress
{
    return _selectedPlayer.progress;
}
- (BOOL)isPlaying
{
    return _selectedPlayer.isPlaying;
}
- (int)reconnectCount
{
    return _selectedPlayer.reconnectCount;
}
- (CGFloat)connectDelay
{
    return _selectedPlayer.connectDelay;
}
- (CGFloat)playedTime
{
    return _selectedPlayer.playedTime;
}

- (void)playUrl:(NSString *)url
{
    PYSingletonLock
    if ( [url rangeOfString:@"http://"].location != NSNotFound ||
        [url rangeOfString:@"https://"].location != NSNotFound ) {
        // URL
        _selectedPlayer = [QTInternalHLSPlayer object];
        _selectedPlayer.delegate = self;
    } else {
        // URL
        _selectedPlayer = [QTInternalFilePlayer object];
        _selectedPlayer.delegate = self;
    }
    [_selectedPlayer playUrl:url];
    PYSingletonUnLock
}

- (void)playFile:(NSString *)filePath __deprecated
{
    NSAssert(NO, @"The method has been deprecated, use [playUrl:] instead.");
    __builtin_unreachable();
}

- (void)prepareForPlayingItem:(QTMediaInfo *)mediaInfo
                 usePathGroup:(NSArray *)pathGroup
                externalParam:(NSString *)param
               dataCenterList:(NSArray *)dcList
                    startSeek:(CGFloat)startSeek __deprecated
{
    NSAssert(NO, @"The method has been deprecated, use [prepareForPlayingPath:centerList:seekFrom:] instead.");
    __builtin_unreachable();
}

- (void)prepareForPlayingPath:(NSString *)path 
                   centerList:(NSArray *)dcList
                     seekFrom:(CGFloat)startSeek
{
    PYSingletonLock
    __TRY__

    if ( [path length] == 0 ) return;
    
    if ( [dcList count] == 0 ) {
        // Local file
        _selectedPlayer = [QTInternalFilePlayer object];
    } else {
        _selectedPlayer = [QTInternalHLSPlayer object];
    }
    _selectedPlayer.delegate = self;
    [_selectedPlayer prepareForPlayingPath:path centerList:dcList seekFrom:startSeek];
    
    __CATCH__
    ALog(@"Failed to load item: %@", ex);
    __END__
    PYSingletonUnLock
}

- (void)playItem
{
    PYSingletonLock
    if ( _selectedPlayer == nil ) return;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

    [_selectedPlayer playItem];
    [_stopWatcher start];
    PYSingletonUnLock
}

- (void)pauseItem __deprecated
{
    NSAssert(NO, @"The method has been deprecated, please use [stopItem] instead.");
    __builtin_unreachable();
}

- (void)stopItem
{
    PYSingletonLock
    if ( _selectedPlayer == nil ) return;
    [_selectedPlayer stopItem];
    [_stopWatcher pause];
    PYSingletonUnLock
}

- (void)seekWithProgress:(CGFloat)progress
{
    PYSingletonLock
    [_selectedPlayer seekWithProgress:progress];
    PYSingletonUnLock
}

- (void)reconnect
{
    PYSingletonLock
    if ( _selectedPlayer == nil ) return;
    [_selectedPlayer reconnect];
    PYSingletonUnLock
}

// Before playing an item, try to pre-load the item.
- (void)player:(QTPlayer *)player willBeginToLoadURL:(NSString *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToLoadURL:)] ) {
        [self.delegate player:self willBeginToLoadURL:url];
    }
}

// When start to seek item, tell the delegate
- (void)player:(QTPlayer *)player willBeginToSeekToProgress:(CGFloat)progress
{
    if ( [self.delegate respondsToSelector:@selector(player:willBeginToSeekToProgress:)] ) {
        [self.delegate player:self willBeginToSeekToProgress:progress];
    }
}

// Did finish loading item, and everything is ready for playing.
- (void)player:(QTPlayer *)player isReadyForPlaying:(NSString *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:isReadyForPlaying:)] ) {
        [self.delegate player:self isReadyForPlaying:url];
    }
}

// Update the duration of the item.
- (void)player:(QTPlayer *)player durationUpdate:(CGFloat)duration
{
    if ( [self.delegate respondsToSelector:@selector(player:durationUpdate:)] ) {
        [self.delegate player:self durationUpdate:duration];
    }
}

// Item has been paused ( by user or by system )
- (void)player:(QTPlayer *)player pausedURL:(NSString *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:pausedURL:)] ) {
        [self.delegate player:self pausedURL:url];
    }
}

// Play to end of the item.
- (void)player:(QTPlayer *)player didPlayToEndOfURL:(NSString *)url
{
    if ( [self.delegate respondsToSelector:@selector(player:didPlayToEndOfURL:)] ) {
        [self.delegate player:self didPlayToEndOfURL:url];
    }
}

// On error to play the specified item.
- (void)player:(QTPlayer *)player failedToPlayItem:(NSString *)playPath error:(NSError *)error
{
    if ( [self.delegate respondsToSelector:@selector(player:failedToPlayItem:error:)] ) {
        [self.delegate player:self failedToPlayItem:playPath error:error];
    }
}

@end
