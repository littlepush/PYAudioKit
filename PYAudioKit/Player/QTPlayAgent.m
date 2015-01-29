//
//  QTPlayAgent.m
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayAgent.h"
#import "QTPlayAgent+Internal.h"
#import "QTPlayAgentInfo.h"
#import "QTModels.h"
#import "QTDownloader.h"
#import "QTRemoteLog+QTMedia.h"
#import "QTDataManager+User.h"
#import "QTDataManager+Items.h"
#import "QTDataManager+ModelItems.h"
#import "QTZeroPlayer.h"

// Play Agent Support Options
NSString *kQTPlayAgentOptionUserInfo            = @"kQTPlayAgentOptionUserInfo";
NSString *kQTPlayAgentOptionBeanIdentify        = @"kQTPlayAgentOptionBeanIdentify";
NSString *kQTPlayAgentOptionBeanItem            = @"kQTPlayAgentOptionBeanItem";
NSString *kQTPlayAgentOptionItemPath            = @"kQTPlayAgentOptionItemPath";
NSString *kQTPlayAgentOptionDaysAgo             = @"kQTPlayAgentOptionDaysAgo";
NSString *kQTPlayAgentOptionStartSeek           = @"kQTPlayAgentOptionStartSeek";
NSString *kQTPlayAgentOptionSetIdentify         = @"kQTPlayAgentOptionSetIdentify";
NSString *kQTPlayAgentOptionCategoryIdentify    = @"kQTPlayAgentOptionCategoryIdentify";
NSString *kQTPlayAgentOptionStartTimestamp      = @"kQTPlayAgentOptionStartTimestamp";
NSString *kQTPlayAgentOptionItemDuration        = @"kQTPlayAgentOptionItemDuration";
NSString *kQTPlayAgentOptionItemCategory        = @"kQTPlayAgentOptionItemCategory";
NSString *kQTPlayAgentOptionURLParameters       = @"kQTPlayAgentOptionURLParameters";
NSString *kQTPlayAgentOptionAudioBPS            = @"kQTPlayAgentOptionAudioBPS";
NSString *kQTPlayAgentOptionReconnectCount      = @"kQTPlayAgentOptionReconnectCount";
NSString *kQTPlayAgentOptionPausedTimes         = @"kQTPlayAgentOptionPausedTimes";
NSString *kQTPlayAgentOptionStopWatch           = @"kQTPlayAgentOptionStopWatch";
NSString *kQTPlayAgentOptionProgress            = @"kQTPlayAgentOptionProgress";
NSString *kQTPlayAgentOptionMediaInfo           = @"kQTPlayAgentOptionMediaInfo";
NSString *kQTPlayAgentOptionAutoPlayNext        = @"kQTPlayAgentOptionAutoPlayNext";
NSString *kQTPlayAgentOptionArtworkImage        = @"kQTPlayAgentOptionArtworkImage";
NSString *kQTPlayAgentOptionSourceFromDownload  = @"kQTPlayAgentOptionSourceFromDownload";
NSString *kQTPlayAgentOptionAudioPlaySource     = @"kQTPlayAgentOptionAudioPlaySource";

// Audio Session Property Observer CallBack.
void _qtAudioSessionPropertyChangeListener(
                                           void                         *inUserData,
                                           AudioSessionPropertyID       inPropertyID,
                                           UInt32                       inPropertyValueSize,
                                           const void                   *inPropertyValue)
{
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
    if ( QT_PLAYAGENT.isPlaying != YES ) return;
    
    CFDictionaryRef	routeChangeDictionary = inPropertyValue;
    CFNumberRef routeChangeReasonRef =
    CFDictionaryGetValue (
                          routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
                          );
    SInt32 routeChangeReason;
    CFNumberGetValue (
                      routeChangeReasonRef,
                      kCFNumberSInt32Type,
                      &routeChangeReason
                      );
    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
        ALog(@"Output device removed, so application audio was paused.");
        [QT_PLAYAGENT pause];
    } else {
        ALog(@"A route change occurred that does not require pausing of application audio.");
    }
}

static QTPlayAgent *_gAgent = nil;

@implementation QTPlayAgent

- (void)_qtAudioSessionRouteChangeHandler:(NSNotification *)notification
{
    if ( self.isPlaying == NO ) return;
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonUnknown:
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            [self pause];
            break;
        default:
            break;
    }
}

@dynamic isPlaying;
- (BOOL)isPlaying
{
    return ((_playingInfo == nil) ?
            NO :
            ((_playingInfo.player == nil) ?
             NO :
             (_playingInfo.player.status == QTPlayerStatusPlaying)));
}

@dynamic isActive;
- (BOOL)isActive
{
    return (_playStatus != QTPlayStatusPaused && _playStatus != QTPlayStatusError);
}

