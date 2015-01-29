//
//  QTPlayAgent+Player.m
//  QTRadioModel
//
//  Created by Push Chen on 9/2/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayAgent+Player.h"
#import "QTPlayAgent+Internal.h"
#import "QTPlayAgentInfo.h"
#import "QTPlayProgress.h"
#import "QTDataManager+User.h"
#import "QTModels.h"
#import "QTRemoteLog+QTMedia.h"

@implementation QTPlayAgent (Player)

#pragma mark --
#pragma mark Player Delegate
- (void)player:(QTPlayer *)player willBeginToLoadURL:(NSString *)url
{
    PYSingletonLock
    if ( player == _emergencyPlayer ) return;
    if ( _playingInfo == nil ) return;
    
    if ( player != _playingInfo.player ) return;
    _playStatus = QTPlayStatusLoading;
    
    PYSingletonUnLock
}

- (void)player:(QTPlayer *)player willBeginToSeekToProgress:(CGFloat)progress
{
    PYSingletonLock
    if ( player == _emergencyPlayer ) return;
    if ( _playingInfo == nil ) return;
    
    if ( _playingInfo.player != player ) return;
    [_delegates objectsTryToPerformSelector:@selector(playerAgentBeginToLoadItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];
    _playStatus = QTPlayStatusLoading;
    PYSingletonUnLock
}

- (void)player:(QTPlayer *)player isReadyForPlaying:(NSString *)url
{
    PYSingletonLock
    if ( player == _emergencyPlayer ) {
        [player playItem];
        [_delegates objectsTryToPerformSelector:@selector(playerAgentBeginPlayingEmergencyItem:)
                                     withObject:_emergencyPlayer.playingUrl];
        return;
    }
    // ready  go to play
    if ( _playingInfo == nil ) return;
    // start current playitem
    if ( player != _playingInfo.player ) return;
    [self _checkCurrentPlayingInfoPlayerStatusAndPlay];
    PYSingletonUnLock
}

- (void)player:(QTPlayer *)player durationUpdate:(CGFloat)duration
{
    // nothing.
}

- (void)player:(QTPlayer *)player pausedURL:(NSString *)url
{
    if ( player == _emergencyPlayer ) {
        [_delegates objectsTryToPerformSelector:@selector(playerAgentPauseEmergencyItem:)
                                     withObject:_emergencyPlayer.playingUrl];
        return;
    }
    [_delegates objectsTryToPerformSelector:@selector(playerAgentDidPausedItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];
}

- (void)player:(QTPlayer *)player didPlayToEndOfURL:(NSString *)url
{
    if ( player == _emergencyPlayer ) {
        [_delegates objectsTryToPerformSelector:@selector(playerAgentEndPlayingEmergencyItem:)
                                     withObject:_emergencyPlayer.playingUrl];
        [self stopEmergencyBroadcast];
        return;
    }
    
    [_delegates objectsTryToPerformSelector:@selector(playerAgentDidEndPlayOfItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];
    // when the item end of play
    [QT_DATAMGR addHistoryProgress:_playingInfo.programItem progress:0];
    
    IF ( _playingInfo.autoPlayNext ) {
        [self systemPlayNextItem];
    }
}

- (void)player:(QTPlayer *)player failedToPlayItem:(NSString *)playPath error:(NSError *)error
{
    ALog(@"Receive error message from inner player.");
    if ( player == _emergencyPlayer ) {
        ALog(@"Emergency Player Error occurred.");
        [_delegates objectsTryToPerformSelector:@selector(playerAgentFailedToPlayEmergencyItem:)
                                     withObject:_emergencyPlayer.playingUrl];
        [self stopEmergencyBroadcast];
        return;
    }
    PYSingletonLock
    NSString *_willRemoveItem = qtEmptyString;
    for ( NSString *_identify in _currentPreLoadItems ) {
        QTPlayAgentInfo *_info = [_currentPreLoadItems objectForKey:_identify];
        if ( _info.player == player ) {
            _willRemoveItem = _identify;
            break;
        }
    }
    if ( [_willRemoveItem length] > 0 ) {
        [_currentPreLoadItems removeObjectForKey:_willRemoveItem];
    }
    [[QTRemoteLog shared] logPlayFailedOfItem:_playingInfo.programItem
                                     withInfo:_playingInfo
                                        error:error];
    if ( player != _playingInfo.player ) return;
    _playStatus = QTPlayStatusError;
    QTPlayAgentInfo *_copiedAgentInfo = _playingInfo;
    [self _stopCurrentPlayingItem:NO];
    for ( id<QTPlayAgentDelegate> _delegate in _delegates ) {
        if ( [_delegate respondsToSelector:@selector(playerAgentFailedToPlayItem:withOptions:error:)] ) {
            ALog(@"Post player error message to object %@<%p>",
                 NSStringFromClass([_delegate class]), _delegate);
            [_delegate playerAgentFailedToPlayItem:_copiedAgentInfo.beanIdentify
                                       withOptions:[_copiedAgentInfo objectToJsonDict]
                                             error:error];
        }
    }
    
    // On failed, auto play next item.
    // [self systemPlayNextItem];
    PYSingletonUnLock
}

@end
