//
//  QTHLSPlayer.h
//  QTRadioModel
//
//  Created by Push Chen on 5/6/13.
//  Copyright (c) 2013 Markphone Culture Media Co.Ltd. All rights reserved.
//

#import "QTPlayer.h"

@class QTInternalHLSPlayer;
@class QTInternalFilePlayer;

// Http Live Stream Player.
@interface QTHLSPlayer : QTPlayer < QTPlayerDelegate >
{
    // The selected player
    QTPlayer                        *_selectedPlayer;
}

@end