@dynamic willAutoShutdown;
- (BOOL)willAutoShutdown
{
    return _autoShutdownTimer != nil;
}
@dynamic leftTimeToShutdown;
- (NSInteger)leftTimeToShutdown
{
    PYSingletonLock
    if ( _autoShutdownTimer == nil ) return -1;
    NSDictionary *_killerInfo = (NSDictionary *)_autoShutdownTimer.userInfo;
    if ( _killerInfo == nil ) return -1;
    PYStopWatch *_killerWatch = [_killerInfo objectForKey:@"ksw"];
    NSNumber *_killerSecond = [_killerInfo objectForKey:@"kt"];
    [_killerWatch tick];
    return (NSInteger)(_killerSecond.doubleValue - _killerWatch.seconds);
    PYSingletonUnLock
}
- (void)setAutoShutdownAfterSeconds:(NSInteger)second
{
    PYSingletonLock
    if ( _autoShutdownTimer != nil ) {
        [_autoShutdownTimer invalidate];
        _autoShutdownTimer = nil;
    }
    if ( second == 0 ) {
        for ( id _delg in _delegates ) {
            if ( [_delg respondsToSelector:@selector(playerAgentDidEndAutoShutdownProgress)] ) {
                [_delg playerAgentDidEndAutoShutdownProgress];
            }
        }
        [self shutdownQTRadioService];
        return;
    }
    if ( second < 0 ) {
        for ( id _delg in _delegates ) {
            if ( [_delg respondsToSelector:@selector(playerAgentDidCancelAutoShutdownProgress)] ) {
                [_delg playerAgentDidCancelAutoShutdownProgress];
            }
        }
        return;
    }
    PYStopWatch *_killerWatch = [PYStopWatch object];
    [_killerWatch start];
    NSDictionary *_killerInfo = @{@"ksw":_killerWatch, @"kt":@(second)};
    _autoShutdownTimer = [NSTimer timerWithTimeInterval:1.f
                                                 target:self
                                               selector:@selector(_autoShutdownTimerHandler:)
                                               userInfo:_killerInfo
                                                repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_autoShutdownTimer forMode:NSRunLoopCommonModes];
    
    for ( id _delg in _delegates ) {
        if ( [_delg respondsToSelector:@selector(playerAgentStartToAutoShutdownAfterSeconds:)] ) {
            [_delg playerAgentStartToAutoShutdownAfterSeconds:second];
        }
    }
    PYSingletonUnLock
}
- (void)_autoShutdownTimerHandler:(NSTimer *)timer
{
    PYSingletonLock
    NSDictionary *_killerInfo = (NSDictionary *)timer.userInfo;
    if ( _killerInfo == nil ) return;
    PYStopWatch *_killerWatch = [_killerInfo objectForKey:@"ksw"];
    NSNumber *_killerSecond = [_killerInfo objectForKey:@"kt"];
    [_killerWatch tick];
    if ( _killerWatch.seconds >= [_killerSecond doubleValue] ) {
        for ( id _delg in _delegates ) {
            if ( [_delg respondsToSelector:@selector(playerAgentDidEndAutoShutdownProgress)] ) {
                [_delg playerAgentDidEndAutoShutdownProgress];
            }
        }
        [self shutdownQTRadioService];
        if ( _autoShutdownTimer != nil ) {
            [_autoShutdownTimer invalidate];
            _autoShutdownTimer = nil;
        }
    } else {
        NSInteger _leftSecond = (NSInteger)(_killerSecond.doubleValue - _killerWatch.seconds);
        for ( id _delg in _delegates ) {
            if ( [_delg respondsToSelector:@selector(playerAgentWillShutdownAfterSeconds:)] ) {
                [_delg playerAgentWillShutdownAfterSeconds:_leftSecond];
            }
        }
    }
    PYSingletonUnLock
}

@synthesize playingInfo = _playingInfo;
@synthesize status = _playStatus;
// DEPRECATED
@synthesize playingCategoryIdentify = _playingCategoryIdentify;
@synthesize playingChannelIdentify = _playingChannelIdentify;
@synthesize playingProgramIdentify = _playingProgramIdentify;

@dynamic playingItem;
- (QTBaseBean *)playingItem
{
    PYSingletonLock
    return PYGETNIL(_playingInfo, programItem);
    PYSingletonUnLock
}
@dynamic playingIdentify;
- (NSString *)playingIdentify
{
    PYSingletonLock
    return PYGETNIL(_playingInfo, beanIdentify);
    PYSingletonUnLock
}

@dynamic itemDuration;
- (int)itemDuration
{
    PYSingletonLock
    id<QTProgramItem> _item = PYGETNIL(_playingInfo, programItem);
    return PYGETDEFAULT(_item, itemDuration, 0);
    PYSingletonUnLock
}

