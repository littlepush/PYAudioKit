//
//  PYAudioRecorder.h
//  PYAudioKit
//
//  Created by Push Chen on 1/28/15.
//  Copyright (c) 2015 PushLab. All rights reserved.
//

/*
 LGPL V3 Lisence
 This file is part of cleandns.
 
 PYAudioKit is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 PYData is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with cleandns.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 LISENCE FOR IPY
 COPYRIGHT (c) 2013, Push Chen.
 ALL RIGHTS RESERVED.
 
 REDISTRIBUTION AND USE IN SOURCE AND BINARY
 FORMS, WITH OR WITHOUT MODIFICATION, ARE
 PERMITTED PROVIDED THAT THE FOLLOWING CONDITIONS
 ARE MET:
 
 YOU USE IT, AND YOU JUST USE IT!.
 WHY NOT USE THIS LIBRARY IN YOUR CODE TO MAKE
 THE DEVELOPMENT HAPPIER!
 ENJOY YOUR LIFE AND BE FAR AWAY FROM BUGS.
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern AudioStreamBasicDescription aqPYAudioRedorcerFormatPCM;
extern AudioStreamBasicDescription aqPYAudioRecorderFormatMPEG4AAC;

@protocol PYAudioRecorderDelegate;

/*!
 @class PYAudioRecorder
 @brief This is the audio recorder object with background envorinment sound catching.
        Also, when recording, it will output the first channel's meter value.
        The final output audio file is in $(DOCUMENT_PATH)/audiofile.{type}
        Default record format is <code>kAudioFormatMPEG4AAC</code> with 16000 simple rate and 2 channels
 */
@interface PYAudioRecorder : NSObject

/*!
 @brief the delegate
 */
@property (nonatomic, assign)   id<PYAudioRecorderDelegate> delegate;
/*!
 @brief temp file path to store current recording audio file, will be removed after stop and save current session
 */
@property (nonatomic, readonly) NSString            *tempFilePath;
/*!
 @brief the final output audio file path, the file name is set by <code>[stopRecordAndSaeWithFileName:]</code>
 */
@property (nonatomic, readonly) NSString            *audioPath;
/*!
 @brief the status of current record object.
 */
@property (nonatomic, readonly) BOOL                isRecording;
/*!
 @brief for envorinment sound, the meter will be scaled with specified rate, default is 0.45, the rate value should between 0 and 1
 */
@property (nonatomic, assign)   float               envSoundMeterRate;  // 0 - 1
/*!
 @brief current record format structure.
 */
@property (nonatomic, readonly) AudioStreamBasicDescription recordFormat;
/*!
 @brief last error for audio recording
 */
@property (nonatomic, readonly) NSError             *lastError;

/*!
 @brief create an audio recorder with specified recording format.
 @param format: the record format struct.
 @return the instance of the recorder object or nil
 */
+ (instancetype)audioRecorderWithFormat:(AudioStreamBasicDescription)format fileType:(AudioFileTypeID)fileType;

/*!
 @brief start to fetch audio meter. Will invoke the delegate 60 times one second
 */
- (void)startMeterFetching;
/*!
 @brief stop fetching audio meter.
 */
- (void)stopMeterFetching;

/*
 @breif start to record audio
 */
- (BOOL)startToRecord;
/*
 @brief Tell the recorder to stop and safe the audio data to specified file path.
 */
- (NSString *)stopRecordAndSaveWithFileName:(NSString *)filename;

/*!
 @brief Generate a full path for specified filename under the audio storage folder.
 @discussion The file maybe not existed.
 */
+ (NSString *)audioPathWithFileName:(NSString *)filename;

/*!
 @brief start to gather envorinment sound, this operation will not save any data.
 */
- (BOOL)startToGatherEnvorinmentSound;

@end

@protocol PYAudioRecorderDelegate <NSObject>

@optional

/*!
 @brief When invoke <code>startMeterFetching:</code>, will invoke this message 60 times each second.
 */
- (void)audioRecorder:(PYAudioRecorder *)recorder updateMeter:(float)meter;

@end

// @littlepush
// littlepush@gmail.com
// PYLab
