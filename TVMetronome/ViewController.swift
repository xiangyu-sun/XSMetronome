//
//  ViewController.swift
//  TVMetronome
//
//  Created by xiangyu sun on 9/28/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import UIKit
import AVFoundation
import MetronomeKit
import os


class ViewController: UIViewController {
    var metronome: Metronome!
    var faceDrawer: MetronomeFacePainter!
    var wasRunning = false
    
    @IBOutlet weak var backgroudnImageView: UIImageView!
    @IBOutlet weak var faceView: UIView!
    @IBOutlet weak var foregroundImageView: UIImageView!
    @IBOutlet weak var meterLabel: UILabel!
    @IBOutlet weak var tempoTextField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else {
            return
        }
        
        let faceConfig = FacePaintConfiguration(scale: UIScreen.main.scale,contentFrame: self.faceView.frame, arcWidth: 32)
        
        faceDrawer  = MetronomeFacePainter(faceConfiguration: faceConfig)
        metronome = Metronome(audioFormat: format)
        metronome.delegate = self
        faceDrawer.drawArchsWith(meter: metronome.meter) { (image) in
            backgroudnImageView.image = image
        }
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesWereReset), name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
    }
    
    
    func updateArcWithTick(currentTick: Int) {
        if metronome.isPlaying {
            foregroundImageView.image = faceDrawer[currentTick]
        } else {
            foregroundImageView.image = nil
        }
    }
    func updateTempoLabel() {
        tempoTextField.text = "\(metronome.tempoBPM)"
    }
    
    
    func updateMeterLabel() {
        meterLabel.text = "\(metronome.meter) / \(metronome.division)"
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
    
    
    @IBAction func tap(_ sender: Any) {
        
        if !metronome.isPlaying {
            tempoTextField.resignFirstResponder()
            try? metronome.start()
        }else if metronome.isPlaying, !tempoTextField.resignFirstResponder() {
            metronome.stop()
            updateArcWithTick(currentTick: 0)
            wasRunning = true
        }
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
}


extension ViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text, let tempo = Int(text) else { return }
        metronome.setTempo(to:tempo)
        updateTempoLabel()
    }
}

extension ViewController: MetronomeDelegate {
    func metronomeTicking(_ metronome: Metronome, currentTick: Int) {
        DispatchQueue.main.async {
            self.updateArcWithTick(currentTick: currentTick)
        }
    }
}
