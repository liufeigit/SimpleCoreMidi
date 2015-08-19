//
//  MidiEngine.m
//  SimpleCoreMidi
//
//  Created by Thierry Sansaricq on 8/18/15.
//  Copyright (c) 2015 Thierry Sansaricq. All rights reserved.
//

#import "MidiEngine.h"

@interface MidiEngine() {
    
}

@end


#pragma mark MidiEngine implementation

@implementation MidiEngine

@synthesize processingGraph     = _processingGraph;
@synthesize samplerUnit         = _samplerUnit;
@synthesize ioUnit              = _ioUnit;
@synthesize graphSampleRate     = _graphSampleRate;



- (instancetype)init
{
    if (self = [super init]) {

        if(![self initAVAudioSession]){
            return nil;
        }
        
        if(![self createAUGraph]){
            return nil;
        }
        
    }
    
        
    return self;
    

}



#pragma mark AVAudioSession

- (BOOL)initAVAudioSession
{
    // For complete details regarding the use of AVAudioSession see the AVAudioSession Programming Guide
    // https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html
    
    // Configure the audio session
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error;
    
    // set the session category
    bool success = [sessionInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!success){
        NSLog(@"Error setting AVAudioSession category! %@\n", [error localizedDescription]);
        return NO;
    }
    
    //double hwSampleRate = 44100.0;
    // Request a desired hardware sample rate.
    self.graphSampleRate = 44100.0;    // Hertz
    
    success = [sessionInstance setPreferredSampleRate:self.graphSampleRate error:&error];
    if (!success){ NSLog(@"Error setting preferred sample rate! %@\n", [error localizedDescription]);
        return NO;
    }
    
    NSTimeInterval ioBufferDuration = 0.0029;
    success = [sessionInstance setPreferredIOBufferDuration:ioBufferDuration error:&error];
    if (!success) {
        NSLog(@"Error setting preferred io buffer duration! %@\n", [error localizedDescription]);
        return NO;
    }
    
    
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
    if (!success){ NSLog(@"Error setting session active! %@\n", [error localizedDescription]);
        return NO;
    }
    
    self.graphSampleRate = [sessionInstance sampleRate];
    
    return YES;
}


//create an audio processing graph
- (BOOL) createAUGraph {
    
    OSStatus result = noErr;
    AUNode samplerNode, ioNode;
    
    //common audio component description object
    AudioComponentDescription cd = {};
    cd.componentManufacturer    = kAudioUnitManufacturer_Apple;
    cd.componentFlags           = 0;
    cd.componentFlagsMask       = 0;
    
    //sampler
    cd.componentType            = kAudioUnitType_MusicDevice;
    cd.componentSubType         = kAudioUnitSubType_Sampler;
    
    //Instantiate Audio processing graph
    result = NewAUGraph(&_processingGraph);
    if(result != noErr){
        NSLog(@"Could not create AUGraph!");
        return NO;
    }
    
    //add sampler unit node to the graph
    result = AUGraphAddNode(self.processingGraph, &cd, &samplerNode);
    if(result != noErr){
        NSLog(@"Could not add sampler node to graph!");
        return NO;
    }
    
    //output unit
    //configuration first
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
    
    result = AUGraphAddNode(self.processingGraph, &cd, &ioNode);
    if(result != noErr){
        NSLog(@"Could not add output node to graph!");
        return NO;
    }
    
    //open the graph
    result = AUGraphOpen(self.processingGraph);
    if(result != noErr){
        NSLog(@"Could not open graph!");
        return NO;
    }
    
    //connect the sampler node to the output node
    result = AUGraphConnectNodeInput(self.processingGraph, samplerNode, 0, ioNode, 0);
    if(result != noErr){
        NSLog(@"Could not connect sampler node to output node!");
        return NO;
    }
    
    //capture reference to sampler unit from its node
    result = AUGraphNodeInfo(self.processingGraph, samplerNode, 0, &_samplerUnit);
    if(result != noErr){
        NSLog(@"Could not capture reference to sampler unit from its node!");
        return NO;
    }
    
    result = AUGraphNodeInfo(self.processingGraph, ioNode, 0, &_ioUnit);
    if(result != noErr){
        NSLog(@"Could not capture reference to output unit from its node!");
        return NO;
    }
    
    
    return YES;
    
}


#pragma mark notifications

- (void)handleInterruption:(NSNotification *)notification
{
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        //[_drumPlayer stop];
        //[_marimbaPlayer stop];
        //[self stopPlayingRecordedFile];
        //[self stopRecordingMixerOutput];
        
        if ([self.delegate respondsToSelector:@selector(engineWasInterrupted)]) {
            [self.delegate engineWasInterrupted];
        }
        
    }
    if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        // make sure to activate the session
        NSError *error;
        bool success = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!success) NSLog(@"AVAudioSession set active failed with error: %@", [error localizedDescription]);
        
        // start the engine once again
        //[self startEngine];
    }
}

- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
    NSLog(@"Route change:");
    switch (reasonValue) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"     NewDeviceAvailable");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"     OldDeviceUnavailable");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"     CategoryChange");
            NSLog(@" New Category: %@", [[AVAudioSession sharedInstance] category]);
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"     Override");
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"     WakeFromSleep");
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"     NoSuitableRouteForCategory");
            break;
        default:
            NSLog(@"     ReasonUnknown");
    }
    
    NSLog(@"Previous route:\n");
    NSLog(@"%@", routeDescription);
}

- (void)handleMediaServicesReset:(NSNotification *)notification
{
    // if we've received this notification, the media server has been reset
    // re-wire all the connections and start the engine
    NSLog(@"Media services have been reset!");
    NSLog(@"Re-wiring connections and starting once again");
    

    #pragma mark TODO: Put In Some Re-wiring code here
    //[self createEngineAndAttachNodes];
    //[self initAVAudioSession];
    //[self makeEngineConnections];
    //self startEngine];
    
    
    
    
    // post notification
    if ([self.delegate respondsToSelector:@selector(engineConfigurationHasChanged)]) {
        [self.delegate engineConfigurationHasChanged];
    }
    
    
}



@end


#pragma mark steps for implementing Midi playback in iOS


/*!

 Create Audio Session
 Create AUGraph
 ** Create AudioComponentDescription
 ** NewAUGraph
 ** Add Nodes to the graph
 ** Open the graph
 ** Connect the nodes to each other
 ** Get references to the AudioUnits from nodes
 Configure Graph
 ** Initialize Audio Units
 ** Set Properties on Audio Units
 Initialize Audio Processing graph
 Start Audio Processing graph
 
*/

#pragma mark useful links

/*!

 http://www.deluge.co/?q=midi-driven-animation-core-audio-objective-c
 
*/



