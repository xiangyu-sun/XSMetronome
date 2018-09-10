//
//  Metronome.swift
//  MetronomeKit_WatchOS
//
//  Created by xiangyu sun on 9/8/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import Foundation
import AVFoundation

struct GlobalConstants {
    static let kBipDurationSeconds: Float32 = 0.020
    static let kTempoChangeResponsivenessSeconds: Float32 = 0.250
    static let kTempoDefault: Float32 = 120;
    static let kTempoMin: Float32 = 40;
    static let kTempoMax: Float32 = 208;
    
    static let kMeterDefault: Int32 = 4;
    static let kMeterMin: Int32 = 2;
    static let kMeterMax: Int32 = 8;
    
    static let kNumDivisions = 4;
    static let kDivisions = [ 2, 4, 8, 16 ];
}

@objc public protocol MetronomeDelegate: class {
    @objc optional func metronomeTicking(_ metronome: Metronome, bar: Int32, beat: Int32)
}

public class Metronome : NSObject {
    var engine: AVAudioEngine = AVAudioEngine()
    var player: AVAudioPlayerNode = AVAudioPlayerNode()    // owned by engine
    var audioFormat: AVAudioFormat
    var soundBuffer = [AVAudioPCMBuffer?]()
    
    public var meter: Int32 = 0
    public var division: Int = 0
    
    var timeInterval: Float32 = 0
    var divisionIndex: Int = 0
    
    var bufferNumber: Int = 0
    var bufferSampleRate: Float64 = 0.0
    
    var syncQueue: DispatchQueue? = nil
    
    public var tempoBPM: Float32 = 0
    public var beatNumber: Int32 = 0
    var nextBeatSampleTime: Float64 = 0.0
    var beatsToScheduleAhead: Int32 = 0     // controls responsiveness to tempo changes
    var beatsScheduled: Int32 = 0
    
    public var isPlaying: Bool = false
    var playerStarted: Bool = false
    
    public weak var delegate: MetronomeDelegate?
    
