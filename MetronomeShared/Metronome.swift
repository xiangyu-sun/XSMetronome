//
//  Metronome.swift
//  MetronomeKit_WatchOS
//
//  Created by xiangyu sun on 9/8/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import Foundation
import AVFoundation
import os


public protocol MetronomeDelegate: class {
    func metronomeTicking(_ metronome: Metronome, currentTick: Int)
}

public final class Metronome {
    
    struct Constants {
        static let kBipDurationSeconds = 0.02
        static let kTempoChangeResponsivenessSeconds = 0.25
        static let kDivisions = [2, 4, 8, 16]
    }

    
    struct MeterConfig{
        static let min = 2
        static let `default` = 4
        static let max = 8
    }
    
    struct TempoConfig{
        static let min = 40
        static let `default` = 80
        static let max = 208
    }
    
    public private(set) var meter = 0
    public private(set) var division = 0
    public private(set) var tempoBPM = 0
    public private(set) var beatNumber  = 0
    public private(set) var isPlaying = false
    
    public weak var delegate: MetronomeDelegate?
    
    let engine: AVAudioEngine = AVAudioEngine()
    /// owned by engine
    let player: AVAudioPlayerNode = AVAudioPlayerNode()
    
    let bufferSampleRate: Double
    let audioFormat: AVAudioFormat
    var soundBuffer = [AVAudioPCMBuffer?]()
    
    var timeInterval: TimeInterval = 0
    var divisionIndex = 0
    
    var bufferNumber = 0
    
    var syncQueue = DispatchQueue(label: "Metronome")

    var nextBeatSampleTime: AVAudioFramePosition = 0
    /// controls responsiveness to tempo changes
    var beatsToScheduleAhead  = 0
    var beatsScheduled = 0

