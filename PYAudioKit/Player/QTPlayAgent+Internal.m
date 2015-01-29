//
//  QTPlayAgent+Internal.m
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayAgent+Internal.h"
#import "QTPlayAgentInfo.h"
#import "QTDataManager+Items.h"
#import "QTMediaCenter.h"
#import "QTDownloader.h"
#import "QTDataManager+User.h"
#import "QTRemoteLog+QTMedia.h"

@implementation QTPlayAgent (Internal)

// Notification handler, for Audio Session, with iOS 6.0+
- (void)_audioSessionInterruptionHandler:(NSNotification *)notify
{
    ALog(@"Audio Session Interrupteion Handler...");
    AVAudioSessionInterruptionType _type =
    [notify.userInfo intObjectForKey:AVAudioSessionInterruptionTypeKey];
    if ( _type == AVAudioSessionInterruptionTypeBegan ) {
        ALog(@"Begin Interruption");
        [self beginInterruption];
    } else {
        ALog(@"End Interruption");
        [self endInterruption];
    }
}

- (QTPlayAgentInfo *)_generateFormatedAgentInfoForSpecifiedItem:(NSString *)itemIdentify
                                                     withOption:(NSDictionary *)options
{
    NSMutableDictionary *_options = [NSMutableDictionary dictionaryWithDictionary:options];
    QTPlayAgentInfo *_agentInfo = [QTPlayAgentInfo object];
    [_options setValue:itemIdentify forKey:kQTPlayAgentOptionBeanIdentify];
    id<QTProgramItem> _item = (id<QTProgramItem>)[QT_DATAMGR dataForKey:itemIdentify];
    if ( _item == nil ) {
        _item = (id<QTProgramItem>)[QT_DATAMGR userDataForKey:itemIdentify];
    }
    if ( _item == nil ) {
        _item = (id<QTProgramItem>)[QT_DLMGR itemByIdentify:itemIdentify];
    }
    if ( _item != nil && [_item conformsToProtocol:@protocol(QTProgramItem)] ) {
        [_options setObject:_item forKey:kQTPlayAgentOptionBeanItem];
    } else {
        [self raiseExceptionWithMessage:@"The item is not playable: %@"];
    }
    
    id<QTChannel> _setItem = nil;
    if ( [_item conformsToProtocol:@protocol(QTChannel)] ) {
        _setItem = (id<QTChannel>)_item;
    } else {
        // Only program
        _setItem = (id<QTChannel>)[QT_DATAMGR dataForKey:_item.uplevelIdentify];
        if ( _setItem == nil ) {
            [self raiseExceptionWithMessage:@"cannot find the channel item: %@"];
        }
    }
    NSString *_categoryIdentify = [options stringObjectForKey:kQTPlayAgentOptionCategoryIdentify
                                        withDefaultValue:_setItem.uplevelIdentify];
    [_options setObject:_categoryIdentify forKey:kQTPlayAgentOptionCategoryIdentify];
    
    NSString *_channelIdentify = [options stringObjectForKey:kQTPlayAgentOptionSetIdentify
                                            withDefaultValue:_setItem.beanIdentify];
    [_options setObject:_channelIdentify forKey:kQTPlayAgentOptionSetIdentify];

    // Try to identify the set item.
    @try {
        [_agentInfo objectFromJsonDict:_options];
    } @catch (NSException *ex) {
        ALog(@"\nex: %@\n%@", ex.reason, ex.callStackSymbols);
        return nil;
    }
    
    return _agentInfo;
}
- (void)_internalPause
{
    PYSingletonLock
    if ( _playingInfo == nil ) return;
    if ( _playingInfo.player == nil ) return;   // Still before loading, which means the thread has problem
    [_playingInfo.player stopItem];
    
    ALog(@"current is playing, pause it!");
    _playStatus = QTPlayStatusPaused;
    if ( _playingInfo == nil ) return;
    _playingInfo.pausedTimes += 1;
    
    // Tell the delegates
    [_delegates objectsTryToPerformSelector:@selector(playerAgentDidPausedItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];
    PYSingletonUnLock
}

- (void)_internalResume
{
    PYSingletonLock
    
    // Close emergency player
    if ( _emergencyPlayer != nil ) {
        [_emergencyPlayer stopItem];
        _emergencyPlayer = nil;
    }
    if ( _playingInfo == nil ) return;
    [_playingInfo.player reconnect];
        
    [_delegates objectsTryToPerformSelector:@selector(playerAgentDidStartToPlayItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];

    PYSingletonUnLock
    
}

// play item
- (void)_playItem:(QTPlayAgentInfo *)agentInfo __deprecated
{
    NSAssert(NO, @"The method has been deprecated.");
    __builtin_unreachable();
}
- (void)_loadItem:(QTPlayAgentInfo *)agentInfo
{
    if ( agentInfo == nil ) return;
    PYSingletonLock
    NSString *_agentIdentify = agentInfo.agentIdentify;
    if ( [_agentIdentify length] == 0 ) {
        ALog(@"Please refresh the program list and try to get the resource id of the program.");
        return;
    }
    if ( [_currentPreLoadItems objectForKey:_agentIdentify] != nil ) return;
    
    // Create new loading player
    agentInfo.player = [QTHLSPlayer object];
    agentInfo.player.delegate = self;
    // Add to cache
    [_currentPreLoadItems setObject:agentInfo forKey:_agentIdentify];
    
    // Check if current item is live channel or audio ondemand.
    NSArray *_dcList = nil;
    NSString *_playPath = qtEmptyString;
    // Radio stream
    QTRadioStreamBitRateType _bitRateType = QT_DATAMGR.userStreamBitRate;
    BOOL _highBitRate = NO;
    if ( _bitRateType == QTRadioStreamBitRateAuto ) {
        _highBitRate = [QT_NETWORK currentNetworkStatus] == QTNetworkByWifi;
    } else {
        _highBitRate = (_bitRateType == QTRadioStreamBitRateHigh);
    }
   
    if ( _highBitRate ) {
        _playPath = agentInfo.programItem.highRatePlayPath;
    } else {
        _playPath = agentInfo.programItem.lowRatePlayPath;
    }
    
    QTItemCategory _itemCategory = agentInfo.programItem.itemCategory;
    switch ( _itemCategory ) {
        case QTItemCategoryLive:
            _dcList = [QT_MEDIACENTER transcodeHLSCenterList];
            break;
        case QTItemCategoryReplay:
            _dcList = [QT_MEDIACENTER transcodeHLSCenterList];
            break;
        case QTItemCategoryAOD:
            _dcList = [QT_MEDIACENTER storageHLSCenterList];
            break;
        case QTItemCategoryDownload:
            _dcList = nil;
            break;
        case QTItemCategoryUnknow:
            ALog(@"Unknow category...cannot load.");
            return;
    }
    
    // Check if has been downloaded
    NSString *_resourcePath = [QT_DLMGR localFilePathWithResourceId:agentInfo.programItem.resourceId];
    if ( [_resourcePath length] > 0 ) {
        _dcList = nil;
        _playPath = _resourcePath;
    }
    
    //continue to listen to
    CGFloat _preProgress = 0.f;
    if ( _itemCategory != QTItemCategoryUnknow && _itemCategory != QTItemCategoryLive ) {
        _preProgress = [QT_DATAMGR getHistoryProgress:agentInfo.programItem];
    }
   
    // preparefor load
    [agentInfo.player prepareForPlayingPath:_playPath centerList:_dcList seekFrom:_preProgress];
    [_delegates objectsTryToPerformSelector:@selector(playerAgentBeginToLoadItem:withOptions:)
                                 withObject:agentInfo.programItem
                                 withObject:[agentInfo objectToJsonDict]];
    PYSingletonUnLock
}

// Play Control
// setting loading item need auto play
- (void)_setLoadingItem:(NSString *)agentId needAutoPlay:(BOOL)needAutoPlay __deprecated
{
    NSAssert(NO, @"The method has been deprecated");
    __builtin_unreachable();
}

// Stop current playing item
- (void)_stopCurrentPlayingItem:(BOOL)resetPlayer
{
    PYSingletonLock
    if ( _playingInfo == nil ) return;
    
    CGFloat _progress = (CGFloat)self.itemProgress.progress;
    CGFloat _playItemDuration = (CGFloat)self.itemDuration;
    
    if ( (_progress >= 5.f && _playingInfo != nil) || [_playingInfo.programItem isKindOfClass:[QTChannel class]] ) {
        // Add playing item info to history.
        // update the history.
        if ( _playingInfo.programItem.itemCategory == QTItemCategoryLive ) {
            id<QTChannel> _channel = self.channelItem;
            [QT_DATAMGR addHistoryItem:_channel];
        } else {
            [QT_DATAMGR addHistoryItem:_playingInfo.programItem];
            // Update the history progress
            ALog(@"_playItemDuration - _progress :%f",(_playItemDuration - _progress));
            if ( ((_playItemDuration - _progress) < 5.f) ) {
                [QT_DATAMGR addHistoryProgress:_playingInfo.programItem progress:0];
            } else {
                [QT_DATAMGR addHistoryProgress:_playingInfo.programItem progress:_progress];
            }
        }
        
        // Add Log
        [[QTRemoteLog shared]
         logPlayEventOfItem:_playingInfo.programItem withInfo:_playingInfo];
    }
    
    // stop current player
    if ( resetPlayer == YES ) {
        if ( _playingInfo != nil && _playingInfo.player != nil ) {
            [_playingInfo.player stopItem];
            [_playingInfo.player setDelegate:nil];
            _playStatus = QTPlayStatusPaused;
            
            [_delegates objectsTryToPerformSelector:@selector(playerAgentDidEndPlayOfItem:withOptions:)
                                         withObject:_playingInfo.programItem
                                         withObject:[_playingInfo objectToJsonDict]];
        }
        _playingInfo = nil;
    }
    
    PYSingletonUnLock
}

- (void)_checkCurrentPlayingInfoPlayerStatusAndPlay
{
    PYSingletonLock
    if ( _playingInfo == nil ) return;
    if ( _playingInfo.player == nil ) return;   // Not loaded yet
    if ( _playingInfo.player.status != QTPlayerStatusReady ) return;
    [_playingInfo.player playItem];
    _playStatus = QTPlayStatusPlaying;
    [_delegates objectsTryToPerformSelector:@selector(playerAgentDidStartToPlayItem:withOptions:)
                                 withObject:_playingInfo.programItem
                                 withObject:[_playingInfo objectToJsonDict]];
    
    // Cancel all other preloading item.
    [_currentPreLoadItems removeObjectForKey:_playingInfo.agentIdentify];
    [self _cancelPreloadLoadingItems];
    
    // Media Center Info Update
    NSMutableDictionary *_nowPlayingInfo = [NSMutableDictionary dictionary];
    [_nowPlayingInfo setObject:self.channelItem.name forKey:MPMediaItemPropertyTitle];
    [_nowPlayingInfo setObject:self.playingItem.name forKey:MPMediaItemPropertyAlbumTitle];
    [_nowPlayingInfo setObject:PYDoubleToObject(_playingInfo.programItem.itemDuration)
                        forKey:MPMediaItemPropertyPlaybackDuration];
    [_nowPlayingInfo setObject:PYDoubleToObject(1.f)
                        forKey:MPNowPlayingInfoPropertyPlaybackRate];
    UIImage *_artwork = [_playingInfo.userInfo objectForKey:kQTPlayAgentOptionArtworkImage];
    if ( _artwork == nil ) {
        _artwork = _defaultArtworkImage;
    }
    if ( _artwork != nil ) {
        MPMediaItemArtwork *_mpArtwork = [[MPMediaItemArtwork alloc] initWithImage:_artwork];
        [_nowPlayingInfo setObject:_mpArtwork forKey:MPMediaItemPropertyArtwork];
    }
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_nowPlayingInfo];
 
    PYSingletonUnLock
}
// Make the ready to play loading item to play.
- (void)_makeLoadedItemToPlay:(NSString *)agentId
{
    NSAssert(NO, @"The method has been deprecated");
    __builtin_unreachable();
}

// Cancel Last Loading item.
- (void)_cancelPreloadLoadingItems
{
    PYSingletonLock
    for ( QTPlayAgentInfo *_agentInfo in _currentPreLoadItems.allValues ) {
        _agentInfo.player.delegate = nil;
    }
    [_currentPreLoadItems removeAllObjects];
    PYSingletonUnLock
}

@end

