//
//  QTPlayer.h
//  QTRadioModel
//
//  Created by Push Chen on 5/2/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import "QTMediaInfo.h"

// The delegate for the player.
@protocol QTPlayerDelegate;

typedef enum {
    QTPlayerStatusUnknow            = 0,
    QTPlayerStatusLoading,
    QTPlayerStatusReady,
    QTPlayerStatusSeek,
    QTPlayerStatusReconnect,
    QTPlayerStatusPlaying,
    QTPlayerStatusPaused    __deprecated,
    QTPlayerStatusError
} QTPlayerStatus;

@interface QTPlayer : PYKVOObject
{
@protected
    // Audio Resource Info
    NSString                            *_playingUrl;   // The final url, or file path
    NSString                            *_playPath;     // The input path, need to combine with specified data center
    NSArray                             *_dataCenterList;   // All available data center list,
                                                            // Ordered by the speed.
    NSInteger                           _currentUsingDC;// Current choosing data center

    // Player Status Info
    QTPlayerStatus                      _status;        // The status of current player
    CGFloat                             _itemDuration;  // The duration get from the audio's metadata
    PYStopWatch                         *_stopWatcher;
   
    // Seek Info 
    CGFloat                             _startSeek;
    BOOL                                _isSeeking;

    // Statistic
    int                                 _reconnectCount;
    CGFloat                             _connectDelay;

    // Deprecated Item
    CGFloat                             _progress __deprecated;
    NSTimer                             *_progressTimer __deprecated;
    NSArray                             *_pathGroup __deprecated;
    NSString                            *_externalParam __deprecated;
    QTMediaInfo                         *_playingMediaInfo __deprecated;
}

// The playing status.
@property (nonatomic, assign)   id<QTPlayerDelegate>    delegate;

@property (nonatomic, readonly) NSString                *playingUrl;
@property (nonatomic, readonly) NSString                *playPath;

@property (nonatomic, readonly) NSString                *usingDataCenter;

@property (nonatomic, readonly) QTPlayerStatus          status;
@property (nonatomic, readonly) CGFloat                 duration;
@property (nonatomic, readonly) CGFloat                 progress;
@property (nonatomic, readonly) CGFloat                 playedTime;
@property (nonatomic, readonly) BOOL                    isPlaying;

// Reconnect times when playing the audio stream
@property (nonatomic, readonly) int                     reconnectCount;
// Time used to connect and fill the buffer
@property (nonatomic, readonly) CGFloat                 connectDelay;

// The media info
@property (nonatomic, readonly) QTMediaInfo             *mediaInfo __deprecated;
// Deprecated
@property (nonatomic, copy)     NSString                *agentIdentify __deprecated;

// Play
- (void)playUrl:(NSString *)url;    // All in one, the url can be http://url or local file://path
- (void)playFile:(NSString *)filePath __deprecated;
- (void)prepareForPlayingPath:(NSString *)path 
                   centerList:(NSArray *)dclist 
                     seekFrom:(CGFloat)startSeek;

- (void)prepareForPlayingItem:(QTMediaInfo *)mediaInfo
                 usePathGroup:(NSArray *)pathGroup
                externalParam:(NSString *)param
               dataCenterList:(NSArray *)dcList
                    startSeek:(CGFloat)startSeek __deprecated;

// Start point is only work for the first time to play item.
// When resume from pause status, ignore the start point.
- (void)playItem;

// Pause current playing statue
- (void)pauseItem __deprecated;

// Pause current playing item but not trace as a pause action.
- (void)stopItem;

// When buffer is empty, try to reconnect.
- (void)reconnect;

// Seek the play progress to the specified progress.
- (void)seekWithProgress:(CGFloat)progress;

// On Error Happen.
- (void)playerErrorOccurredWithMessage:(NSString *)message;

@end

@protocol QTPlayerDelegate <NSObject>

@optional

// Before playing an item, try to pre-load the item.
- (void)player:(QTPlayer *)player willBeginToLoadURL:(NSString *)url;

// When start to seek item, tell the delegate
- (void)player:(QTPlayer *)player willBeginToSeekToProgress:(CGFloat)progress;

// Did finish loading item, and everything is ready for playing.
- (void)player:(QTPlayer *)player isReadyForPlaying:(NSString *)url;

// Update the duration of the item.
- (void)player:(QTPlayer *)player durationUpdate:(CGFloat)duration;

// During playing, update the progress.
- (void)player:(QTPlayer *)player progressUpdate:(CGFloat)progress __deprecated;

// Item has been paused ( by user or by system )
- (void)player:(QTPlayer *)player pausedURL:(NSString *)url;

// Play to end of the item.
- (void)player:(QTPlayer *)player didPlayToEndOfURL:(NSString *)url;

// On error to play the specified item.
- (void)player:(QTPlayer *)player failedToPlayItem:(NSString *)playPath error:(NSError *)error;

@end
