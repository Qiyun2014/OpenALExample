
//
//  IDYAudioManager.m
//  IYNAudioExample
//
//  Created by qiyun on 17/1/13.
//  Copyright © 2017年 qiyun. All rights reserved.
//

#import "IDYAudioManager.h"
@import AVFoundation;

@implementation IDYAudioManager{
    
    AVAudioEngine               *_engine;       // 引擎
    
    AVAudioUnitSampler          *_sampler;      // 采样音频单元
    AVAudioUnitDistortion       *_distortion;   // 失真
    AVAudioUnitReverb           *_reverb;       // 混响
    AVAudioPlayerNode           *_player;       // 音节
    
    AVAudioSequencer            *_sequencer;    // 音序器
    AVAudioPCMBuffer            *_playerLoopBuffer;  // provides a number of methods useful for manipulating buffers of audio in PCM format
    
    NSString                    *_audioFilePath;
    
    double                      _sequencerTrackLengthSeconds;
    
    BOOL                        _isRecording;
    BOOL                        _isRecordingSelected;
    
    // mananging session and configuration changes
    BOOL                        _isSessionInterrupted;
    BOOL                        _isConfigChangePending;
}

@synthesize stereoPan = _stereoPan;
@synthesize masterGain = _masterGain;
@synthesize globalTuning = _globalTuning;
@synthesize numberOfLoops = _numberOfLoops;
@synthesize muted = _muted;
@synthesize soloed = _soloed;
@synthesize offsetTime = _offsetTime;
@synthesize currentPositionInSeconds = _currentPositionInSeconds;
@synthesize rate = _rate;
@synthesize nodeVolume = _nodeVolume;


- (id)initWithAudioFileOfUrlString:(NSString *)urlString{
    
    if (self == [super init]) {
        
        _audioFilePath = urlString;
        [self initWithAudioSession];

        _isSessionInterrupted = NO;
        _isConfigChangePending = NO;
        
        _isRecording = NO;
        _isRecordingSelected = NO;
        
        [self initWithPlayerNode];
        [self initWithUnitSampler];
        
        [self initWithUnitDistortion];
        [self initWithUnitReverb];

        [self initWithEngine];
        [self initWithSequencer];
        
        // sign up for notifications from the engine if there's a hardware config change
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioEngineConfigurationChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
           
                                                          // if we've received this notification, something has changed and the engine has been stopped
                                                          // re-wire all the connections and start the engine
                                                          _isConfigChangePending = YES;
                                                          
                                                          if (!_isSessionInterrupted) {
                                                              
                                                              NSLog(@"Received a %@ notification!", AVAudioEngineConfigurationChangeNotification);
                                                              [self initWithEngine];
                                                              [self startEngine];

                                                          }else{

                                                              NSLog(@"Session is interrupted, deferring changes");
                                                          }
        }];
        
        [self startEngine];
    }
    return self;
}


#pragma mark    -   get/set method

// 调整失真预设
- (void)setDistortionPreset:(IDYAudioDistortionPreset)distortionPreset{
    
    _distortionPreset = distortionPreset;
    [_distortion loadFactoryPreset:(AVAudioUnitDistortionPreset)_distortionPreset];
}

// 混响预设
- (void)setUnitReverbPreset:(IDYAudioUnitReverbPreset)unitReverbPreset{
    
    _unitReverbPreset = unitReverbPreset;
    [_reverb loadFactoryPreset:(AVAudioUnitReverbPreset)_unitReverbPreset];
}

// 音量
- (void)setVolume:(float)volume{
    
    _volume = volume;
    _player.volume = _volume;
}


#pragma mark    -   init configure method

