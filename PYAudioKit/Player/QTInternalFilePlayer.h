//
//  QTInternalFilePlayer.h
//  QTMedia
//
//  Created by Push Chen on 4/14/14.
//  Copyright (c) 2014 Shanghai MarkPhone Culture Media Co., Ltd. All rights reserved.
//

#import "QTPlayer.h"

@interface QTInternalFilePlayer : QTPlayer <AVAudioPlayerDelegate>
{
    AVAudioPlayer           *_iPlayer;
    CGFloat                 _stopPosition;
}

@end