@dynamic playedDuration;
- (CGFloat)playedDuration
{
    PYSingletonLock
    QTPlayer *_player = PYGETNIL(_playingInfo, player);
    return PYGETDEFAULT(_player, playedTime, 0);
    PYSingletonUnLock
}

@dynamic itemProgress;
- (QTPlayProgress *)itemProgress
{
    PYSingletonLock
    QTPlayer *_player = PYGETNIL(_playingInfo, player);
    if ( _player == nil ) return nil;
    id<QTProgramItem> _program = PYGETNIL(_playingInfo, programItem);
    if ( _program == nil ) return nil;
    CGFloat _progress = _player.progress;
    QTPlayProgress *_qtProg = nil;
    if ( _program.itemCategory == QTItemCategoryLive ) {
        QTDate *_now = [QTDate date];
        _qtProg = [QTPlayProgress durationWithHour:_now.hour minute:_now.minute second:_now.second];
        NSInteger _now_sec = _now.timestamp - [_now beginOfDay].timestamp;
        NSInteger _start_sec = _program.startTime.timestamp - [_program.startTime beginOfDay].timestamp;
        _qtProg.progress = _now_sec - _start_sec;
    } else if ( _playingInfo) {
        QTDate *_start = [QTDate dateWithTimestamp:_playingInfo.startTimeStamp + _progress];
        _qtProg = [QTPlayProgress durationWithHour:_start.hour minute:_start.minute second:_start.second];
        _qtProg.progress = _progress;
    } else {
        // Left time
        int _leftTime = _program.itemDuration - _progress;
        int _hour = _leftTime / 3600;
        _leftTime -= (_hour * 3600);
        int _minute = _leftTime / 60;
        _leftTime -= (_minute * 60);
        int _second = _leftTime;
        _qtProg = [QTPlayProgress durationWithHour:_hour minute:_minute second:_second];
        _qtProg.progress = _progress;
    }
    return _qtProg;
    PYSingletonUnLock
}

@dynamic pausedTimes;
- (int)pausedTimes
{
    PYSingletonLock
    return PYGETDEFAULT(_playingInfo, pausedTimes, 0);
    PYSingletonUnLock
}

@dynamic reconnectedCount;
- (int)reconnectedCount
{
    PYSingletonLock
    QTPlayer *_player = PYGETNIL(_playingInfo, player);
    if ( _player == nil ) return 0;
    return _player.reconnectCount;
    PYSingletonUnLock
}

@dynamic audioPlaySource;
- (NSInteger)audioPlaySource
{
    PYSingletonLock
    return PYGETDEFAULT(_playingInfo, audioPlaySource, 0);
    PYSingletonUnLock
}
@dynamic channelItem;
- (id<QTChannel>)channelItem
{
    PYSingletonLock
    return (id<QTChannel>)[QT_DATAMGR dataForKey:_playingInfo.setIdentify];
    PYSingletonUnLock
}
@dynamic setItem;
- (id<QTChannel>)setItem
{
    return self.channelItem;
}
@dynamic channelIdentify;
- (NSString *)channelIdentify
{
    PYSingletonLock
    return PYGETNIL(_playingInfo, setIdentify);
    PYSingletonUnLock
}
@dynamic setIdentify;
- (NSString *)setIdentify
{
    return self.channelIdentify;
}

@dynamic categoryItem;
- (QTCategory *)categoryItem
{
    PYSingletonLock
    return (QTCategory *)[QT_DATAMGR dataForKey:_playingInfo.categoryIdentify];
    PYSingletonUnLock
}
@dynamic categoryIdentify;
- (NSString *)categoryIdentify
{
    PYSingletonLock
    return PYGETNIL(_playingInfo, categoryIdentify);
    PYSingletonUnLock
}

@dynamic itemCategory;
- (QTItemCategory)itemCategory
{
    PYSingletonLock
    id<QTProgramItem> _program = PYGETNIL(_playingInfo, programItem);
    if ( _program == nil ) return QTItemCategoryUnknow;
    return _program.itemCategory;
    PYSingletonUnLock
}

@dynamic isSourceFromDownloadFolder;
- (BOOL)isSourceFromDownloadFolder
{
    PYSingletonLock
    if ( _playingInfo == nil ) return NO;
    return _playingInfo.isSourceFromDownload;
    PYSingletonUnLock
}

@dynamic userInfo;
- (NSDictionary *)userInfo
{
    PYSingletonLock
    NSDictionary *_uifo = PYGETNIL(_playingInfo, userInfo);
    if ( _uifo == nil ) return @{};
    return _uifo;
    PYSingletonUnLock
}
@dynamic urlParameters;
- (NSString *)urlParameters
{
    return @"";
}
@dynamic itemPath;
- (NSArray *)itemPath
{
    return nil;
}

@synthesize defaultArtworkImage = _defaultArtworkImage;