- (void)initWithEngine{
    
    if (!_engine) {
        
        [self initWithPCMBuffer];

        /* An AVAudioEngine contains a group of connected AVAudioNodes ("nodes"), each of which performs an audio signal generation, processing, or input/output task. */
        _engine = [[AVAudioEngine alloc] init];
        
        /*  To support the instantiation of arbitrary AVAudioNode subclasses, instances are created externally to the engine, but are not usable until they are attached to the engine via the attachNode method. */
        [_engine attachNode:_sampler];
        [_engine attachNode:_distortion];
        [_engine attachNode:_reverb];
        [_engine attachNode:_player];
    }
    
    // The engine's optional singleton main mixer node.
    AVAudioMixerNode    *mixerNode = [_engine mainMixerNode];
    
    // Initialize to deinterleaved float with the specified sample rate and channel count. If the format specifies more than 2 channels, this method fails (returns nil).
    AVAudioFormat *audioFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    AVAudioFormat *playerFormat = _playerLoopBuffer.format;
    
    // connect the player to the reverb
    [_engine connect:_player to:_reverb format:playerFormat];
    
    // connect the reverb effect to mixer input bus 0
    [_engine connect:_reverb to:mixerNode fromBus:0 toBus:0 format:playerFormat];
    
    // connect the distortion effect to mixer input bus 2
    [_engine connect:_distortion to:mixerNode fromBus:0 toBus:2 format:audioFormat];
    
    // Create a connection point object. If the node is nil, this method fails (returns nil).
    [_engine connect:_sampler toConnectionPoints:@[[[AVAudioConnectionPoint alloc] initWithNode:_engine.mainMixerNode bus:1],
                                                   [[AVAudioConnectionPoint alloc] initWithNode:_distortion bus:0]] fromBus:0 format:audioFormat];
}


- (void)initWithUnitSampler{
    
    NSAssert(_audioFilePath, @"not found audio file from url path ...");
    
    NSError *error;
    _sampler = [[AVAudioUnitSampler alloc] init];
    
    /*
     loadInstrumentAtURL    支持音频类型(eg. .caf, .aiff, .wav, .mp3)
     loadAudioFilesAtURLs   加载多个音频文件，按队列有序播放
     */
    
     /* The AVAudioUnitSampler class encapsulates Apple's Sampler Audio Unit. The sampler audio unit can be configured by loading different types of instruments such as an “.aupreset” file, a DLS or SF2 sound bank, an EXS24 instrument, a single audio file or with an array of audio files. The output is a single stereo bus. */
    NSURL *bankURL = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"gs_instruments" ofType:@"dls"]];

    // This method reads from file and allocates memory, so it should not be called on a real time thread.
    // bankMSB: MSB for the bank number for the instrument to load.  This is usually 0x79 for melodic instruments and 0x78 for percussion instruments.
    BOOL success = [_sampler loadSoundBankInstrumentAtURL:bankURL program:0 bankMSB:0x79 bankLSB:0 error:&error];
    if (!success) NSLog(@"loadSoundBank : counld not open file from url = %@",_audioFilePath);
}


- (void)initWithUnitDistortion{
    
    // An AVAudioUnitEffect that implements a multi-stage distortion effect.
    _distortion = [[AVAudioUnitDistortion alloc] init];
    
    // Load a distortion preset.
    [_distortion loadFactoryPreset:AVAudioUnitDistortionPresetDrumsBitBrush];
    
    // Blend of the distorted and dry signals
    _distortion.wetDryMix = 100;
}
 

- (void)initWithUnitReverb{
    
    // An AVAudioUnitEffect that implements a reverb
    _reverb = [[AVAudioUnitReverb alloc] init];
    
    // Load a reverb preset
    [_reverb loadFactoryPreset:AVAudioUnitReverbPresetMediumHall];
    
    // Blend of the wet and dry signals  混音设置最大值
    _reverb.wetDryMix = 100;
}


- (void)initWithPlayerNode{
    
    // Play buffers or segments of audio files.
    _player = [[AVAudioPlayerNode alloc] init];
    NSError *error;
    
    [self playerNodeScheduledBufferReading:_audioFilePath error:&error];
    
    if (error) {
        
        NSLog(@"initWithPlayerNode error = %@",error);
    }
}


- (void)initWithSequencer{
    
    _sequencerTrackLengthSeconds = 0;
    BOOL success = NO;
    NSError *error;

    /* mid文件为标准MIDI文件格式
     A collection of MIDI events organized into AVMusicTracks, plus a player to play back the events.
     NOTE: The sequencer must be created after the engine is initialized and an instrument node is attached and connected
     */
    _sequencer = [[AVAudioSequencer alloc] initWithAudioEngine:_engine];
    
    // load sequencer loop  读取MIDI音频
    NSURL *midiFileURL = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"bluesyRiff" ofType:@"mid"]];
    NSAssert(midiFileURL, @"couldn't find midi file");
    
    success = [_sequencer loadFromURL:midiFileURL options:AVMusicSequenceLoadSMF_PreserveTracks error:&error];
    NSAssert(success, @"couldn't load midi file, %@", error.localizedDescription);
    
    // An NSArray containing all the tracks in the sequence, Track indices count from 0, and do not include the tempo track.
    [_sequencer.tracks enumerateObjectsUsingBlock:^(AVMusicTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {

        obj.loopingEnabled = YES;
        obj.numberOfLoops = AVMusicTrackLoopCountForever;
        const float trackLengthInSeconds = obj.lengthInSeconds;
        
        if (_sequencerTrackLengthSeconds < trackLengthInSeconds) {
            _sequencerTrackLengthSeconds = trackLengthInSeconds;
        }
    }];
    
    [_sequencer prepareToPlay];
}


