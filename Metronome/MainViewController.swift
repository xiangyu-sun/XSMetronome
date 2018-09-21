//
//  MainViewController.swift
//  Metronome
//
//  Created by xiangyu sun on 9/21/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import UIKit
import AVFoundation
import MetronomeKit_iOS
import os

class MainViewController: UIViewController {
    var metronome: Metronome!
    var faceDrawer: MetronomeFacePainter!
    var wasRunning = false
    
    @IBOutlet weak var backgroudnImageView: UIImageView!
    @IBOutlet weak var faceView: UIView!
    @IBOutlet weak var foregroundImageView: UIImageView!
    @IBOutlet weak var meterLabel: UILabel!
    @IBOutlet weak var tempoLabel: UILabel!
    @IBOutlet var swipeRightGestureRecongnizer: UISwipeGestureRecognizer!
    
    @IBOutlet var swipeDownRestureRecongnizer: UISwipeGestureRecognizer!
    @IBOutlet var swipeUpGestureRecongnizer: UISwipeGestureRecognizer!
    @IBOutlet var swipeLeftGestureRecongnizer: UISwipeGestureRecognizer!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else {
            return
        }
        
        let faceConfig = FacePaintConfiguration(scale: UIScreen.main.scale, contentFrame: self.faceView.frame)
        
        faceDrawer  = MetronomeFacePainter(faceConfiguration: faceConfig)
        metronome = Metronome(audioFormat: format)
        metronome.delegate = self
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
           backgroudnImageView.image = image
        }
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesWereReset), name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMeterLabel()
        updateTempoLabel()
    }
    @objc func handleMediaServicesWereReset()  {
        os_log("audio reset")
        metronome.delegate = nil
        metronome.reset()
        
        updateMeterLabel()
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroudnImageView.image = image
        }
        
        metronome.delegate = self
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        }catch {
            os_log("%@", error.localizedDescription)
        }
    }
    

    @IBAction func tempoChanged(_ sender: UISlider) {
        metronome.setTempo(to: Int(sender.value))
        updateTempoLabel()
    }
    

    @IBAction func swipeDown(_ sender: Any) {
        try? metronome.incrementDivisionIndex(by: -1)
        updateMeterLabel()
    }
    @IBAction func swipeUp(_ sender: Any) {
        try? metronome.incrementDivisionIndex(by: 1)
        updateMeterLabel()
    }
    @IBAction func swipeLeft(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: 1)
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroudnImageView.image = image
        }
        updateMeterLabel()
        
        if wasRunning {
            try? metronome.start()
        }
    }
    @IBAction func swipeRight(_ sender: Any) {
        let wasRunning = metronome.isPlaying
        
        if wasRunning {
            metronome.stop()
        }
        metronome.incrementMeter(by: -1)
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroudnImageView.image = image
        }
        updateMeterLabel()
        
        if wasRunning {
            try? metronome.start()
        }
    }
    
    func updateArcWithTick(currentTick: Int) {
        if metronome.isPlaying {
            foregroundImageView.image = faceDrawer[currentTick]
        } else {
            foregroundImageView.image = nil
        }
    }
    @IBAction func tap(_ sender: Any) {
        if metronome.isPlaying {
            metronome.stop()
            updateArcWithTick(currentTick: 0)
            wasRunning = true
        }else {
            try? metronome.start()
        }
    }

    
    
    func updateTempoLabel() {
        tempoLabel.text = "\(metronome.tempoBPM) BPM"
    }
    
    
    func updateMeterLabel() {
        meterLabel.text = "\(metronome.meter) / \(metronome.division)"
    }
}

extension MainViewController: MetronomeDelegate {
    func metronomeTicking(_ metronome: Metronome, currentTick: Int) {
        DispatchQueue.main.async {
            self.updateArcWithTick(currentTick: currentTick)
        }
    }
}