- (id)init
{
    self = [super init];
    if ( self ) {
        //AVAudioSessionInterruptionNotification
        
        if ( SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0") ) {
            [NF_CENTER addObserver:self
                          selector:@selector(_audioSessionInterruptionHandler:)
                              name:AVAudioSessionInterruptionNotification
                            object:nil];
        } else {
            [[AVAudioSession sharedInstance] setDelegate:(id)self];
        }
        [[AVAudioSession sharedInstance]
         setCategory:AVAudioSessionCategoryPlayback
         error:nil];
        
        // The following property listener is only available in system version
        // elder than 7.0
        if ( SYSTEM_VERSION_LESS_THAN(@"6.0" ) ) {
            _Pragma("clang diagnostic push")
            _Pragma("clang diagnostic ignored \"-Wdeprecated\"")
            AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
                                            _qtAudioSessionPropertyChangeListener,
                                            NULL);
            _Pragma("clang diagnostic pop")
        } else {
            // AVAudioSessionRouteChangeNotification
            [NF_CENTER addObserver:self
                          selector:@selector(_qtAudioSessionRouteChangeHandler:)
                              name:AVAudioSessionRouteChangeNotification
                            object:nil];
        }
        
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        // Init 
        _currentPreLoadItems = [NSMutableDictionary dictionary];
        
        _delegates = [NSMutableArray array];
        
        _durationUpdateTimer = [NSTimer
                                scheduledTimerWithTimeInterval:1.f
                                target:self
                                selector:@selector(_progressUpdateTimer:)
                                userInfo:nil
                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_durationUpdateTimer forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)_progressUpdateTimer:(NSTimer *)timer
{
    if ( self.isPlaying == NO ) return;
    [_delegates objectsTryToPerformSelector:@selector(playerAgentUpdateProgress:duration:)
                                 withObject:_playingInfo.programItem
                                 withObject:self.itemProgress];
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    if ( event.type != UIEventTypeRemoteControl ) return;
    if ( _playingInfo == nil ) return;
    switch ( event.subtype ) {
        case UIEventSubtypeRemoteControlTogglePlayPause:
            if ( self.isPlaying ) {
                [self pause];
                [_zeroPlayer stop];
            } else {
                [self resume];
                [_zeroPlayer play];
            }
            break;
        case UIEventSubtypeRemoteControlPlay:
            [self resume];
            [_zeroPlayer play];
            break;
        case UIEventSubtypeRemoteControlPause:
            [self pause];
            [_zeroPlayer stop];
            break;
        case UIEventSubtypeRemoteControlStop:
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [self systemPlayNextItem];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [self systemPlayPrevItem];
            break;
        default:
            return;
    };
}

+ (QTPlayAgent *)sharedAgent
{
    PYSingletonLock
    if ( _gAgent == nil ) {
        _gAgent = [QTPlayAgent object];
    }
    return _gAgent;
    PYSingletonUnLock
}

PYSingletonDefaultImplementation;
PYSingletonAllocWithZone(_gAgent);

+ (void)enableAudioMixable:(BOOL)mix
{
    unsigned int _mix = (mix ? 1 : 0);
    if ( SYSTEM_VERSION_LESS_THAN(@"6.0") ) {
    //#warning Need to check if this will cause background play error.
        _Pragma("clang diagnostic push")
        _Pragma("clang diagnostic ignored \"-Wdeprecated\"")
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers,
                                sizeof(unsigned int),
                                &_mix);
        _Pragma("clang diagnostic pop")
    } else {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *setCategoryError = nil;
        AVAudioSessionCategoryOptions _option = (mix ?
                                                 AVAudioSessionCategoryOptionMixWithOthers :
                                                 AVAudioSessionCategoryOptionDuckOthers);
        if (![session setCategory:AVAudioSessionCategoryPlayback
                      withOptions:_option
                            error:&setCategoryError]) {
        }
    }
}

+ (void)bindZeroVolumnFile:(NSString *)filePath
{
    [QTPlayAgent sharedAgent]->_backgroundEmptyAudioFilePath = [filePath copy];
    [[QTPlayAgent sharedAgent] __initZeroPlayer];
}

- (void)__initZeroPlayer
{
    _zeroPlayer = [[QTZeroPlayer alloc] initWithAudioFilePath:_backgroundEmptyAudioFilePath];
    [_zeroPlayer play];
    return;
    /*
    NSURL *_zeroFileUrl = [NSURL fileURLWithPath:_backgroundEmptyAudioFilePath];
    NSError *_error;
    _zeroPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_zeroFileUrl error:&_error];
    if ( _error != nil ) {
        ALog(@"Error: %@", _error.localizedDescription);
        ALog(@"Failed to load zero volumn file, the application "
             @"may not play in background after receive a phone call.");
        return;
    }
    // Zero Volumn
    [_zeroPlayer setVolume:0];
    // Infinit
    [_zeroPlayer setNumberOfLoops:-1];
     */
}
#pragma mark --
#pragma mark Audio Session Delegate

