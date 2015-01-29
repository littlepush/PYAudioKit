
//
//  QTPlayAgent.h
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QTPlayer.h"
#import "QTHLSPlayer.h"
#import "QTPlayProgress.h"
#import "QTModels.h"

// Play Agent Support Options
extern NSString *kQTPlayAgentOptionUserInfo;                // The UserInfo Dict.
extern NSString *kQTPlayAgentOptionBeanIdentify;            // The bean identify. if the bean item is not in cache,
                                                            // use the identify to search from the server.
extern NSString *kQTPlayAgentOptionBeanItem;                // The bean item to play, set by the Agent.
extern NSString *kQTPlayAgentOptionStartSeek;               // Start with a seek time for ondemand item
extern NSString *kQTPlayAgentOptionSetIdentify;             // The Set Identify
extern NSString *kQTPlayAgentOptionCategoryIdentify;        // The category identify
extern NSString *kQTPlayAgentOptionStartTimestamp;          // For live program/channel, start timestamp
extern NSString *kQTPlayAgentOptionItemDuration;            // Item duration, auto write back by Agent.
extern NSString *kQTPlayAgentOptionReconnectCount;          // write back by Agent, reconnect count during playing.
extern NSString *kQTPlayAgentOptionPausedTimes;             // write back by Agent, paused times during playing.
extern NSString *kQTPlayAgentOptionProgress;                // write back by Agent, playing progress,
                                                            // should be a QTPlayProgress.
extern NSString *kQTPlayAgentOptionStopWatch;               // A stopwatch to gather play time info.
extern NSString *kQTPlayAgentOptionAutoPlayNext;            // If need to play next item when get EOF sig. Default is YES

extern NSString *kQTPlayAgentOptionArtworkImage;            // The Lock Screen Artwork image object. must be an UIImage

extern NSString *kQTPlayAgentOptionMustPlayBack;            // For download item this key should be set to NO, default is YES.
extern NSString *kQTPlayAgentOptionSourceFromDownload;      // @(BOOL), if the play item is from download folder
extern NSString *kQTPlayAgentOptionAudioPlaySource;         // @(Number), the source the audio been to play.

extern NSString *kQTPlayAgentOptionAudioBPS DEPRECATED_ATTRIBUTE; // Reserved
extern NSString *kQTPlayAgentOptionItemCategory DEPRECATED_ATTRIBUTE; // QTItemCategory Item, write back by Agent.
extern NSString *kQTPlayAgentOptionItemPath DEPRECATED_ATTRIBUTE; // Bean identify path.
extern NSString *kQTPlayAgentOptionDaysAgo DEPRECATED_ATTRIBUTE; // For replay item, specified days ago
extern NSString *kQTPlayAgentOptionMediaInfo DEPRECATED_ATTRIBUTE; // Media Info of a playable bean item. Write by the Agent.
extern NSString *kQTPlayAgentOptionURLParameters DEPRECATED_ATTRIBUTE; // For replay item's request paremter.

#define QT_PLAYAGENT                ([QTPlayAgent sharedAgent])

#define QTPlayAgentSeekFailedCode               100001

// Play Agent Statue
typedef enum {
    QTPlayStatusLoading     = 0,
    QTPlayStatusPlaying     = 1,
    QTPlayStatusPaused      = 2,
    QTPlayStatusError       = 3
} QTPlayStatus;

typedef NS_ENUM(NSInteger, QTAudioPlaySource) {
    QTAudioPlaySourceOther              = 0,
    QTAudioPlaySourceNormal,            // 1
    QTAudioPlaySourceCategoryRecommend, // 2
    QTAudioPlaySourceHomeRecommend,     // 3
    QTAudioPlaySourceFavorite,          // 4
    QTAudioPlaySourceSearch,            // 5
    QTAudioPlaySourceDownload,          // 6
    QTAudioPlaySourceHistory,           // 7
    QTAudioPlaySourceBooking,           // 8
    QTAudioPlaySourceHardwareRadio,     // 9
    QTAudioPlaySourceFakeLast,          // 10
    QTAudioPlaySourcePushNotification,  // 11
    QTAudioPlaySourceAlarm,             // 12
    QTAudioPlaySourceLastPlay,          // 13
    QTAudioPlaySourceBillboard,         // 14
    QTAudioPlaySourceHomeBigPic,        // 15
    QTAudioPlaySourceHomeSmallPic,      // 16
    QTAudioPlaySourceLiveSmallPic,      // 17
    QTAudioPlaySourceCategoryBigPic,    // 18
    QTAudioPlaySourceCategorySmallPic,  // 19
    QTAudioPlaySourceLoopView           // 20
};

