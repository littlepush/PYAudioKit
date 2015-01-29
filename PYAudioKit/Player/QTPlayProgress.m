//
//  QTPlayProgress.m
//  QTRadioModel
//
//  Created by Push Chen on 8/27/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayProgress.h"

@implementation QTPlayProgress

@synthesize hour, minute, second, progress;

+ (QTPlayProgress *)durationWithHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s
{
    QTPlayProgress *_duration = [QTPlayProgress object];
    _duration.hour = h;
    _duration.minute = m;
    _duration.second = s;
    return _duration;
}

+ (QTPlayProgress *)durationWithTime:(NSInteger)time
{
    int _hour = (int)time / 3600;
    time -= (_hour * 3600);
    int _minute = (int)time / 60;
    time -= (_minute * 60);
    return [QTPlayProgress durationWithHour:_hour minute:_minute second:time];
}

@end