- (void)initWithPCMBuffer{

    NSError *error;
    NSURL *audioFilePath = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"drumLoop" ofType:@"caf"]];//[NSURL fileURLWithPath:_audioFilePath];
    
    // Open a file for reading.  加载音频文件  如caf mp3 -> pcm
    AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:audioFilePath error:&error];
    if (error) NSLog(@"audio file reading error : %@",error);
    
    // Initialize a buffer that is to contain PCM audio samples.
    // @param format , The format of the PCM audio to be contained in the buffer.
    // @param frameCapacity , The capacity of the buffer in PCM sample frames.
    _playerLoopBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.processingFormat frameCapacity:(AVAudioFrameCount)audioFile.length];
    
    //The buffer into which to read from the file. Its format must match the file's processing format.
    BOOL success = [audioFile readIntoBuffer:_playerLoopBuffer error:&error];
    if (!success) NSLog(@"read audio file into buffer failed = %@",error);
}


#pragma mark    -   Audio Control

- (void)startEngine{
    
    if (!_engine.isRunning) {
        
        NSError *error;
        
        // Start the engine.
        BOOL success = [_engine startAndReturnError:&error];
        if (!success) NSLog(@"could not start engine = %@", error);
    }
}


#pragma mark    -   Audio session

- (void)initWithAudioSession{
    
     /* returns singleton instance */
    AVAudioSession  *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error;
    
    /* set session category */
    BOOL success = [sessionInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!success) NSLog(@"setting AVAudioSession category error :  %@",error);
    
    // setPreferredIOBufferDuration 音频缓冲时长
    // setPreferredInputNumberOfChannels、setPreferredOutputNumberOfChannels  设置音频通道的数量(左声道，右声道，立体声)
    
    double audioSampleRate = 44100.0;
    success = [sessionInstance setPreferredSampleRate:audioSampleRate error:&error];
    if (!success) NSLog(@"setting AVAudioSession sampleRate error :  %@",error);
    
    success = [sessionInstance setPreferredIOBufferDuration:0.0029 error:&error];
    if (!success) NSLog(@"setting AVAudioSession IO Buffer Duration error :  %@",error);
    
    // add interruption handler
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:sessionInstance];
    
    // we don't do anything special in the route change notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:sessionInstance];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMediaServicesReset:)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:sessionInstance];
    
    // activate the audio session
    success = [sessionInstance setActive:YES error:&error];
    if (!success) NSLog(@"setting session active error :  %@\n", [error localizedDescription]);
}


#pragma mark    -   Audio session notification

/* Registered listeners will be notified when the system has interrupted the audio session and when
 the interruption has ended.  Check the notification's userInfo dictionary for the interruption type -- either begin or end.
 In the case of an end interruption notification, check the userInfo dictionary for AVAudioSessionInterruptionOptions that
 indicate whether audio playback should resume. */
- (void)handleInterruption:(NSNotification *)notification{
    
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        
        _isSessionInterrupted = YES;
        [_player stop];
        [_sequencer stop];
        [_engine reset];
        _engine = nil;
        
    }else if (theInterruptionType == AVAudioSessionInterruptionTypeEnded){
        
        // make sure to activate the session
        NSError *error;
        bool success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        if (!success)
            NSLog(@"AVAudioSession set active failed with error: %@", [error localizedDescription]);
        else {
            _isSessionInterrupted = NO;
            
            if (_isConfigChangePending) {
                
                //there is a pending config changed notification
                NSLog(@"Responding to earlier engine config changed notification. Re-wiring connections and starting once again");
                [self initWithEngine];
                [self startEngine];
                
                _isConfigChangePending = NO;
            }
            else {
                // start the engine once again
                [self startEngine];
            }
        }
    }
}

