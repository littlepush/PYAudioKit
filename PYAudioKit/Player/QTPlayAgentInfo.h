//
//  QTPlayAgentInfo.h
//  QTRadioModel
//
//  Created by Push Chen on 8/28/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import <QTCore/QTCore.h>
#import "QTMediaInfo.h"
#import "QTPlayProgress.h"
#import "QTPlayer.h"
#import "QTModels.h"

@interface QTPlayAgentInfo : NSObject<PYObject>

// The Player.
@property (nonatomic, strong)   QTPlayer            *player;

// The key to identify an agent item.
@property (nonatomic, readonly) NSString            *agentIdentify;

// kQTPlayAgentOptionUserInfo
@property (nonatomic, strong)   NSDictionary        *userInfo;

// Tell if is playing local file even not from download
@property (nonatomic, assign)   BOOL                isLocalFile;

#pragma mark -- 
#pragma mark Must-Have Properties.
// The Bean identify.
@property (nonatomic, copy)     NSString            *beanIdentify;
// The Bean Item for the agent to play.
@property (nonatomic, strong)   QTBaseBean          *beanItem DEPRECATED_ATTRIBUTE;
// We use [programItem] to replace [beanItem], which contains the [itemCategory] info
// And lots of other important properties
@property (nonatomic, strong)   id<QTProgramItem>   programItem;
// kQTPlayAgentOptionMediaInfo
@property (nonatomic, strong)   QTMediaInfo         *mediaInfo  DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionItemPath
@property (nonatomic, strong)   NSArray             *itemPath   DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionSetIdentify
@property (nonatomic, copy)     NSString            *setIdentify;
// kQTPlayAgentOptionCategoryIdentify
@property (nonatomic, copy)     NSString            *categoryIdentify;
// kQTPlayAgentOptionItemCategory
@property (nonatomic, assign)   QTItemCategory      itemCategory DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionSourceFromDownload
@property (nonatomic, assign)   BOOL                isSourceFromDownload;
// kQTPlayAgentOptionAudioPlaySource
@property (nonatomic, assign)   NSInteger           audioPlaySource;

#pragma mark --
#pragma mark Agent Set Properties.
// kQTPlayAgentOptionReconnectCount, can be read from the player
@property (nonatomic, assign)   int                 reconnectCount DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionPuasedTimes
@property (nonatomic, assign)   int                 pausedTimes;
// kQTPlayAgentOptionPorgress, can be read from the player
@property (nonatomic, strong)   QTPlayProgress      *progress DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionStopWatch
@property (nonatomic, strong)   PYStopWatch         *stopWatch DEPRECATED_ATTRIBUTE;

#pragma mark --
#pragma mark Other Info for play.
// kQTPlayAgentOptionDaysAgo
@property (nonatomic, assign)   int                 daysAgo DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionStartSeek
@property (nonatomic, assign)   float               startSeek;
// kQTPlayAgentOptionStartTimestamp
@property (nonatomic, assign)   int                 startTimeStamp;
// kQTPlayAgentOptionItemDuration
@property (nonatomic, assign)   float               itemDuration DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionURLParameters
@property (nonatomic, copy)     NSString            *urlParameters DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionAudioBPS
@property (nonatomic, assign)   int                 audioBps DEPRECATED_ATTRIBUTE;
// kQTPlayAgentOptionAutoPlayNext
@property (nonatomic, assign)   BOOL                autoPlayNext;

// Replace with the new agent info, the player will remine the old one.
- (void)replaceWithNewAgentInfo:(QTPlayAgentInfo *)info;

@end
