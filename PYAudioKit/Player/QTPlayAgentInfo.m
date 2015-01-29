//
//  QTPlayAgentInfo.m
//  QTRadioModel
//
//  Created by Push Chen on 8/28/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayAgentInfo.h"
#import "QTPlayAgent.h"

@implementation QTPlayAgentInfo

+ (NSString *)identifyOfId:(NSString *)objectId
{
    return [NSString stringWithFormat:@"%@+%@",
            NSStringFromClass([self class]), objectId];
}

// @synthesize agentIdentify;
@dynamic agentIdentify;
- (NSString *)agentIdentify
{
    return self.programItem.resourceId;
}

- (BOOL)isEqual:(id)object
{
    if ( ![object isKindOfClass:[QTPlayAgentInfo class]] )
        return NO;
    return [self.programItem.resourceId
            isEqualToString:((QTPlayAgentInfo *)object).programItem.resourceId];
}

@synthesize userInfo;
@synthesize player;
// Items
// must have
@synthesize beanIdentify, programItem, setIdentify, categoryIdentify;
@synthesize isSourceFromDownload, audioPlaySource;
@synthesize pausedTimes;
@synthesize startSeek, startTimeStamp, autoPlayNext;

// Deprecated
@dynamic beanItem;
- (QTBaseBean *)beanItem
{
    return (QTBaseBean *)self.programItem;
}
@dynamic mediaInfo;
- (QTMediaInfo *)mediaInfo
{
    return self.programItem.mediaInfo;
}
@dynamic itemPath;
- (NSArray *)itemPath
{
    return @[self.categoryIdentify, self.setIdentify, self.beanIdentify];
}
@dynamic itemCategory;
- (QTItemCategory)itemCategory
{
    return self.programItem.itemCategory;
}
@dynamic reconnectCount;
- (int)reconnectCount
{
    return self.player.reconnectCount;
}
@dynamic daysAgo;
- (int)daysAgo
{
    return 0;
}
@dynamic itemDuration;
- (CGFloat)itemDuration
{
    return self.programItem.itemDuration;
}
@dynamic urlParameters;
- (NSString *)urlParameters
{
    return qtEmptyString;
}
@dynamic audioBps;
- (int)audioBps
{
    return 0;
}
@dynamic stopWatch;
- (PYStopWatch *)stopWatch
{
    return nil;
}
@dynamic progress;
- (QTPlayProgress *)progress
{
    return nil;
}

- (void)replaceWithNewAgentInfo:(QTPlayAgentInfo *)info
{
    self.userInfo = [info.userInfo copy];
    self.beanIdentify = [info.beanIdentify copy];
    self.programItem = info.programItem;
    self.setIdentify = [info.setIdentify copy];
    self.categoryIdentify = [info.categoryIdentify copy];
    self.pausedTimes = info.pausedTimes;
    self.startSeek = info.startSeek;
    self.autoPlayNext = info.autoPlayNext;
    self.isSourceFromDownload = info.isSourceFromDownload;
    self.audioPlaySource = info.audioPlaySource;
}

#pragma mark --
#pragma mark PYObject

- (void)objectFromJsonDict:(NSDictionary *)jsonDict
{
    self.userInfo = [jsonDict objectForKey:kQTPlayAgentOptionUserInfo];
    if ( self.userInfo == nil ) self.userInfo = [NSDictionary dictionary];
    self.beanIdentify = [jsonDict stringObjectForKey:kQTPlayAgentOptionBeanIdentify];
    self.programItem = [jsonDict objectForKey:kQTPlayAgentOptionBeanItem];
    self.setIdentify = [jsonDict stringObjectForKey:kQTPlayAgentOptionSetIdentify];
    self.categoryIdentify = [jsonDict stringObjectForKey:kQTPlayAgentOptionCategoryIdentify];
    
    self.pausedTimes = [jsonDict intObjectForKey:kQTPlayAgentOptionPausedTimes withDefaultValue:0];
    
    self.startSeek = (float)[jsonDict doubleObjectForKey:kQTPlayAgentOptionStartSeek withDefaultValue:0.f];
    self.startTimeStamp = [jsonDict intObjectForKey:kQTPlayAgentOptionStartTimestamp withDefaultValue:0];
    self.autoPlayNext = [jsonDict boolObjectForKey:kQTPlayAgentOptionAutoPlayNext withDefaultValue:YES];
    self.isSourceFromDownload = [jsonDict boolObjectForKey:kQTPlayAgentOptionSourceFromDownload withDefaultValue:NO];
    self.audioPlaySource = [jsonDict intObjectForKey:kQTPlayAgentOptionAudioPlaySource
                                    withDefaultValue:QTAudioPlaySourceNormal];
}

- (NSDictionary *)objectToJsonDict
{
    NSMutableDictionary *_jsonDict = [NSMutableDictionary dictionary];
    if ( self.userInfo != nil ) {
        [_jsonDict setValue:self.userInfo forKey:kQTPlayAgentOptionUserInfo];
    }
    
    [_jsonDict setValue:self.beanIdentify forKey:kQTPlayAgentOptionBeanIdentify];
    if ( self.programItem != nil ) {
        [_jsonDict setValue:self.programItem forKey:kQTPlayAgentOptionBeanItem];
    }
    
    [_jsonDict setValue:self.setIdentify forKey:kQTPlayAgentOptionSetIdentify];
    [_jsonDict setValue:self.categoryIdentify forKey:kQTPlayAgentOptionCategoryIdentify];
    
    [_jsonDict setValue:PYIntToObject(self.pausedTimes) forKey:kQTPlayAgentOptionPausedTimes];
    
    [_jsonDict setValue:PYDoubleToObject(self.startSeek) forKey:kQTPlayAgentOptionStartSeek];
    [_jsonDict setValue:PYIntToObject(self.startTimeStamp) forKey:kQTPlayAgentOptionStartTimestamp];
    [_jsonDict setValue:PYBoolToObject(self.autoPlayNext) forKey:kQTPlayAgentOptionAutoPlayNext];
    [_jsonDict setValue:@(self.isSourceFromDownload) forKey:kQTPlayAgentOptionSourceFromDownload];
    [_jsonDict setObject:@(self.audioPlaySource) forKey:kQTPlayAgentOptionAudioPlaySource];
    return _jsonDict;
}

@end
