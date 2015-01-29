//
//  QTPlayProgress.h
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QTPlayProgress : NSObject

@property (nonatomic, assign)   NSInteger       hour;
@property (nonatomic, assign)   NSInteger       minute;
@property (nonatomic, assign)   NSInteger       second;
@property (nonatomic, assign)   NSInteger       progress;

// Duration Creator.
+ (QTPlayProgress *)durationWithHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s;
+ (QTPlayProgress *)durationWithTime:(NSInteger)time;

@end
