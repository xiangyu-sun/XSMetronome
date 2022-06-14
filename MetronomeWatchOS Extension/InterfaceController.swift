//
//  InterfaceController.swift
//  MetronomeWatchOS Extension
//
//  Created by xiangyu sun on 9/8/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import WatchKit
import Foundation
import MetromomeKit
import AVFoundation
import os
import Combine


final class InterfaceController: WKInterfaceController {
    @IBOutlet var backgroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var foregroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var tempoLabel: WKInterfaceLabel!
    @IBOutlet var meterLabel: WKInterfaceLabel!
    
    var metronome: Metronome!
    var faceDrawer: MetronomeFacePainter!
    
    var accumulatedRotations: Double = 0
    var wasRunning = false
    
    private var cancellable = Set<AnyCancellable>()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate, channels: 1) else {
            return
        }
        let side = min(self.contentFrame.width, self.contentFrame.height)
        let frame = CGRect(x: 0, y: 0, width:  side, height: side)
        let faceConfig = FacePaintConfiguration(scale: WKInterfaceDevice.current().screenScale, contentFrame: frame)
        
        faceDrawer  = MetronomeFacePainter(faceConfiguration: faceConfig)
        
        metronome = Metronome(audioFormat: format)

        
        Task { @MainActor in
            await backgroundArcsGroup.setBackgroundImage( faceDrawer.drawArchsWith(meter: metronome.meter) )
        }
        crownSequencer.delegate = self
        

        metronome.tick
            .receive(on: DispatchQueue.main)
            .sink { completion in
            print("end")
        } receiveValue: { value in
            self.updateArcWithTick(currentTick: value)
        }
        .store(in: &cancellable)

        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesWereReset), name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
    }
    
    
    @objc func handleMediaServicesWereReset()  {
        Task {
            os_log("audio reset")
            
            await metronome.reset()
            
            updateMeterLabel()
            
            Task { @MainActor in
                await backgroundArcsGroup.setBackgroundImage( faceDrawer.drawArchsWith(meter: metronome.meter) )
            }
            
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            }catch {
                os_log("%@", error.localizedDescription)
            }
        }
    }
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        updateMeterLabel()
        updateTempoLabel()
        crownSequencer.focus()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        Task {
            await metronome.stop()
        }
    }
    
    func updateArcWithTick(currentTick: Int) {
        Task {
            let isPlaying = await metronome.isPlaying
            
            if isPlaying {
                
                foregroundArcsGroup.setBackgroundImage( await faceDrawer[currentTick])
                
            } else {
                foregroundArcsGroup.setBackgroundImage(nil)
            }
        }
    }
    
    func updateMeterLabel() {
        Task {
            meterLabel.setText("\(await metronome.meter) / \(await metronome.division)")
        }
    }
    
    func updateTempoLabel() {
        Task {
            tempoLabel.setText("\(await metronome.tempoBPM) BPM")
        }
    }
    @IBAction func downSwipeRecongnized(_ sender: Any) {
        Task {
            try? await metronome.incrementDivisionIndex(by: -1)
        }
        updateMeterLabel()
    }
    @IBAction func upSwipeRecongnized(_ sender: Any) {
        Task {
            try? await metronome.incrementDivisionIndex(by: 1)
        }
        updateMeterLabel()
    }
    @IBAction func leftSwipeRecongnized(_ sender: Any) {
        Task {
            let wasRunning =  await metronome.isPlaying
            
            if wasRunning {
                await metronome.stop()
            }
            await metronome.incrementMeter(by: 1)
            
            Task { @MainActor in
                await backgroundArcsGroup.setBackgroundImage( faceDrawer.drawArchsWith(meter: metronome.meter) )
            }
            
            updateMeterLabel()
            
            if wasRunning {
                try? await metronome.start()
            }
        }
    }
    @IBAction func rightSwipeRecongnized(_ sender: Any) {
        Task {
            let wasRunning = await metronome.isPlaying
            
            if wasRunning {
                await metronome.stop()
            }
            await metronome.incrementMeter(by: -1)
            
            Task { @MainActor in
                await backgroundArcsGroup.setBackgroundImage( faceDrawer.drawArchsWith(meter: metronome.meter) )
            }
            
            updateMeterLabel()
            
            if wasRunning {
                try? await metronome.start()
            }
        }
    }
    @IBAction func tapRecongnized(_ sender: Any) {
        Task {
            if await metronome.isPlaying {
                await metronome.stop()
                updateArcWithTick(currentTick: 0)
                wasRunning = true
            }else {
                try? await metronome.start()
            }
        }
    }
    
    
    
    
}

extension InterfaceController: WKCrownDelegate {
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        Task {
            if await metronome.isPlaying {
                await metronome.stop()
                updateArcWithTick(currentTick: 0)
                wasRunning = true
            }
            var value = 0
            accumulatedRotations += rotationalDelta
            
            if accumulatedRotations >= 0.15 {
                value = 1;
                accumulatedRotations = 0;
            } else if accumulatedRotations <= -0.15 {
                value = -1;
                accumulatedRotations = 0;
            }
            if  value != 0 {
                await metronome.incrementTempo(by: value)
                updateTempoLabel()
            }
        }
    }
    
    func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
        Task {
            if wasRunning {
                try? await metronome.start()
                wasRunning = false
            }
        }
    }
}