/* Registered listeners will be notified when a route change has occurred.  Check the notification's userInfo dictionary for the
 route change reason and for a description of the previous audio route.
 */
- (void)handleRouteChange:(NSNotification *)notification{
    
    UInt8   audioRouteReasonValue = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *audioSessionRouteDescription = notification.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    
    switch (audioRouteReasonValue) {
            
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@">>>>>>>>>>>>>>>>>  NewDeviceAvailable");
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@">>>>>>>>>>>>>>>>>  OldDeviceUnavailable");
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@">>>>>>>>>>>>>>>>>  CategoryChange");
            NSLog(@">>>>>>>>>>>>>>>>>  New Category: %@", [[AVAudioSession sharedInstance] category]);
            break;
            
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@">>>>>>>>>>>>>>>>>  Override");
            break;
            
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@">>>>>>>>>>>>>>>>>  WakeFromSleep");
            break;
            
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@">>>>>>>>>>>>>>>>>  NoSuitableRouteForCategory");
            break;
            
        default:
            NSLog(@">>>>>>>>>>>>>>>>>  ReasonUnknown");
    }
    
    NSLog(@">>>>>>>>>>>>>>>>>  Previous route: %@", audioSessionRouteDescription);
}

/* Registered listeners will be notified when the media server restarts.  In the event that the server restarts,
 take appropriate steps to re-initialize any audio objects used by your application.  See Technical Q&A QA1749.
 */
- (void)handleMediaServicesReset:(NSNotification *)notification{
    
    // if we've received this notification, the media server has been reset
    // re-wire all the connections and start the engine
    NSLog(@"Media services have been reset!");
    NSLog(@"Re-wiring connections and starting once again");
    
    _sequencer = nil; //remove this sequencer since it's linked to the old AVAudioEngine
    [self initWithAudioSession];
    [self initWithEngine];
    [self initWithSequencer];
    [self startEngine];
}


#pragma mark    -   private/public method

- (void)resetAudioNode{
    
    [_player reset];
}


#pragma mark    - IDYEngineControl protocol

- (void)engineStart{
    
    [self startEngine];
}

- (void)engineStop{
    
    if (!_engine.isRunning) {
        
        [_engine stop];
    }
}

- (void)enginePause{
    
    if (!_engine.isRunning) {
        
        [_engine pause];
    }
}


#pragma mark    -   IDYUnitSampleAction protocol

// 音符
- (void)setStereoPan:(float)stereoPan{
    
    _stereoPan = stereoPan;
    if (_sampler) _sampler.stereoPan = stereoPan;
}

// 音符增益
- (void)setMasterGain:(float)masterGain{
    
    _masterGain = masterGain;
    if (_sampler) _sampler.masterGain = masterGain;
}

// 音符调谐
- (void)setGlobalTuning:(float)globalTuning{
    
    _globalTuning = globalTuning;
    if (_sampler) _sampler.globalTuning = globalTuning;
}


#pragma mark    -   IDYSequencerControl protocol

// 播放次数，默认是无限循环
- (void)setNumberOfLoops:(NSInteger)numberOfLoops{
    
    _numberOfLoops = numberOfLoops;
    
    [_sequencer.tracks enumerateObjectsUsingBlock:^(AVMusicTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        obj.loopingEnabled = !numberOfLoops;
        obj.numberOfLoops = numberOfLoops?numberOfLoops:AVMusicTrackLoopCountForever;
    }];
}

// 消除声音，柔和
- (void)setMuted:(BOOL)muted{
    
    _muted = muted;
    
    [self sequencerStop];
    
    [_sequencer.tracks enumerateObjectsUsingBlock:^(AVMusicTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        obj.muted = _muted;
        if (_sequencerTrackLengthSeconds < obj.lengthInSeconds) {
            _sequencerTrackLengthSeconds = obj.lengthInSeconds;
        }
    }];
    
    [self sequencerStart];
}

// 独奏
- (void)setSoloed:(BOOL)soloed{
    
    _soloed = soloed;
    
    [self sequencerStop];
    
    [_sequencer.tracks enumerateObjectsUsingBlock:^(AVMusicTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        obj.soloed = soloed;
        if (_sequencerTrackLengthSeconds < obj.lengthInSeconds) {
            _sequencerTrackLengthSeconds = obj.lengthInSeconds;
        }
    }];
    
    [self sequencerStart];
}

