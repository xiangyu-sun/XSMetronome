//
//  InterfaceController.swift
//  MetronomeWatchOS Extension
//
//  Created by xiangyu sun on 9/8/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import WatchKit
import Foundation
import MetronomeKit_WatchOS
import AVFoundation
import os

let kArcWidth: CGFloat = 8.0                     // points
let kArcGapAngle = (16.0 * Double.pi) / 180.0     // radians

class InterfaceController: WKInterfaceController {
    @IBOutlet var backgroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var foregroundArcsGroup: WKInterfaceGroup!
    @IBOutlet var tempoLabel: WKInterfaceLabel!
    @IBOutlet var meterLabel: WKInterfaceLabel!
    
    var metronome: Metronome!
    
    var foregroundArcArray = [UIImage]()
    var accumulatedRotations: Double = 0
    var wasRunning = false
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate, channels: 1) else {
            return 
        }
        metronome = Metronome(audioFormat: format)
        metronome.delegate = self
        drawArchs()
        crownSequencer.delegate = self
        crownSequencer.focus()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesWereReset), name: NSNotification.Name.AVAudioSessionMediaServicesWereReset, object: AVAudioSession.sharedInstance())
    }
    
    func drawArchs()  {
        let meter = metronome.meter
        
        let scale = WKInterfaceDevice.current().screenScale
        let foregroundFillColor = UIColor(red: 0.301, green: 0.556, blue: 0.827, alpha: 1.0).cgColor
        let firstElementFillColor = UIColor(red: 0.301, green: 0.729, blue: 0.478, alpha: 1.0).cgColor
        let backgroundFillColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0).cgColor
        
        
        let contentFrameWidth = self.contentFrame.size.width;
        let contentFrameHeight = self.contentFrame.size.height;
        
        let center = CGPoint(x: contentFrameWidth / 2.0, y: contentFrameHeight / 2.0)
        let radius = min(contentFrameWidth / 2.0, contentFrameHeight / 2.0) - (kArcWidth / 2.0)
        
        let stepAngle = ((2.0 * .pi) / Double(meter)) - kArcGapAngle;
        
        // Draw Background Rings
        var startAngle = (kArcGapAngle / 2.0) - (1.5 * .pi/2);
        UIGraphicsBeginImageContextWithOptions(self.contentFrame.size, false, scale);
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.beginPath()
        for _ in (0..<meter) {
            let strokedArc = newDonutArcWithCenter(centerPoint: center, withRadius: radius, fromStartAngle: CGFloat(startAngle), toEndAngle: CGFloat(startAngle + stepAngle))

            context.addPath(strokedArc);
            startAngle += stepAngle + kArcGapAngle;
        }
        
 
        context.closePath()
        context.setFillColor(backgroundFillColor)
        context.fillPath()
        
        guard let cgBackgroundImage = context.makeImage() else {
            return
        }
        let backgroundImage = UIImage(cgImage: cgBackgroundImage)
        backgroundArcsGroup.setBackgroundImage(backgroundImage)
        
        UIGraphicsEndImageContext();
        
        // Draw and Store Foreground Rings
        foregroundArcArray.removeAll()

        startAngle = (kArcGapAngle / 2.0) - (1.5 * .pi/2)
        
        
        for index in (0..<meter) {
            UIGraphicsBeginImageContextWithOptions(self.contentFrame.size, false, scale)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                continue
            }
            context.beginPath()
            let strokedArc = newDonutArcWithCenter(centerPoint: center, withRadius: radius, fromStartAngle: CGFloat(startAngle), toEndAngle: CGFloat(startAngle + stepAngle))
            
            context.addPath(strokedArc)
            
            context.closePath()
            
            if (index == 0) {
                context.setFillColor(firstElementFillColor)
            } else {
                context.setFillColor(foregroundFillColor)
            }
            context.fillPath();
            
            guard let cgImage = context.makeImage() else {
                continue
            }
            let foregroundImage = UIImage(cgImage: cgImage)
            foregroundArcArray.append(foregroundImage)
            
            UIGraphicsEndImageContext()
            
            startAngle += stepAngle + kArcGapAngle
        }
    }
    
    func newDonutArcWithCenter(centerPoint: CGPoint, withRadius radius: CGFloat, fromStartAngle startAngle: CGFloat, toEndAngle endAngle: CGFloat) -> CGPath {
        let arc = CGMutablePath()
        arc.addArc(center: centerPoint, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false, transform: CGAffineTransform.identity)

        return arc.copy(strokingWithWidth: kArcWidth, lineCap: .square, lineJoin: .miter, miterLimit: 10)
    }
    
    @objc func handleMediaServicesWereReset()  {
        os_log("audio reset")
        metronome.delegate = nil
        metronome.reset()
        
        updateMeterLabel()
        drawArchs()
        
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
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        metronome.stop()
    }
    
    func updateArcWithTick(currentTick: Int) {
        if metronome.isPlaying {
            foregroundArcsGroup.setBackgroundImage(foregroundArcArray[currentTick])
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
        metronome.incrementDivisionIndex(by: -1)
        updateMeterLabel()
    }
    @IBAction func upSwipeRecongnized(_ sender: Any) {
        metronome.incrementDivisionIndex(by: 1)
        updateMeterLabel()
    }
    @IBAction func leftSwipeRecongnized(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: 1)
        drawArchs()
        updateMeterLabel()
        
        if wasRunning {
            metronome.start()
        }
    }
    @IBAction func rightSwipeRecongnized(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: -1)
        drawArchs()
        updateMeterLabel()
        
        if wasRunning {
            metronome.start()
        }
    }
    @IBAction func tapRecongnized(_ sender: Any) {
        if metronome.isPlaying {
            metronome.stop()
            updateArcWithTick(currentTick: 0)
            wasRunning = true
        }else {
            metronome.start()
        }
    }
    
    
    
}


extension InterfaceController: MetronomeDelegate {
    func metronomeTicking(_ metronome: Metronome, currentTick: Int32) {
        updateArcWithTick(currentTick: Int(currentTick))
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
            metronome.incrementTempo(by: Float32(value))
            updateTempoLabel()
        }
    }
    
    func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
        if wasRunning {
            metronome.start()
            wasRunning = false
        }
    }
}