    public init(audioFormat:AVAudioFormat) {
        
        // Use two triangle waves which are generate for the metronome bips.
        
        // Create a standard audio format deinterleaved float.
        self.audioFormat = audioFormat
        super.init()
        
        // How many audio frames?
        let bipFrames: UInt32 = UInt32(GlobalConstants.kBipDurationSeconds * Float(audioFormat.sampleRate))
        
        // Create the PCM buffers.
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bipFrames))
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bipFrames))
        
        // Fill in the number of valid sample frames in the buffers (required).
        soundBuffer[0]?.frameLength = bipFrames
        soundBuffer[1]?.frameLength = bipFrames
        
        // Generate the metronme bips, first buffer will be A440 and the second buffer Middle C.
        let wg1 = TriangleWaveGenerator(sampleRate: Float(audioFormat.sampleRate), frequency: 660.0)
        let wg2 = TriangleWaveGenerator(sampleRate: Float(audioFormat.sampleRate))
        
        wg1.render(soundBuffer[0]!)
        wg2.render(soundBuffer[1]!)
        
        // Connect player -> output, with the format of the buffers we're playing.
        let output: AVAudioOutputNode = engine.outputNode
        
        engine.attach(player)
        engine.connect(player, to: output, fromBus: 0, toBus: 0, format: audioFormat)
        
        bufferSampleRate = audioFormat.sampleRate
        
        // Create a serial dispatch queue for synchronizing callbacks.
        syncQueue = DispatchQueue(label: "Metronome")
        
    }
    
    deinit {
        self.stop()
        
        engine.detach(player)
        soundBuffer[0] = nil
        soundBuffer[1] = nil
    }
    
    func scheduleBeats() {
        if (!isPlaying) { return }
        
        while (beatsScheduled < beatsToScheduleAhead) {
            // Schedule the beat.
            
            let samplesPerBeat = Float(timeInterval * Float(bufferSampleRate))
            
            let beatSampleTime: AVAudioFramePosition = AVAudioFramePosition(nextBeatSampleTime)
            let playerBeatTime: AVAudioTime = AVAudioTime(sampleTime: AVAudioFramePosition(beatSampleTime), atRate: bufferSampleRate)
            // This time is relative to the player's start time.
            
            player.scheduleBuffer(soundBuffer[bufferNumber]!, at: playerBeatTime, options: AVAudioPlayerNodeBufferOptions(rawValue: 0), completionHandler: {
                self.syncQueue!.sync() {
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
            let callbackBeat = beatNumber
            
            let callBackMeter = meter
            
            if delegate?.metronomeTicking != nil {
                let nodeBeatTime: AVAudioTime = player.nodeTime(forPlayerTime: playerBeatTime)!
                let output: AVAudioIONode = engine.outputNode
                
                //print(" \(playerBeatTime), \(nodeBeatTime), \(output.presentationLatency)")
                let latencyHostTicks: UInt64 = AVAudioTime.hostTime(forSeconds: output.presentationLatency)
                let dispatchTime = DispatchTime(uptimeNanoseconds: nodeBeatTime.hostTime + latencyHostTicks)
                
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: dispatchTime) {
                    if (self.isPlaying && self.meter == callBackMeter) {
                        self.delegate!.metronomeTicking!(self, bar: (callbackBeat / 4) + 1, beat: (callbackBeat % 4) + 1)
                    }
                }
            }
            beatNumber = (beatNumber + 1) % meter
            nextBeatSampleTime += Float64(samplesPerBeat)
        }
    }
    
    @discardableResult public func start() -> Bool {
        // Start the engine without playing anything yet.
        do {
            try engine.start()
            
            isPlaying = true
            nextBeatSampleTime = 0
            
            beatNumber = 0
            bufferNumber = 0
            
            self.syncQueue!.sync() {
                self.scheduleBeats()
            }
            
            return true
        } catch {
            print("\(error)")
            return false
        }
    }
    
    public func stop() {
        isPlaying = false;
        
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
    
    public func reset() {
        tempoBPM = GlobalConstants.kTempoDefault;
        meter = GlobalConstants.kMeterDefault;
        timeInterval = 0
        divisionIndex = 1
        beatNumber = 0
        division = GlobalConstants.kDivisions[divisionIndex]
        beatsScheduled = 0;
        
        updateTimeInterval()
        
        isPlaying = false
        playerStarted = false
    }
    
    func updateTimeInterval() {
        
        timeInterval = (60.0 / tempoBPM) * (4.0 / Float(GlobalConstants.kDivisions[divisionIndex]))
        
        beatsToScheduleAhead = Int32(Int(GlobalConstants.kTempoChangeResponsivenessSeconds / timeInterval))
        
        if (beatsToScheduleAhead < 1) {
            beatsToScheduleAhead = 1
        }
    }
    
    public func incrementTempo(by increment: Float32) {
        
        tempoBPM += increment;
        
        if (tempoBPM > GlobalConstants.kTempoMax) {
            tempoBPM = GlobalConstants.kTempoMax
        } else if (tempoBPM < GlobalConstants.kTempoMin) {
            tempoBPM = GlobalConstants.kTempoMin
        }
        
        updateTimeInterval()
    }
    
    public func incrementMeter(by increment: Int32) {
        meter += increment;
        
        if (meter < GlobalConstants.kMeterMin) {
            meter = GlobalConstants.kMeterMin
        } else if (meter > GlobalConstants.kMeterMax) {
            meter = GlobalConstants.kMeterMax;
        }
        
        beatNumber = 0;
    }
    
    public func incrementDivisionIndex(by increment: Int) {
        let wasRunning = isPlaying
        
        if (wasRunning) {
            stop()
        }
        
        divisionIndex += increment
        
        if (divisionIndex < 0) {
            divisionIndex = 0
        } else if (divisionIndex > GlobalConstants.kNumDivisions-1) {
            divisionIndex = GlobalConstants.kNumDivisions-1
        }
        
        division = GlobalConstants.kDivisions[divisionIndex];
        updateTimeInterval()
        
        if (wasRunning) {
            start()
        }
    }
    
}
