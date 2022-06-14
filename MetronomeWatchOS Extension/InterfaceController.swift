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


class InterfaceController: WKInterfaceController {
    @IBOutlet var backgroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var foregroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var tempoLabel: WKInterfaceLabel!
    @IBOutlet var meterLabel: WKInterfaceLabel!
    
    var metronome: Metronome!
    var faceDrawer: MetronomeFacePainter!
   
    var accumulatedRotations: Double = 0
    var wasRunning = false
    
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
        metronome.delegate = self
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroundArcsGroup.setBackgroundImage(image)
        }
      
        crownSequencer.delegate = self
    
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesWereReset), name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
    }
    

    @objc func handleMediaServicesWereReset()  {
        os_log("audio reset")
        metronome.delegate = nil
        metronome.reset()
        
        updateMeterLabel()
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroundArcsGroup.setBackgroundImage(image)
        }
        
        metronome.delegate = self
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        }catch {
            os_log("%@", error.localizedDescription)
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
        metronome.stop()
    }
    
    func updateArcWithTick(currentTick: Int) {
        if metronome.isPlaying {
            foregroundArcsGroup.setBackgroundImage(faceDrawer[currentTick])
        } else {
            foregroundArcsGroup.setBackgroundImage(nil)
        }
    }

    func updateMeterLabel() {
        meterLabel.setText("\(metronome.meter) / \(metronome.division)")
    }
    
    func updateTempoLabel() {
        tempoLabel.setText("\(metronome.tempoBPM) BPM")
    }
    @IBAction func downSwipeRecongnized(_ sender: Any) {
        try? metronome.incrementDivisionIndex(by: -1)
        updateMeterLabel()
    }
    @IBAction func upSwipeRecongnized(_ sender: Any) {
        try? metronome.incrementDivisionIndex(by: 1)
        updateMeterLabel()
    }
    @IBAction func leftSwipeRecongnized(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: 1)
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroundArcsGroup.setBackgroundImage(image)
        }
        updateMeterLabel()
        
        if wasRunning {
            try? metronome.start()
        }
    }
    @IBAction func rightSwipeRecongnized(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: -1)
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroundArcsGroup.setBackgroundImage(image)
        }
        updateMeterLabel()
        
        if wasRunning {
            try? metronome.start()
        }
    }
    @IBAction func tapRecongnized(_ sender: Any) {
        if metronome.isPlaying {
            metronome.stop()
            updateArcWithTick(currentTick: 0)
            wasRunning = true
        }else {
            try? metronome.start()
        }
    }

    
    
    
}


extension InterfaceController: MetronomeDelegate {
    func metronomeTicking(_ metronome: Metronome, currentTick: Int) {
        DispatchQueue.main.async {
            self.updateArcWithTick(currentTick: currentTick)
        }
    }
}

extension InterfaceController: WKCrownDelegate {
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        if metronome.isPlaying {
            metronome.stop()
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
            metronome.incrementTempo(by: value)
            updateTempoLabel()
        }
    }
    
    func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
        if wasRunning {
            try? metronome.start()
            wasRunning = false
        }
    }
}
