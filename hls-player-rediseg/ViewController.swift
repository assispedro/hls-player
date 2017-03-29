//
//  ViewController.swift
//  hls-player-rediseg
//
//  Created by Pedro Assis on 17/03/17.
//  Copyright © 2017 Pedro Assis. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit
import SystemConfiguration

class ViewController: UIViewController {
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var mediaControlsView: UIView!
    @IBOutlet weak var scrubberOuterCircle: UIView!
    @IBOutlet weak var scrubberInnerCircle: UIView!
    @IBOutlet weak var progressBarView: UIView!
    @IBOutlet weak var seekBarView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var playbackControlButton: UIButton!
    @IBOutlet weak var fullscreenButton: UIButton!
    
    lazy var playButtonImage: UIImage? = self.imageFromName("play")
    lazy var pauseButtonImage: UIImage? = self.imageFromName("pause")
    lazy var stopButtonImage: UIImage? = self.imageFromName("stop")
    lazy var fullscreenButtonImage: UIImage? = self.imageFromName("fullscreen")
    lazy var fullscreenExitButtonImage: UIImage? = self.imageFromName("fullscreen_exit")

    var counter: Float!
    var videoFullscreen: Bool!
    var mediaPlayerActions: MediaPlayerActions!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preparePlayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func playbackControlPressed(sender: UIButton) {
        mediaPlayerActions.playbackControlPressed()
    }
    