// 播放指定时间
- (void)setCurrentPositionInSeconds:(NSTimeInterval)currentPositionInSeconds{
    
    _currentPositionInSeconds = currentPositionInSeconds;
    if (_currentPositionInSeconds && (_sequencer.currentPositionInSeconds != currentPositionInSeconds)) {
        
        _sequencer.currentPositionInSeconds = _currentPositionInSeconds * _sequencerTrackLengthSeconds;
    }
}

// 播放速率
- (void)setRate:(float)rate{
    
    _rate = rate;
    if (_rate && (_sequencer.rate != _rate)) {
        
        [_sequencer setRate:_rate];
    }
}

// 偏移指定时间长度
- (void)setOffsetTime:(Float64)offsetTime{
    
    [self sequencerStop];
    
    [_sequencer.tracks enumerateObjectsUsingBlock:^(AVMusicTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        obj.offsetTime = offsetTime;
        if (_sequencerTrackLengthSeconds < obj.lengthInSeconds) {
            _sequencerTrackLengthSeconds = obj.lengthInSeconds;
        }
    }];
    
    [self sequencerStart];
}

- (void)sequencerStart{
    
    if (!_sequencer.isPlaying) {
        
        [_sequencer prepareToPlay];
        
        NSError *error;
        BOOL success = [_sequencer startAndReturnError:&error];
        if (!success) NSLog(@"sequence start failed ... %@",error);
    }
}

- (void)sequencerStop{
    
    if (_sequencer.isPlaying) {
        
        [_sequencer stop];
    }
}

#pragma mark    -   IDYPlayerNodeControl protocol

// 从指定路径读取音频文件
- (void)playerNodeScheduledFileReading:(NSString *)filePath completionHanlder:(void (^) (void))completionHanlder{
    
    if (!_player) _player = [[AVAudioPlayerNode alloc] init];
    
    NSError *error;
    // Open a file for reading.
    AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:filePath] error:&error];
    
    if (!error) {
        
        // Start the engine.
        [_engine startAndReturnError:&error];
        
        if (!error) {
            
            const float kStartDelayTime = 0.5; // sec
            AVAudioFormat *outputFormat = [_player outputFormatForBus:0];
            
            // _player.lastRenderTime : Will return nil if the engine is not running or if the node is not connected to an input or output node. 
            AVAudioFramePosition startSampleTime = _player.lastRenderTime.sampleTime + kStartDelayTime * outputFormat.sampleRate;
            AVAudioTime *startTime = [AVAudioTime timeWithSampleTime:startSampleTime atRate:outputFormat.sampleRate];
            
            // Schedule playing of an entire audio file.
            [_player scheduleFile:audioFile
                           atTime:startTime
                completionHandler:completionHanlder?completionHanlder:nil];
            
        }else NSLog(@"engine start and return failed : %@",error);
        
    }else NSLog(@"player node scheduled file read failed : %@",error);
}

// 读取pcm buffer数据
- (void)playerNodeScheduledBufferReading:(NSString *)filePath error:(NSError **)outError{
    
    if (!_player) _player = [[AVAudioPlayerNode alloc] init];
    
    // Open a file for reading.
    AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:filePath] error:outError];
    
    // Initialize a buffer that is to contain PCM audio samples.
    _playerLoopBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:[audioFile processingFormat] frameCapacity:(AVAudioFrameCount)audioFile.length];
    
    // Read an entire buffer.
    [audioFile readIntoBuffer:_playerLoopBuffer error:outError];
}

- (void)playerNode_play{
    
    if (!_player.playing) {
        
        if (_isRecordingSelected) {
            
            [self playerNodeScheduledFileReading:_audioFilePath completionHanlder:nil];
            
        }else{
            
            // Schedule playing samples from an AVAudioBuffer.
            [_player scheduleBuffer:_playerLoopBuffer
                             atTime:nil
                            options:AVAudioPlayerNodeBufferLoops
                  completionHandler:nil];
        }
        
        [_player play];
    }
}

- (void)playerNode_stop{
    
    if (_player.playing) {
        
        [_player stop];
    }
}

- (void)playerNode_pause{
    
    if (_player.playing) {
        
        [_player pause];
    }
}

- (void)setNodeVolume:(float)nodeVolume{
    
    _nodeVolume = nodeVolume;
    
    [_player setVolume:_nodeVolume];
}

@end
