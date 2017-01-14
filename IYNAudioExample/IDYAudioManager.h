//
//  IDYAudioManager.h
//  IYNAudioExample
//
//  Created by qiyun on 17/1/13.
//  Copyright © 2017年 qiyun. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IDYAudioDistortionPreset) {
    
    IDYAudioDistortionPresetDefault = 0,
    IDYAudioDistortionPresetBeats,          // 跳动
    IDYAudioDistortionPresetLoFi,           // 收音机
    IDYAudioDistortionPresetSpeaker,        // 扬声器
    IDYAudioDistortionPresetCellphone,      // 手机音乐
    IDYAudioDistortionPresetDecimated1,
    IDYAudioDistortionPresetDecimated2,
    IDYAudioDistortionPresetDecimated3,
    IDYAudioDistortionPresetDecimated4,
    IDYAudioDistortionPresetFuck,           // 怪音
    IDYAudioDistortionPresetCubed,          // 立体怪音
    IDYAudioDistortionPresetSquared,        // 立方
    IDYAudioDistortionPresetEcho1,          // 回声
    IDYAudioDistortionPresetEcho2,
    IDYAudioDistortionPresetEchoTight1,     //紧凑回声
    IDYAudioDistortionPresetEchoTight2,
    IDYAudioDistortionPresetBroken,         //中断
    IDYAudioDistortionPresetChatter,        //不断的怪音
    IDYAudioDistortionPresetInterference,   //干扰
    IDYAudioDistortionPresetPi,
    IDYAudioDistortionPresetTower,          //铁路信号
    IDYAudioDistortionPresetWaves           //波浪
    
} NS_ENUM_AVAILABLE(10_10, 8_0);


typedef NS_ENUM(NSInteger, IDYAudioUnitReverbPreset) {
    
    IDYAudioUnitReverbPresetSmallRoom       = 0,        // 室内
    IDYAudioUnitReverbPresetMediumRoom      = 1,
    IDYAudioUnitReverbPresetLargeRoom       = 2,        // 大厅
    IDYAudioUnitReverbPresetMediumHall      = 3,
    IDYAudioUnitReverbPresetLargeHall       = 4,        // 大堂
    IDYAudioUnitReverbPresetPlate           = 5,
    IDYAudioUnitReverbPresetMediumChamber   = 6,
    IDYAudioUnitReverbPresetLargeChamber    = 7,
    IDYAudioUnitReverbPresetCathedral       = 8,        // 大教堂
    IDYAudioUnitReverbPresetLargeRoom2      = 9,
    IDYAudioUnitReverbPresetMediumHall2     = 10,
    IDYAudioUnitReverbPresetMediumHall3     = 11,
    IDYAudioUnitReverbPresetLargeHall2      = 12
    
} NS_ENUM_AVAILABLE(10_10, 8_0);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol IDYEngineControl <NSObject>

// Pause the engine.
- (void)engineStart;

// Stop the engine. Releases the resources allocated by prepare.
- (void)engineStop;

// Reset all of the nodes in the engine.
- (void)enginePause;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol IDYUnitSampleControl <NSObject>

/*! @property stereoPan
	@abstract
 adjusts the pan for all the notes played.
 Range:     -1 -> +1
 Default:   0
 */
@property (nonatomic) float     stereoPan;

/*! @property masterGain
	@abstract
 adjusts the gain of all the notes played
 Range:     -90.0 -> +12 db
 Default: 0 db
 */
@property (nonatomic) float     masterGain;

/*! @property globalTuning
	@abstract
 adjusts the tuning of all the notes played.
 Range:     -2400 -> +2400 cents
 Default:   0
 */
@property (nonatomic) float     globalTuning;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol IDYSequencerControl <NSObject>

/*!	@property numberOfLoops
	@abstract The number of times that the track's loop will repeat
	@discussion
 If set to AVMusicTrackLoopCountForever, the track will loop forever.
 Otherwise, legal values start with 1.
 */
@property (nonatomic) NSInteger numberOfLoops;

/*! @property muted
	@abstract Whether the track is muted
 */
@property (nonatomic) BOOL muted;

/*! @property soloed
	@abstract Whether the track is soloed
 */
@property (nonatomic) BOOL soloed;

/*! @property offsetTime
	@abstract Offset the track's start time to the specified time in beats
	@discussion
 By default this value is zero.
 */
@property (nonatomic) Float64 offsetTime;

/*! @property currentPositionInSeconds
	@abstract The current playback position in seconds
	@discussion
 Setting this positions the sequencer's player to the specified time.  This can be set while
 the player is playing, in which case playback will resume at the new position.
 */
@property(nonatomic) NSTimeInterval currentPositionInSeconds;

/*! @property rate
	@abstract The playback rate of the sequencer's player
	@discussion
 1.0 is normal playback rate.  Rate must be > 0.0.
 */
@property (nonatomic) float rate;

/*
 Start the sequencer's player
 If the AVAudioSequencer has not been prerolled, it will pre-roll itself and then start.
 */
- (void)sequencerStart;

/*
 Stop the sequencer's player
 Stopping the player leaves it in an un-prerolled state, but stores the playback position so
 that a subsequent call to startAndReturnError will resume where it left off. This action
 will not stop an associated audio engine.
 */
- (void)sequencerStop;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface IDYAudioManager : NSObject<IDYEngineControl, IDYUnitSampleControl, IDYSequencerControl>

/*! @property preGain
 @abstract
 Gain applied to the signal before being distorted
 Range:      -80 -> 20
 Default:    -6
 Unit:       dB
 */
@property (nonatomic) float preGain;

/*! @property wetDryMix
 @abstract
 Blend of the distorted and dry signals
 Range:      0 (all dry) -> 100 (all distorted)
 Default:    50
 Unit:       Percent
 */
@property (nonatomic) float wetDryMix;


/*! @property volume
 @abstract Set a bus's input volume
 @discussion
 Range:      0.0 -> 1.0
 Default:    1.0
 Mixers:     AVAudioMixerNode, AVAudioEnvironmentNode
 */
@property (nonatomic) float volume;


@property (nonatomic) IDYAudioDistortionPreset   distortionPreset;
@property (nonatomic) IDYAudioUnitReverbPreset   unitReverbPreset;


/*
 Clear a unit's previous processing state.
 */
- (void)resetAudioNode;

@end
