//
//  ViewController.swift
//  Overplay-UIKit
//
//  Created by Alvaro Peche on 26/03/24.
//

import UIKit
import AVKit
import CoreMotion
import MediaPlayer

enum VideoState: String { case playing, paused }

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var testLabel: UILabel!
    var player = CustomAVPlayer()
    var locationManager: CLLocationManager!
    let manager = CMMotionManager()

    private let INCREASE_THRESHOLD = 3.14...5.78
    private let DECREASE_THRESHOLD = 0.50...3.14
    private let VIDEO_TIME_VARIATION: Double = 5
    private let VIDEO_URL = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startUpdates()
        
        //MARK: LAUNCH AND PLAY VIDEO
        if let videoURL =  URL(string: VIDEO_URL) {
            player = CustomAVPlayer(url: videoURL)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = self.view.bounds
            self.view.layer.addSublayer(playerLayer)
            player.play()
        }
        locationManager = CLLocationManager()
        
        // Ask for Authorisation from the User.
        locationManager.requestAlwaysAuthorization()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
    }
    
    //MARK: RESTART ON DISTANCE CHANGE
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        player.seek(to: CMTime.zero)
        testLabel.text = "RESTARTED"
    }
    
    //MARK: PAUSE ON SHAKE
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { testLabel.text = player.playOrPause() }
    }
    
    func startUpdates() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 0.25
            manager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                
                //MARK: Z AXIS CONTROL ON VOLUME
                let rotationOnZ = atan2(data.gravity.x, data.gravity.y) + Double.pi
                if self.DECREASE_THRESHOLD.contains(rotationOnZ) {
                    MPVolumeView.changeVolume(.decrease)
                } else if self.INCREASE_THRESHOLD.contains(rotationOnZ) {
                    MPVolumeView.changeVolume(.increase)
                }
                //MARK: X AXIS CONTROL ON PLAYBACK
                let rotationOnX = atan2(data.gravity.z, data.gravity.y) + Double.pi
                if self.DECREASE_THRESHOLD.contains(rotationOnX) {
                    playback(isForward: false)
                    testLabel.text = "-\(Int(VIDEO_TIME_VARIATION)) SECONDS"
                } else if self.INCREASE_THRESHOLD.contains(rotationOnX) {
                    playback(isForward: true)
                    testLabel.text = "+\(Int(VIDEO_TIME_VARIATION)) SECONDS"
                }
            }
        }
    }
    
    private func playback(isForward: Bool) {
        guard let duration = player.currentItem?.duration
        else { return }

        let currentElapsedTime = player.currentTime().seconds
        var destinationTime = isForward ? (currentElapsedTime + VIDEO_TIME_VARIATION) : (currentElapsedTime - VIDEO_TIME_VARIATION)
        
        if destinationTime < 0 { destinationTime = 0 }
        if destinationTime < duration.seconds {
            let newTime = CMTime(value: Int64(destinationTime * 1000 as Float64), timescale: 1000)
            player.seek(to: newTime)
        }
    }
}

class CustomAVPlayer: AVPlayer {
    var state = VideoState.paused
    override func pause() {
        state = .paused
        super.pause()
    }
    
    override func play() {
        state = .playing
        super.play()
    }
    
    func playOrPause() -> String {
        switch state {
        case .playing: pause()
        case .paused: play()
        }
        return state.rawValue.uppercased()
    }
}

extension MPVolumeView {
    enum VolumeAction: Float {
        case increase = 0.05
        case decrease = -0.05
    }
    
    private static func canChange(action: VolumeAction, on slider: UISlider) -> Bool {
        switch action {
        case .decrease: slider.value != slider.minimumValue
        case .increase: slider.value != slider.maximumValue
        }
    }
    
    static func changeVolume(_ action: VolumeAction) {
        let volumeView = MPVolumeView()
        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        else { return }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            guard canChange(action: action, on: slider) else { return }
            slider.value = slider.value + action.rawValue
        }
    }
}