    @IBAction func fullscreenControlPressed(sender: UIButton) {
        let value = videoFullscreen == true ? UIInterfaceOrientation.portrait.rawValue :
                                              UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.changeAspect),
                                               name: .UIDeviceOrientationDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.mediaPlayerStateChanged),
                                               name: mediaPlayerActions.stateNotificationName,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.mediaPlayerTimeChanged),
                                               name: mediaPlayerActions.timeNotificationName,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.setupCounter),
                                               name: mediaPlayerActions.durationNotificationName,
                                               object: nil)
    }
    
    func setupGestureActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapVideoScreen(sender:)))
        videoView.addGestureRecognizer(tapGesture)
        
        if mediaPlayerActions.isLive == false {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(sender:)))
            scrubberOuterCircle.addGestureRecognizer(panGesture)
        }
    }
    
    func mediaPlayerStateChanged() {
        let state = mediaPlayerActions.state
        updateControlButtons(state)
        
        if state == .error {
            showNormalAlert(self, title: "Erro", message: "O vídeo pode estar offline")
            finish()
        } else if state == .ended {
            mediaPlayerActions.reload()
        }
    }
    
    func mediaPlayerTimeChanged() {
        updateScrubberPosition(withDuration: mediaPlayerActions.mediaCurrentTime, withPosition: nil)
    }
    
    func updateControlButtons(_ state: MediaState!) {
        if state == .paused || state == .stopped {
            playbackControlButton?.setImage(playButtonImage, for: UIControlState())
        } else if mediaPlayerActions.isLive == true {
            playbackControlButton?.setImage(stopButtonImage, for: UIControlState())
        } else {
            playbackControlButton?.setImage(pauseButtonImage, for: UIControlState())
        }
    }
    
    func setupCounter() {
        counter = Float(seekBarView.frame.width)/(Float(mediaPlayerActions.mediaDuration)/1000.0)
        activityIndicator.stopAnimating()
        prepareProgressBarAndLabels()
        NotificationCenter.default.removeObserver(self, name: mediaPlayerActions.durationNotificationName, object: nil)
        fadeOut(withDuration: 3.0)
    }
    
    func changeAspect() {
        let orientation = UIDevice.current.orientation
        
        if UIDeviceOrientationIsLandscape(orientation) {
            let screenBounds = UIScreen.main.bounds
            self.videoView.frame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
            self.mediaControlsView.frame = CGRect(x: 0,
                                                  y: screenBounds.height - self.mediaControlsView.frame.height,
                                                  width: screenBounds.width,
                                                  height: self.mediaControlsView.frame.height)
            videoFullscreen = true
            fullscreenButton?.setImage(fullscreenExitButtonImage, for: UIControlState())
        } else if UIDeviceOrientationIsPortrait(orientation) {
            videoFullscreen = false
            fullscreenButton?.setImage(fullscreenButtonImage, for: UIControlState())
        }
        updateCounter()
    }
    
    func updateScrubberPosition(withDuration duration: Int?, withPosition position: CGFloat?) {
        if mediaPlayerActions.isLive == false {
            var scrubberFrame: CGRect = self.scrubberOuterCircle.frame;
            if duration != nil {
                let positionWithDuration = CGFloat(counter*(Float(duration!)/1000.0)) - scrubberFrame.size.width/2.0
                scrubberFrame.origin.x = positionWithDuration
                self.scrubberOuterCircle.frame = scrubberFrame
            } else if position != nil {
                scrubberOuterCircle.center.x = position!
            }
            updateProgressBar(withDuration: duration, withPosition: position)
            updateTimeLabel(withDuration: duration, withPosition: position)
        }
    }
    
    func updateProgressBar(withDuration duration: Int?, withPosition position: CGFloat?) {
        if mediaPlayerActions.isLive == false {
            var frame: CGRect = self.progressBarView.frame
            let frame2: CGRect = self.scrubberInnerCircle.frame
            let offset = frame2.size.width/3.0
            if duration != nil {
                frame.size.width = CGFloat(counter*(Float(duration!)/1000.0)) - offset
            } else {
                frame.size.width = position! - offset
            }
            self.progressBarView?.frame = frame
        }
    }
    
    func updateTimeLabel(withDuration duration: Int?, withPosition position: CGFloat?) {
        let time = duration != nil ? duration : Int(Float(position!)*1000/counter)
        let minutes = (time!/1000/60)
        let seconds = time!/1000 - minutes*60
        self.currentTimeLabel?.text = String(format:"%02d:%02d", minutes, seconds)
    }
    
    func updateCounter() {
        if mediaPlayerActions.isLive == false {
            if mediaPlayerActions.mediaDuration != 0 {
                let time = mediaPlayerActions.mediaCurrentTime
                counter = Float(seekBarView.frame.width)/(Float(mediaPlayerActions.mediaDuration)/1000.0)
                updateScrubberPosition(withDuration: time, withPosition: nil)
            }
        } else {
            var progressBarFrame: CGRect = progressBarView.frame
            var scrubberFrame: CGRect = scrubberOuterCircle.frame
            progressBarFrame.size.width = seekBarView.frame.width
            scrubberFrame.origin.x = seekBarView.frame.width - scrubberFrame.size.width/2.0
            progressBarView.frame = progressBarFrame
            scrubberOuterCircle.frame = scrubberFrame
        }
    }
    
    func prepareProgressBarAndLabels() {
        if mediaPlayerActions.isLive == true {
            var progressBarFrame: CGRect = progressBarView.frame
            var scrubberFrame: CGRect = scrubberOuterCircle.frame
            let scrubberInnerFrame: CGRect = scrubberInnerCircle.frame
            progressBarFrame.size.width = seekBarView.frame.width - scrubberInnerFrame.size.width
            scrubberFrame.origin.x = seekBarView.frame.width - scrubberFrame.size.width/2.0
            progressBarView.frame = progressBarFrame
            scrubberOuterCircle.frame = scrubberFrame
            durationLabel?.text = "AO VIVO"
            currentTimeLabel?.text = ""
        } else {
            let minutes = mediaPlayerActions.mediaDuration/1000/60
            let seconds = mediaPlayerActions.mediaDuration/1000 - minutes*60
            durationLabel?.text = String(format:"%02d:%02d", minutes, seconds)
        }
    }
    
    func tapVideoScreen(sender: UITapGestureRecognizer) {
        if mediaControlsView.alpha == 0.0 {
            self.fadeIn()
        } else {
            self.fadeOut()
        }
    }
    
    func preparePlayer() {
        videoFullscreen = false
        counter = 0.0
        mediaPlayerActions = MediaPlayerActions("http://clips.vorwaerts-gmbh.de/VfE_html5.mp4")
        mediaPlayerActions.prepareMedia()
        applyScrubberLayout()
        addControlButtos()
        setupGestureActions()
        setupNotifications()
        mediaPlayerActions.mediaPlayer.drawable = self.videoView
        mediaPlayerActions.start()
    }
    
    func applyScrubberLayout() {
        scrubberOuterCircle.layer.cornerRadius = 6;
        scrubberInnerCircle.layer.cornerRadius = 3;
        scrubberOuterCircle.layoutMargins = UIEdgeInsetsMake(10, 10, 10, 10)
    }
    
    func addControlButtos() {
        if mediaPlayerActions.isLive == true {
            playbackControlButton?.setImage(stopButtonImage, for: UIControlState())
        } else {
            playbackControlButton?.setImage(playButtonImage, for: UIControlState())
        }
        fullscreenButton?.setImage(fullscreenButtonImage, for: UIControlState())
    }
    
    func pan(sender: UIPanGestureRecognizer) {
        let locationInView = sender.location(in: self.view)
        if sender.state == .began {
            mediaPlayerActions.pauseToSeek()
        } else if sender.state == .changed {
            updateScrubberPosition(withDuration: nil, withPosition: locationInView.x)
        } else if sender.state == .cancelled || sender.state == .ended {
            updateScrubberPosition(withDuration: nil, withPosition: locationInView.x)
            let newSeconds = (Float(locationInView.x) * 1000.0)/counter
            mediaPlayerActions.moveToTime(Int(newSeconds))
            mediaPlayerActions.playAfterSeek()
        }
    }
    
    func fadeIn(withDuration duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration, animations: {
            self.mediaControlsView.alpha = 1.0
        })
    }
    
    func fadeOut(withDuration duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration, animations: {
            self.mediaControlsView.alpha = 0.0
        })
    }
    
    func finish() {
        // TODO return to prevous page
    }
    
    // TODO Move to another file, like utils or helper
    func showNormalAlert(_ controller: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
    
    
    func imageFromName(_ name: String) -> UIImage? {
        return UIImage(named: name, in: Bundle(for: type(of: self)), compatibleWith: nil)
    }
}