// Predefinition
@protocol QTPlayAgentDelegate;
@class QTPlayAgentInfo;
@class QTZeroPlayer;

@interface QTPlayAgent : UIResponder < QTPlayerDelegate, AVAudioSessionDelegate >
{
    QTPlayAgentInfo                 *_playingInfo;
    QTPlayAgentInfo                 *_interruptionInfo __deprecated;
    
    //current loading item
    NSMutableDictionary             *_currentPreLoadItems;
    
    // Current using player.
    QTPlayer                        *_usingPlayer __deprecated;
    // Emergency Player( can be HLSPlayer or LSPlayer )
    QTPlayer                        *_emergencyPlayer;
    QTPlayStatus                    _beforeEmergencyStatue;

    BOOL                            _systemSessionPaused;
    BOOL                            _audioSystemPaused;
    
    QTPlayStatus                    _playStatus;
    // Delegate
    NSMutableArray                  *_delegates;
    
    // Default Artwork Image
    UIImage                         *_defaultArtworkImage;
    
    // Background Empty Audio File
    NSString                        *_backgroundEmptyAudioFilePath;
    //AVAudioPlayer                   *_zeroPlayer __deprecated;
    QTZeroPlayer                    *_zeroPlayer;
    
    NSTimer                         *_durationUpdateTimer;
    NSTimer                         *_autoShutdownTimer;
} 

@property (nonatomic, readonly) QTPlayAgentInfo           *playingInfo DEPRECATED_ATTRIBUTE;

@property (nonatomic, readonly) BOOL                    isPlaying;
@property (nonatomic, readonly) BOOL                    isActive;
@property (nonatomic, readonly) QTPlayStatus            status;

// Auto shut down event.
@property (nonatomic, readonly) BOOL                    willAutoShutdown;
@property (nonatomic, readonly) NSInteger               leftTimeToShutdown;
// > 0, shutdown count down second
// == 0, shutdown right now
// < 0, cancel shuting down progress
- (void)setAutoShutdownAfterSeconds:(NSInteger)second;

// Item Informations
@property (nonatomic, readonly) QTBaseBean              *playingItem;
@property (nonatomic, readonly) NSString                *playingIdentify;
@property (nonatomic, readonly) int                     itemDuration;
@property (nonatomic, readonly) CGFloat                 playedDuration;
@property (nonatomic, readonly) QTPlayProgress          *itemProgress;

@property (nonatomic, readonly) int                     pausedTimes;
@property (nonatomic, readonly) int                     reconnectedCount;
// The source the audio stream come from.
@property (nonatomic, readonly) NSInteger               audioPlaySource;

@property (nonatomic, readonly) NSString                *setIdentify DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly) id<QTChannel>           setItem DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly) NSString                *channelIdentify;
@property (nonatomic, readonly) id<QTChannel>           channelItem;
@property (nonatomic, readonly) NSString                *categoryIdentify;
@property (nonatomic, readonly) QTCategory              *categoryItem;
@property (nonatomic, readonly) BOOL                    isSourceFromDownloadFolder;

@property (nonatomic, readonly) QTItemCategory          itemCategory;
@property (nonatomic, readonly) NSDictionary            *userInfo;

@property (nonatomic, readonly) NSString                *urlParameters DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly) NSArray                 *itemPath   DEPRECATED_ATTRIBUTE;
// category channel program
@property (nonatomic, copy)     NSString                *playingCategoryIdentify DEPRECATED_ATTRIBUTE;
@property (nonatomic, copy)     NSString                *playingChannelIdentify DEPRECATED_ATTRIBUTE;
@property (nonatomic, copy)     NSString                *playingProgramIdentify DEPRECATED_ATTRIBUTE;

// Delegater
- (void)addDelegate:(id<QTPlayAgentDelegate>)delegate;
- (void)removeDelegate:(id<QTPlayAgentDelegate>)delegate;

// Set the default artwork image
@property (nonatomic, strong)   UIImage                 *defaultArtworkImage;

// Singleton item
+ (QTPlayAgent *)sharedAgent;

