# PYAudioKit
A simple audio recorder and player for iOS.

<font color='gray'>*This is a CocoaPods project.*</font>

## Player
The player support both HLS audio and local file audio.
Usually, we just need to invoke `[_player playUrl:[NSURL URLWithString:@"..."]` to play a specified audio stream.
For an http live stream(HLS), the player will use `AVPlayer` and `AVPlayerItem` to load audio data and play it. It will check the status of the item use KVO.
For a local audio file, the player will use `AVAudioPlayer` to play, which is very simple.

We can use `[prepareUrl:seekFrom:autoPlay:]` and set `autoPlay` to `NO` to load the stream buffer only and not start the audio session.
Or we can set the `seekFrom` to tell the player to start play at specified position of the audio stream.

The HLS player will check the buffer status and will automatically recover from a network broken.

## Recorder
The recorder use `AudioQueueRef` to record. The audio format and the file format should be set at initialization.
When enabled the meter fetching, the recorder will invoke the delegate 60 times per second, and return the first channel's audio weight.
You can use `[startToGatherEnvorinmentSound]` and `[startMeterFetching]` to build a dynamic graph for background envorinment.

## Install
1. Create 'Podfile' or modify the file under the root path of your Xcode project
2. Add the following line before `end`

  > pod "PYAudioKit", "~> 0.3"
3. Run `pod install` or `pod update` to get the source code
4. open *.xcworkspcae

## Example

    #import <PYAudioKit/PYAudioKit.h>
    
    @interface MyViewController {
        PYAudioPlayer         *_audioPlayer;
        PYAudioRecorder       *_audioRecorder;
        UIButton              *_recordBtn;
    }
    @end
    
    @implementation MyViewController
    - (void)viewDidLoad {
        [super viewDidLoad];
        // Initialize the player and recorder
        _recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_recordBtn setBackgroundColor:[UIColor blueColor]];
        [_recordBtn setFrame:CGRectMake(80, 80, 160, 88)];
        [_recordBtn addTarget:self action:@selector(actionTouchDown:)
             forControlEvents:UIControlEventTouchDown];
        [_recordBtn addTarget:self action:@selector(actionTouchUpInside:)
             forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubView:_recordBtn];
    }
    
    - (void)actionTouchDown:(id)sender {
        // the recorder use m4a format, default with 2 channels, 8000 sample rate
        _audioRecorder = [PYAudioRecorder 
                          audioRecorderWithFormat:aqPYAudioRecorderFormatMPEG4AAC 
                          fileType:kAudioFileMPEG4Type];
        [_audioRecorder startToRecord];
    }
    
    - (void)actionTouchUpInside:(id)sender {
        if ( _audioRecorder == nil ) return;
        NSString *_savedAudioPath = [_audioRecorder stopRecordAndSaveWithFileName:@"example.m4a"];
        
        // Play the audio
        _audioPlayer = [PYAudioPlayer object];
        [_audioPlayer playUrl:[NSURL fileURLWithPath:_savedAudioPath]];
    }
    
    @end
    