    var playerStarted = false

    
    public init(audioFormat:AVAudioFormat) {
        
        self.audioFormat = audioFormat
        self.bufferSampleRate = audioFormat.sampleRate

        initiazeDefaults()
        
        // How many audio frames?
        let bipFrames = UInt32(Constants.kBipDurationSeconds * audioFormat.sampleRate)
        
        // Use two triangle waves which are generate for the metronome bips.
        // Create the PCM buffers.
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bipFrames))
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bipFrames))
        
        // Fill in the number of valid sample frames in the buffers (required).
        soundBuffer[0]?.frameLength = bipFrames
        soundBuffer[1]?.frameLength = bipFrames
        
        // Generate the metronme bips, first buffer will be A440 and the second buffer Middle C.
        let wg1 = TriangleWaveGenerator(sampleRate: Float(audioFormat.sampleRate), frequency: 261.6)
        let wg2 = TriangleWaveGenerator(sampleRate: Float(audioFormat.sampleRate))
        
        wg1.render(soundBuffer[0]!)
        wg2.render(soundBuffer[1]!)
        
        engine.attach(player)
        engine.connect(player, to:  engine.outputNode, fromBus: 0, toBus: 0, format: audioFormat)
        
    }
    
    deinit {
        self.stop()
        engine.detach(player)
        soundBuffer[0] = nil
        soundBuffer[1] = nil
    }
    
    public func start() throws {
        
        // Start the engine without playing anything yet.
        try engine.start()
        isPlaying = true
        
        updateTimeInterval()
        nextBeatSampleTime = 0
        beatNumber = 0
        bufferNumber = 0
        
        self.syncQueue.async() {
            self.scheduleBeats()
        }
    }
    
    func initiazeDefaults() {
        tempoBPM = TempoConfig.default
        meter = MeterConfig.default
        timeInterval = 0
        divisionIndex = 1
        beatNumber = 0
        division = Constants.kDivisions[divisionIndex]
        beatsScheduled = 0;
    }

    
    public func stop() {
        isPlaying = false
        
        /* Note that pausing or stopping all AVAudioPlayerNode's connected to an engine does
         NOT pause or stop the engine or the underlying hardware.
         
         The engine must be explicitly paused or stopped for the hardware to stop.
         */
        player.stop()
        player.reset()
        
        /* Stop the audio hardware and the engine and release the resources allocated by the prepare method.
         
         Note that pause will also stop the audio hardware and the flow of audio through the engine, but
         will not deallocate the resources allocated by the prepare method.
         
         It is recommended that the engine be paused or stopped (as applicable) when not in use,
         to minimize power consumption.
         */
        engine.stop()
        
        playerStarted = false
    }
    
    public func incrementTempo(by increment: Int) {
        
        tempoBPM += increment;
        
        tempoBPM = min(max(tempoBPM, TempoConfig.min), TempoConfig.max)
        
        updateTimeInterval()
    }
    
    public func setTempo(to value: Int) {
        
        tempoBPM = min(max(value, TempoConfig.min), TempoConfig.max)
        
        updateTimeInterval()
    }
    
    public func incrementMeter(by increment: Int) {
        meter += increment;
        
        meter = min(max(meter, MeterConfig.min), MeterConfig.max)
        
        beatNumber = 0
    }
    
    public func incrementDivisionIndex(by increment: Int) throws {
        
        let wasRunning = isPlaying
        
        if (wasRunning) {
            stop()
        }
        
        divisionIndex += increment
        
        divisionIndex = min(max(divisionIndex, 0), Constants.kDivisions.count - 1)
        
        division = Constants.kDivisions[divisionIndex];
        
        
        
        if (wasRunning) {
            try start()
        }
    }
    
    public func reset() {
        
        initiazeDefaults()
        updateTimeInterval()
        
        isPlaying = false
        playerStarted = false
    }
    
    
    
    func scheduleBeats() {
        if (!isPlaying) { return }
        
        while (beatsScheduled < beatsToScheduleAhead) {
            // Schedule the beat.
            
            let playerBeatTime = AVAudioTime(sampleTime: nextBeatSampleTime, atRate: bufferSampleRate)
            // This time is relative to the player's start time.
            
            player.scheduleBuffer(soundBuffer[bufferNumber]!, at: playerBeatTime, options: AVAudioPlayerNodeBufferOptions(rawValue: 0), completionHandler: {
                self.syncQueue.async() {
                    self.beatsScheduled -= 1
                    self.bufferNumber ^= 1
                    self.scheduleBeats()
                }
            })
            
            beatsScheduled += 1
            
            if (!playerStarted) {
                // We defer the starting of the player so that the first beat will play precisely
                // at player time 0. Having scheduled the first beat, we need the player to be running
                // in order for nodeTimeForPlayerTime to return a non-nil value.
                player.play()
                playerStarted = true
            }
            
            // Schedule the delegate callback (metronomeTicking:bar:beat:) if necessary.
            
            let callBackMeter = meter
            if let delegate = self.delegate , self.isPlaying && self.meter == callBackMeter {
                let callbackBeat = beatNumber
                
                let nodeBeatTime: AVAudioTime = player.nodeTime(forPlayerTime: playerBeatTime)!
                let output: AVAudioIONode = engine.outputNode
                
                os_log(" %@, %@, %f", playerBeatTime, nodeBeatTime, output.presentationLatency)
                
                let latencyHostTicks: UInt64 = AVAudioTime.hostTime(forSeconds: output.presentationLatency)
                let dispatchTime = DispatchTime(uptimeNanoseconds: nodeBeatTime.hostTime + latencyHostTicks)
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: dispatchTime) {
                    delegate.metronomeTicking(self, currentTick: callbackBeat)
                }
            }
            beatNumber = (beatNumber + 1) % meter
            
            let samplesPerBeat = AVAudioFramePosition(timeInterval * bufferSampleRate)
            nextBeatSampleTime += samplesPerBeat
        }
    }
    

    func updateTimeInterval() {
        
        timeInterval = (60.0 / Double(tempoBPM)) * (4.0 / Double(Constants.kDivisions[divisionIndex]))
        
        beatsToScheduleAhead = Int(Constants.kTempoChangeResponsivenessSeconds / timeInterval)
        
        beatsToScheduleAhead = max(beatsToScheduleAhead, 1)
    }
    
 
    
}