- (void)beginInterruption
{
    ALog(@"Begin Interruption");
    [_zeroPlayer stop];
    IF ( self.isPlaying == NO ) return;
    IF ( _audioSystemPaused == YES ) return;
    _systemSessionPaused = YES;
    
    // _interruptionInfo = _playingInfo;
    // [self shutdownQTRadioService];
    [self _internalPause];
    
    //[self _internalPause];
}

- (void)endInterruption
{
    ALog(@"End Interruption");
    //[_zeroPlayer play];
    IF ( ! _systemSessionPaused ) return;
    IF ( _audioSystemPaused == YES ) return;
//    if ( _zeroPlayer != nil ) {
//        [_zeroPlayer play];
//    }
    [self _internalResume];
    //[self playItem:_interruptionInfo.beanIdentify withOption:[_interruptionInfo objectToJsonDict]];
    //[_controller playItemWithAgentInfo:_interruptionInfo];
    _systemSessionPaused = NO;
}

#pragma mark --
#pragma mark Instances
// Agent
- (void)addDelegate:(id<QTPlayAgentDelegate>)delegate
{
    PYSingletonLock
    if ( [_delegates containsObject:delegate] ) return;
    [_delegates addObject:delegate];
    PYSingletonUnLock
}

- (void)removeDelegate:(id<QTPlayAgentDelegate>)delegate
{
    PYSingletonLock
    if ( ![_delegates containsObject:delegate] ) return;
    [_delegates removeObject:delegate];
    PYSingletonUnLock
}

// Emergency Broadcast an item.
// When the item stop to play or failed to play, resume current playing status.
- (void)emergencyBroadcast:(NSString *)url
{
    PYSingletonLock
    if ( _emergencyPlayer != nil ) {
        [_emergencyPlayer stopItem];
        _emergencyPlayer = nil;
    }
    _beforeEmergencyStatue = _playStatus;
    [self pause];
    _emergencyPlayer = [QTHLSPlayer object];
    _emergencyPlayer.delegate = self;
    [_emergencyPlayer playUrl:url];
    PYSingletonUnLock
}
- (void)pauseEmergencyBroadcast
{
    PYSingletonLock
    if ( _emergencyPlayer == nil ) return;
    [_emergencyPlayer stopItem];
    PYSingletonUnLock
}
- (void)stopEmergencyBroadcast
{
    PYSingletonLock
    if ( _emergencyPlayer != nil ) {
        [_emergencyPlayer stopItem];
        _emergencyPlayer = nil;
    }
    if ( _beforeEmergencyStatue == QTPlayStatusPlaying ) {
        [self resume];
    }
    PYSingletonUnLock
}

