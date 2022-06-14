//
//  MainViewController.swift
//  Metronome
//
//  Created by xiangyu sun on 9/21/18.
//  Copyright © 2018 xiangyu sun. All rights reserved.
//

import UIKit
import AVFoundation
import MetromomeKit
import os
import Combine

class MainViewController: UIViewController {
    var metronome: Metronome!
    var faceDrawer: MetronomeFacePainter!
    var wasRunning = false
    
    @IBOutlet weak var backgroudnImageView: UIImageView!
    @IBOutlet weak var faceView: UIView!
    @IBOutlet weak var foregroundImageView: UIImageView!
    @IBOutlet weak var meterLabel: UILabel!
    @IBOutlet weak var tempoTextField: UITextField!
    
    
    
    @IBOutlet var swipeRightGestureRecongnizer: UISwipeGestureRecognizer!
    
    @IBOutlet var swipeDownRestureRecongnizer: UISwipeGestureRecognizer!
    @IBOutlet var swipeUpGestureRecongnizer: UISwipeGestureRecognizer!
    @IBOutlet var swipeLeftGestureRecongnizer: UISwipeGestureRecognizer!
    
    private var cancellable = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else {
            return
        }
        
        let faceConfig = FacePaintConfiguration(scale: UIScreen.main.scale, contentFrame: self.faceView.frame)
        
        faceDrawer  = MetronomeFacePainter(faceConfiguration: faceConfig)
        metronome = Metronome(audioFormat: format)
        
        
        Task { @MainActor in
            backgroudnImageView.image = await faceDrawer.drawArchsWith(meter: metronome.meter)
        }
        
        
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
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMeterLabel()
        updateTempoLabel()
    }
    @objc func handleMediaServicesWereReset()  {
        os_log("audio reset")
 
        Task { @MainActor in
            await metronome.reset()
            
            updateMeterLabel()
            
            backgroudnImageView.image = await faceDrawer.drawArchsWith(meter: metronome.meter)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            }catch {
                os_log("%@", error.localizedDescription)
            }
        }
    }
  

    @IBAction func swipeDown(_ sender: Any) {
        Task {
            try? await metronome.incrementDivisionIndex(by: -1)
            updateMeterLabel()
        }
    }
    @IBAction func swipeUp(_ sender: Any) {
        Task {
            try? await metronome.incrementDivisionIndex(by: 1)
        }
        updateMeterLabel()
    }
    @IBAction func swipeLeft(_ sender: Any) {
        Task {
            let wasRunning = await metronome.isPlaying
            
            if wasRunning {
                await metronome.stop()
            }
            await metronome.incrementMeter(by: 1)
            
            backgroudnImageView.image = await faceDrawer.drawArchsWith(meter: metronome.meter)
            
            updateMeterLabel()
            
            if wasRunning {
                try? await metronome.start()
            }
        }
    }
    @IBAction func swipeRight(_ sender: Any) {
        Task {
            let wasRunning = await metronome.isPlaying
            
            if wasRunning {
                await metronome.stop()
            }
            await metronome.incrementMeter(by: -1)
            
            backgroudnImageView.image = await faceDrawer.drawArchsWith(meter: metronome.meter)
            
            updateMeterLabel()
            
            if wasRunning {
                try? await metronome.start()
            }
        }
    }
    
    func updateArcWithTick(currentTick: Int) {
        Task { @MainActor in
            if await metronome.isPlaying {
                foregroundImageView.image = await faceDrawer[currentTick]
            } else {
                foregroundImageView.image = nil
            }
        }
    }
    @IBAction func tap(_ sender: Any) {
        Task {
            if await !metronome.isPlaying {
                tempoTextField.resignFirstResponder()
                try? await metronome.start()
            }else if await metronome.isPlaying, !tempoTextField.resignFirstResponder() {
                await metronome.stop()
                updateArcWithTick(currentTick: 0)
                wasRunning = true
            }
        }
    }

    
    
    func updateTempoLabel() {
        Task {
            tempoTextField.text = "\(await metronome.tempoBPM)"
        }
    }
    
    
    func updateMeterLabel() {
        Task {
            meterLabel.text = "\(await metronome.meter) / \(await metronome.division)"
        }
       
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        Task {
            guard let text = textField.text, let tempo = Int(text) else { return }
            await metronome.setTempo(to:tempo)
            updateTempoLabel()
        }
    }
}
