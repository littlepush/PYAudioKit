//
//  QTInternalHLSPlayer.h
//  QTMedia
//
//  Created by Push Chen on 4/14/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTPlayer.h"

extern NSString *const  kQTPlayerPropertyStatus;
extern NSString *const  kQTPlayerPropertyDuration;
extern NSString *const  kQTPlaeryPropertyBufferEmpty;
extern NSString *const  kQTPlayerPropertyTimedMetadata;

@interface QTInternalHLSPlayer : QTPlayer
{
    AVPlayer                    *_iPlayer;
    AVPlayerItem                *_iItem;
    CGFloat                     _disconnectPosition;
}

@end