// Entry for load & play item.
- (void)loadItem:(NSString *)itemIdentify withOption:(NSDictionary *)options
{
    PYSingletonLock
    QTPlayAgentInfo *_agentInfo = nil;
    @try {
        _agentInfo = [self
                      _generateFormatedAgentInfoForSpecifiedItem:itemIdentify
                      withOption:options];
    }
    @catch (NSException *exception) {
        //[[QTRemoteLog shared] playAgentFormatError:[NSString stringWithFormat:@"%@", itemIdentify]];
        ALog(@"Failed to generate agent info: %@", exception.reason);
        return;
    }
    if ( _agentInfo == nil ) return;
    if ( [_agentInfo isEqual:_playingInfo] ) {
        [_playingInfo replaceWithNewAgentInfo:_agentInfo];
        return;
    }
    
    // Check if is already loading...
    if ( [_currentPreLoadItems objectForKey:_agentInfo.agentIdentify] != nil ) return;
    
    // Start to load the item...on need
    [self _loadItem:_agentInfo];
    PYSingletonUnLock
}
- (void)playItem:(NSString *)itemIdentify withOption:(NSDictionary *)options
{
    PYSingletonLock
    if ( _systemSessionPaused ) {
        _systemSessionPaused = NO;
    }
    if ( _zeroPlayer.isRunning == NO ) {
        [_zeroPlayer play];
    }
    QTPlayAgentInfo *_agentInfo = nil;
    @try {
        _agentInfo = [self
                      _generateFormatedAgentInfoForSpecifiedItem:itemIdentify
                      withOption:options];
    }
    @catch (NSException *exception) {
        // [[QTRemoteLog shared] playAgentFormatError:[NSString stringWithFormat:@"%@", itemIdentify]];
        return;
    }
    if ( _agentInfo == nil ) return;
    if ( [_agentInfo isEqual:_playingInfo] ) {
        [_playingInfo replaceWithNewAgentInfo:_agentInfo];
        if ( _playingInfo.player == nil || _playingInfo.player.status == QTPlayerStatusError ) {
            [self _loadItem:_agentInfo];
        }
        [_delegates objectsTryToPerformSelector:@selector(playerAgentPrepareToPlayItem:withOptions:)
                                     withObject:_agentInfo.programItem
                                     withObject:[_agentInfo objectToJsonDict]];
        return;
    }
    [self _stopCurrentPlayingItem:YES];
    
    // Check if has loaded item
    QTPlayAgentInfo *_loadingInfo = [_currentPreLoadItems objectForKey:_agentInfo.agentIdentify];
    if ( _loadingInfo != nil ) {
        // Update the load cache item.
        [_loadingInfo replaceWithNewAgentInfo:_agentInfo];
        _playingInfo = _loadingInfo;
        [_delegates objectsTryToPerformSelector:@selector(playerAgentPrepareToPlayItem:withOptions:)
                                     withObject:_agentInfo.programItem
                                     withObject:[_agentInfo objectToJsonDict]];
        [self _checkCurrentPlayingInfoPlayerStatusAndPlay];
    } else {
        _playingInfo = _agentInfo;
        [_delegates objectsTryToPerformSelector:@selector(playerAgentPrepareToPlayItem:withOptions:)
                                     withObject:_agentInfo.programItem
                                     withObject:[_agentInfo objectToJsonDict]];
        [self _loadItem:_agentInfo];
    }
    if ( _agentInfo.programItem.itemCategory == QTItemCategoryLive &&
        [_agentInfo.programItem isKindOfClass:[QTChannel class]] ) {
        [QT_DATAMGR getPlayingLiveProgramOfLiveChannel:(QTChannel *)_agentInfo.programItem get:^(id object) {
            [QT_PLAYAGENT
             playItem:object
             withOption:@{
                          kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                          kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify,
                          kQTPlayAgentOptionSetIdentify:_agentInfo.beanIdentify
                          }];
//            id<QTProgramItem> _liveProg = (id<QTProgramItem>)[QT_DATAMGR dataForKey:object];
//            if ( [((id<QTProgramItem>)QT_PLAYAGENT.playingItem).resourceId isEqualToString:_liveProg.resourceId] ) {
//            }
        }];
    }
    PYSingletonUnLock
}

// Pause current playing item
- (void)pause
{
    PYSingletonLock
    ALog(@"Pause the audio session");
    // Try to play the zero file
//    if ( _zeroPlayer != nil && _zeroPlayer.isPlaying != NO ) {
//        [_zeroPlayer pause];
//    }
    _audioSystemPaused = YES;
    [self _internalPause];
    [self _stopCurrentPlayingItem:NO];
    PYSingletonUnLock
}
// Resume current playing item.
- (void)resume
{
    // If last pause/shutdown is caused by system, then manually invoke [endInterruption]
    if ( _systemSessionPaused == YES ) {
        [self endInterruption];
        return;
    }
    PYSingletonLock
    ALog(@"Resume the audio session");
    // Try to play the zero file
    /*
    if ( _zeroPlayer != nil && _zeroPlayer.isPlaying == NO ) {
        [_zeroPlayer play];
    }
     */
    [self _internalResume];
    _audioSystemPaused = NO;
    PYSingletonUnLock
}

- (void)playNextItemContinueProgram:(BOOL)continueProgram __deprecated
{
    NSAssert(NO, @"The method has been deprecated");
    __builtin_unreachable();
}

- (void)playPreviousItemContinueProgram:(BOOL)continueProgram __deprecated
{
    NSAssert(NO, @"The method has been deprecated");
    __builtin_unreachable();
}

