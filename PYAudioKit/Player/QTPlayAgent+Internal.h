//
//  QTPlayAgent+Internal.h
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayAgent.h"

@interface QTPlayAgent (Internal)

- (QTPlayAgentInfo *)_generateFormatedAgentInfoForSpecifiedItem:(NSString *)itemIdentify
                                                     withOption:(NSDictionary *)options;

// Play & Load
- (void)_playItem:(QTPlayAgentInfo *)agentInfo __deprecated;
- (void)_loadItem:(QTPlayAgentInfo *)agentInfo;

// Audio Sessionn Notification Handler
- (void)_audioSessionInterruptionHandler:(NSNotification *)notify;

// setting loading item need auto play
- (void)_setLoadingItem:(NSString *)agentId needAutoPlay:(BOOL)needAutoPlay __deprecated;

// Stop current playing item
- (void)_stopCurrentPlayingItem:(BOOL)resetPlayer;

// Make the ready to play loading item to play.
- (void)_makeLoadedItemToPlay:(NSString *)agentId __deprecated;
- (void)_checkCurrentPlayingInfoPlayerStatusAndPlay;

// Cancel pre Loading item.
- (void)_cancelPreloadLoadingItems;

// Internal pause.
- (void)_internalPause;

// Internal Resume
- (void)_internalResume;

@end
