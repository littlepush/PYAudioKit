//
//  PYPlayer.h
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


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import <PYCore/PYCore.h>

// The delegate for the player.
@protocol PYPlayerDelegate;

/*!
 @brief Player status enumeration.
 */
typedef NS_ENUM( NSInteger, PYPlayerStatus ) {
    /*! Just init the player */
    PYPlayerStatusInit            = 0,
    /*! Loading the HLS stream or prepare the file */
    PYPlayerStatusLoading,
    /*! Ready to play */
    PYPlayerStatusReady,
    /*! Seeking the stream */
    PYPlayerStatusSeeking,
    /*! Reconnect to HLS stream */
    PYPlayerStatusReconnecting,
    /*! Playing the audio */
    PYPlayerStatusPlaying,
    /*! Error happened */
    PYPlayerStatusError
};

/*!
 @class PYPlayer
 @brief This is the basic class definition of Audio Player, which just
    defined the interface and methods, is an abstract class.
 @discussion Do not use this interface directly.
 */
@interface PYPlayer : PYKVOObject
{
@protected
    // Audio Resource Info
    NSURL                               *_playingUrl;
    // Player Status Info
    PYPlayerStatus                      _status;
    CGFloat                             _itemDuration;

    // Statistic
    int                                 _reconnectCount;
    CGFloat                             _connectDelay;
}

/*! The playing status. */
@property (nonatomic, assign)   id<PYPlayerDelegate>    delegate;
/*! The hls url, or file path */
@property (nonatomic, readonly) NSURL                   *playingUrl;
/*! The status of current player */
@property (nonatomic, readonly) PYPlayerStatus          status;
/*! The duration get from the audio's metadata */
@property (nonatomic, readonly) CGFloat                 duration;
/*! Current playing progress */
@property (nonatomic, readonly) CGFloat                 progress;
/*! Is current status equal to <code>PYPlayerStatusPlaying</code> */
@property (nonatomic, readonly) BOOL                    isPlaying;

// Reconnect times when playing the audio stream
/*! Reconnect count */
@property (nonatomic, readonly) int                     reconnectCount;
/*! The time between status change from <code>PYPlayerStatusLoading</code> to <code>PYPlayerStatusReady</code> */
@property (nonatomic, readonly) CGFloat                 connectDelay;

// Play
/*! All in one, the url can be http://url or local file://path, will not seek, and auto start to play when status changed to ready. */
- (void)prepareUrl:(NSURL *)url;
/*! load the audio data from the url and seek to specified position then start to play */
- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek;
/*! load the audio data, seek to specified position, and if <code>autoPlay</code> is set to NO, then will wait for play signal. */
- (void)prepareUrl:(NSURL *)url seekFrom:(CGFloat)startSeek autoPlay:(BOOL)autoPlay;

/*!
 @brief start to play an audio stream of status <code>PYPlayerStatusReady</code>
 @discussion Start seek point is only work for the first time to play item.
 */
- (void)playItem;

/*! Pause current playing item but not trace as a pause action. */
- (void)stopItem;

/*! When buffer is empty, try to reconnect. */
- (void)reconnect;

/*! Seek the play progress to the specified progress. */
- (void)seekToProgress:(CGFloat)progress;

/*! On Error Happen. */
- (void)playerErrorOccurredWithMessage:(NSString *)message;

@end

@protocol PYPlayerDelegate <NSObject>

@optional

/*! Before playing an item, try to pre-load the item. */
- (void)player:(PYPlayer *)player willBeginToLoadURL:(NSURL *)url;

/*! When start to seek item, tell the delegate */
- (void)player:(PYPlayer *)player willBeginToSeekToProgress:(CGFloat)progress;

/*! Did finish loading item, and everything is ready for playing. */
- (void)player:(PYPlayer *)player isReadyForPlaying:(NSURL *)url;

/*! Update the duration of the item. */
- (void)player:(PYPlayer *)player durationUpdate:(CGFloat)duration;

/*! Item has been paused ( by user or by system ) */
- (void)player:(PYPlayer *)player pausedURL:(NSURL *)url;

/*! Play to end of the item. */
- (void)player:(PYPlayer *)player didPlayToEndOfURL:(NSURL *)url;

/*! On error to play the specified item. */
- (void)player:(PYPlayer *)player failedToPlayItem:(NSURL *)playUrl error:(NSError *)error;

@end

/*!
 @class The audio player class. Used this to play an HTTP Live Stream(HLS) or a local audio file.
 @discussion The only interface which can be used as audio player.
 */
@interface PYAudioPlayer : PYPlayer

@end

/*!
 @class The internal player to play a local audio file
 */
@interface PYInternalFilePlayer : PYPlayer

@end

/*!
 @class The internal player to play an HLS.
 */
@interface PYInternalHLSPlayer : PYPlayer

@end

// @littlepush
// littlepush@gmail.com
// PYLab