- (void)playNextItemInChannel
{
    PYSingletonLock
    if ( _playingInfo == nil ) return;
    id<QTChannel> _channel = (id<QTChannel>)[QT_DATAMGR dataForKey:_playingInfo.setIdentify];
    if ( [_channel isKindOfClass:[QTChannel class]] ) {
        // Live Channel
        if ( _playingInfo.programItem.itemCategory == QTItemCategoryLive ) return;
        [QT_DATAMGR
         getNextLiveProgramWithCurrentItem:_playingInfo.beanIdentify
         inChannel:_playingInfo.setIdentify
         get:^(id object) {
             [QT_PLAYAGENT playItem:object
                         withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                      kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
        }];
    } else {
        [QT_DATAMGR
         getNextVirtualProgramWithCurrentItem:_playingInfo.beanIdentify
         inVirtualChannel:_playingInfo.setIdentify
         get:^(id object) {
            [QT_PLAYAGENT playItem:object
                        withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                     kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
        }];
    }
    PYSingletonUnLock
}

- (void)playPrevItemInChannel
{
    PYSingletonLock
    if ( _playingInfo == nil ) return;
    id<QTChannel> _channel = (id<QTChannel>)[QT_DATAMGR dataForKey:_playingInfo.setIdentify];
    if ( [_channel isKindOfClass:[QTChannel class]] ) {
        [QT_DATAMGR
         getPrevLiveProgramWithCurrentItem:_playingInfo.beanIdentify
         inChannel:_playingInfo.setIdentify
         get:^(id object) {
             [QT_PLAYAGENT playItem:object
                         withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                      kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
         }];
    } else {
        [QT_DATAMGR
         getPrevVirtualProgramWithCurrentItem:_playingInfo.beanIdentify
         inVirtualChannel:_playingInfo.setIdentify
         get:^(id object) {
             [QT_PLAYAGENT playItem:object
                         withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                      kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
        }];
    }
    PYSingletonUnLock
}

- (void)playNextItemInCategory
{
    PYSingletonLock
    id<QTChannel> _channel = (id<QTChannel>)[QT_DATAMGR dataForKey:_playingInfo.setIdentify];
    if ( ![_channel isKindOfClass:[QTChannel class]] ) return;
    [QT_DATAMGR getAllLiveChannelInCategory:_playingInfo.categoryIdentify get:^(id object) {
        NSArray *_channelList = (NSArray *)[QT_DATAMGR dataForKey:object];
        NSInteger _channelIndex = [_channelList indexOfObject:QT_PLAYAGENT.channelIdentify];
        if ( _channelIndex == NSNotFound ) return;
        _channelIndex += 1;
        if ( _channelIndex == [_channelList count] ) _channelIndex = 0;
        NSString *_nextChannel = [_channelList safeObjectAtIndex:_channelIndex];
        if ( [_nextChannel length] == 0 ) return;
        [QT_DATAMGR
         getPlayingLiveProgramWithLiveChannelIdentify:_nextChannel
         get:^(id object) {
             [QT_PLAYAGENT playItem:object
                         withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                      kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
         }];
    }];
    PYSingletonUnLock
}

- (void)playPrevItemInCategory
{
    PYSingletonLock
    id<QTChannel> _channel = (id<QTChannel>)[QT_DATAMGR dataForKey:_playingInfo.setIdentify];
    if ( ![_channel isKindOfClass:[QTChannel class]] ) return;
    [QT_DATAMGR getAllLiveChannelInCategory:_playingInfo.categoryIdentify get:^(id object) {
        NSArray *_channelList = (NSArray *)[QT_DATAMGR dataForKey:object];
        NSInteger _channelIndex = [_channelList indexOfObject:QT_PLAYAGENT.channelIdentify];
        if ( _channelIndex == NSNotFound ) return;
        _channelIndex -= 1;
        if ( _channelIndex < 0 ) _channelIndex = [_channelList count] - 1;
        NSString *_prevChannel = [_channelList safeObjectAtIndex:_channelIndex];
        if ( [_prevChannel length] == 0 ) return;
        [QT_DATAMGR
         getPlayingLiveProgramWithLiveChannelIdentify:_prevChannel
         get:^(id object) {
             [QT_PLAYAGENT playItem:object
                         withOption:@{kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo,
                                      kQTPlayAgentOptionCategoryIdentify:QT_PLAYAGENT.categoryIdentify}];
         }];
    }];
    PYSingletonUnLock
}

- (void)_playNextItemInDownloadFolder
{
    PYSingletonLock
    NSArray *_list = [QT_DLMGR itemListOfFolderContainsSpecifiedItem:_playingInfo.programItem.beanIdentify];
    if ( [_playingInfo.programItem isKindOfClass:[QTLiveProgram class]] ) {
        // For live program in download folder, just find the next item in list.
        NSInteger _index = [_list indexOfObject:_playingInfo.programItem.beanIdentify];
        NSInteger _nextIndex = (_index + 1);
        if ( _index == NSNotFound ) {
            _nextIndex = 0;
        }
        if ( _nextIndex >= [_list count] ) _nextIndex = 0;
        NSString *_nextIdentify = [_list safeObjectAtIndex:_nextIndex];
        if ( [_nextIdentify length] == 0 ) return;
        [QT_PLAYAGENT playItem:_nextIdentify withOption:@{
                                                          kQTPlayAgentOptionSourceFromDownload:@(YES),
                                                          kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo
                                                          }];
    } else {
        [QT_DATAMGR orderList:_list withVirtualChannel:_playingInfo.setIdentify resultList:^(id object) {
            NSArray *_result = (NSArray *)object;
            NSInteger _index = [_result indexOfObject:QT_PLAYAGENT.playingIdentify];
            NSInteger _nextIndex = (_index + 1);
            if ( _index == NSNotFound ) {
                _nextIndex = 0;
            }
            if ( _nextIndex >= [_result count] ) _nextIndex = 0;
            NSString *_nextIdentify = [_result safeObjectAtIndex:_nextIndex];
            if ( [_nextIdentify length] == 0 ) return;
            [QT_PLAYAGENT playItem:_nextIdentify withOption:@{
                                                              kQTPlayAgentOptionSourceFromDownload:@(YES),
                                                              kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo
                                                              }];
        }];
    }
    PYSingletonUnLock
}

- (void)_playPrevItemInDownloadFolder
{
    PYSingletonLock
    NSArray *_list = [QT_DLMGR itemListOfFolderContainsSpecifiedItem:_playingInfo.programItem.beanIdentify];
    if ( [_playingInfo.programItem isKindOfClass:[QTLiveProgram class]] ) {
        // For live program in download folder, just find the next item in list.
        NSInteger _index = [_list indexOfObject:_playingInfo.programItem.beanIdentify];
        NSInteger _prevIndex = _index - 1;
        if ( _index == NSNotFound ) {
            _prevIndex = 0;
        }
        if ( _prevIndex < 0 ) _prevIndex = [_list count] - 1;
        NSString *_prevIdentify = [_list safeObjectAtIndex:_prevIndex];
        if ( [_prevIdentify length] == 0 ) return;
        [QT_PLAYAGENT playItem:_prevIdentify withOption:@{
                                                          kQTPlayAgentOptionSourceFromDownload:@(YES),
                                                          kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo
                                                          }];
    } else {
        [QT_DATAMGR orderList:_list withVirtualChannel:_playingInfo.setIdentify resultList:^(id object) {
            NSArray *_result = (NSArray *)object;
            NSInteger _index = [_result indexOfObject:QT_PLAYAGENT.playingIdentify];
            NSInteger _prevIndex = _index - 1;
            if ( _index == NSNotFound ) {
                _prevIndex = 0;
            }
            if ( _prevIndex < 0 ) _prevIndex = [_result count] - 1;
            NSString *_prevIdentify = [_result safeObjectAtIndex:_prevIndex];
            if ( [_prevIdentify length] == 0 ) return;
            [QT_PLAYAGENT playItem:_prevIdentify withOption:@{
                                                              kQTPlayAgentOptionSourceFromDownload:@(YES),
                                                              kQTPlayAgentOptionUserInfo:QT_PLAYAGENT.userInfo
                                                              }];
        }];
    }
    PYSingletonUnLock
}

- (void)systemPlayNextItem
{
    PYSingletonLock
    // Do different operator for download source
    if ( _playingInfo.isSourceFromDownload ) {
        [self _playNextItemInDownloadFolder];
        return;
    }
    
    if ( [self.channelItem isKindOfClass:[QTVirtualChannel class]] ) {
        [self playNextItemInChannel];
    } else if ( [self.channelItem isKindOfClass:[QTChannel class]] ) {
        [self playNextItemInCategory];
    }
    PYSingletonUnLock
}

- (void)systemPlayPrevItem
{
    PYSingletonLock
    // Do different operator for download source
    if ( _playingInfo.isSourceFromDownload ) {
        [self _playPrevItemInDownloadFolder];
        return;
    }
    
    if ( [self.channelItem isKindOfClass:[QTVirtualChannel class]] ) {
        [self playPrevItemInChannel];
    } else if ( [self.channelItem isKindOfClass:[QTChannel class]] ) {
        [self playPrevItemInCategory];
    }
    PYSingletonUnLock
}

// Shut down the radio server
- (void)shutdownQTRadioService
{
    @synchronized(self) {
        [self _stopCurrentPlayingItem:YES];
        
        _playingInfo = nil;
        // Try to play the zero file
        /*
        if ( _zeroPlayer != nil ) {
            [_zeroPlayer stop];
        }*/
        
        if ( _autoShutdownTimer != nil ) {
            [_autoShutdownTimer invalidate];
            _autoShutdownTimer = nil;
        }
        
        _playStatus = QTPlayStatusPaused;
    }
}

// Seek
- (void)seekWithSpecifiedProgress:(CGFloat)progess
{
    [self seekto:progess];
}
- (void)seekto:(CGFloat)progress
{
    PYSingletonLock
    if ( _playingInfo == nil || _playingInfo.player == nil ) return;
    if ( _playingInfo.player.status != QTPlayerStatusPlaying ) return;
    [_playingInfo.player seekWithProgress:progress];
    PYSingletonUnLock
}

@end
@implementation QTPlayAgent (PlayController)

- (void)playItemWithAgentInfo:(QTPlayAgentInfo *)agentInfo __deprecated
{
    [self _playItem:agentInfo];
}

- (void)loadItemWithAgentInfo:(QTPlayAgentInfo *)agentInfo __deprecated
{
    [self _loadItem:agentInfo];
}

@end