// make the audio mix with other application.
+ (void)enableAudioMixable:(BOOL)mix;

// Set the background zero volumn audio file path.
+ (void)bindZeroVolumnFile:(NSString *)filePath;

// Emergency Broadcast an item.
// When the item stop to play or failed to play, resume current playing status.
- (void)emergencyBroadcast:(NSString *)url;
- (void)pauseEmergencyBroadcast;
- (void)stopEmergencyBroadcast;

// Entry for load & play item.
- (void)loadItem:(NSString *)itemIdentify withOption:(NSDictionary *)options;
- (void)playItem:(NSString *)itemIdentify withOption:(NSDictionary *)options;

// Pause current playing item
- (void)pause;
// Resume current playing item.
- (void)resume;

// Switch to play next item or previous item in the set or category.
// For Live Channel/Program, switch to the next/prev channel in the category.
// For other item, switch in the set.
- (void)playNextItemContinueProgram:(BOOL)continueProgram __deprecated;
- (void)playPreviousItemContinueProgram:(BOOL)continueProgram __deprecated;

// More atomly api
- (void)playNextItemInChannel;
- (void)playPrevItemInChannel;
- (void)playNextItemInCategory;
- (void)playPrevItemInCategory;

// System Defined Play next or prev item. As the old API do.
- (void)systemPlayNextItem;
- (void)systemPlayPrevItem;

// Shut down the radio server
- (void)shutdownQTRadioService;

// Seek
- (void)seekWithSpecifiedProgress:(CGFloat)progess __deprecated;
- (void)seekto:(CGFloat)progress;

@end

@interface QTPlayAgent (PlayController)

// For Controller to do.
- (void)playItemWithAgentInfo:(QTPlayAgentInfo *)agentInfo __deprecated;
- (void)loadItemWithAgentInfo:(QTPlayAgentInfo *)agentInfo __deprecated;

@end

@protocol QTPlayAgentDelegate <NSObject>

@optional

// Auto shutdown callback
- (void)playerAgentWillShutdownAfterSeconds:(NSInteger)leftSecond;

// Start, Cancel & End Shutdown event
- (void)playerAgentStartToAutoShutdownAfterSeconds:(NSInteger)second;
- (void)playerAgentDidCancelAutoShutdownProgress;
- (void)playerAgentDidEndAutoShutdownProgress;

// The agent will start a pre-load event of specified item.
- (void)playerAgentPrepareToPlayItem:(id<QTProgramItem>)item withOptions:(NSDictionary *)options;

// Before playing an item, try to pre-load the item.
- (void)playerAgentBeginToLoadItem:(id<QTProgramItem>)item withOptions:(NSDictionary *)options;

// Did start to play item.
- (void)playerAgentDidStartToPlayItem:(id<QTProgramItem>)item withOptions:(NSDictionary *)options;

// Update the playing progress of item.
- (void)playerAgentUpdateProgress:(id<QTProgramItem>)playedProgress duration:(QTPlayProgress *)duration;

// Item has been paused ( by user or by system )
- (void)playerAgentDidPausedItem:(id<QTProgramItem>)item withOptions:(NSDictionary *)options;

// Play to end of the item. If the user change to play something else
// this message will not been invoked.
- (void)playerAgentDidEndPlayOfItem:(id<QTProgramItem>)item withOptions:(NSDictionary *)options;

// On error to play the specified item.
- (void)playerAgentFailedToPlayItem:(NSString *)itemIdentify
                        withOptions:(NSDictionary *)options
                              error:(NSError *)error;

// Unavailable
- (void)playerAgentBeginToLoadProgramListWithUserInfo:(NSDictionary *)userInfo UNAVAILABLE_ATTRIBUTE;
- (void)playerAgentBeginToPlayItemDirectlyWithUserInfo:(QTPlayAgentInfo *)agentInfo UNAVAILABLE_ATTRIBUTE ;

// Update the playing category of item.& Update the playing item.
- (void)playerAgentUpdateView:(NSDictionary *)options UNAVAILABLE_ATTRIBUTE;

// Emergency Item.
- (void)playerAgentBeginPlayingEmergencyItem:(NSString *)url;
- (void)playerAgentPauseEmergencyItem:(NSString *)url;
- (void)playerAgentEndPlayingEmergencyItem:(NSString *)url;
- (void)playerAgentFailedToPlayEmergencyItem:(NSString *)url;

@end

