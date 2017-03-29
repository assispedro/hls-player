//
//  MediaPlayerActions.swift
//  hls-player-rediseg
//
//  Created by Pedro Assis on 23/03/17.
//  Copyright © 2017 Pedro Assis. All rights reserved.
//

import Foundation

enum MediaState {
    case waiting
    case restarting
    case reloading
    case buffering
    case playing
    case paused
    case stopped
    case ended
    case error
    case pausedToSeek
}

class MediaPlayerActions: NSObject, VLCMediaPlayerDelegate {
    
    var state: MediaState
    var playedTimes: Int
    var isLive: Bool
    var mediaPlayer: VLCMediaPlayer!
    var mediaCurrentTime: Int
    var mediaDuration: Int!
    var mediaURL: String!
    let stateNotificationName = Notification.Name("MediaStateChanged")
    let timeNotificationName = Notification.Name("MediaTimeChanged")
    let durationNotificationName = Notification.Name("DurationAcquired")
    
    init(_ mediaURL: String!) {
        playedTimes = 0
        state = .waiting
        mediaPlayer = VLCMediaPlayer(options: ["--extraintf="])
        mediaCurrentTime = 0
        mediaDuration = 0
        isLive = false
        self.mediaURL = mediaURL
    }
    
    func prepareMedia() {
        setIsLive(mediaURL)
        let url = NSURL(string: mediaURL)
        
        mediaPlayer.media = VLCMedia(url: url as URL!)
        mediaPlayer.delegate = self
    }
    
    func start() {
        mediaPlayer.play()
    }
    
    private func setIsLive(_ mediaURL: String!) {
        let urlParts = mediaURL.components(separatedBy: ".")
        isLive = (urlParts.last == "m3u8" || urlParts.last == "ts")
    }
    
    private func changeState(_ state: MediaState) {
        self.state = state
        NotificationCenter.default.post(name: stateNotificationName, object: nil)
    }
    
    private func changeCurrentTime(_ mediaCurrentTime: Int) {
        self.mediaCurrentTime = mediaCurrentTime
        NotificationCenter.default.post(name: timeNotificationName, object: nil)
    }
    
    func checkPlayCause() {
        if state == .reloading || state == .restarting {
            pauseAfterReload()
        } else if state == .buffering {
            changeState(.playing)
            mediaDuration = Int(mediaPlayer.media.length.intValue)
            NotificationCenter.default.post(name: durationNotificationName, object: nil)
        } else {
            changeState(.playing)
        }
    }
    
    func checkStoppedCause() {
        if isLive == true {
            if state != .stopped {
                changeState(.error)
            }
        } else {
            if mediaDuration/1000 == mediaCurrentTime/1000 {
                changeState(.ended)
                playedTimes += 1
            } else {
                changeState(.error)
            }
        }
    }
    
    func checkBufferingCause() {
        if state == .waiting {
            changeState(.buffering)
        } else if state == .restarting {
            changeState(.reloading)
        } else if state == .reloading {
            pauseAfterReload()
        } else if state == .buffering {
            changeState(.playing)
            mediaDuration = Int(mediaPlayer.media.length.intValue)
            NotificationCenter.default.post(name: durationNotificationName, object: nil)
        }
    }
    
    func playbackControlPressed() {
        if state == .playing {
            let newState: MediaState = (isLive == true) ? .stopped : .paused
            changeState(newState)
            pauseStop()
        } else if state == .paused || state == .stopped {
            changeState(.playing)
            play()
        }
    }
    
    func pauseToSeek() {
        if state == .playing {
            mediaPlayer.pause()
            state = .pausedToSeek
        }
    }
    
    private func pauseAfterReload() {
        mediaCurrentTime = 0
        changeState(.paused)
        mediaPlayer.pause()
        NotificationCenter.default.post(name: timeNotificationName, object: nil)
    }
    
    func playAfterSeek() {
        if state == .pausedToSeek {
            state = .playing
            play()
        }
    }
    
    func reload() {
        let url = NSURL(string: mediaURL)
        mediaPlayer.media = VLCMedia(url: url as URL!)
        state = .restarting
        play()
    }
    
    private func play() {
        mediaPlayer.play()
    }
    
    private func pauseStop() {
        if isLive == true {
            mediaPlayer.stop()
        } else {
            mediaPlayer.pause()
        }
    }
    
    func moveToTime(_ mediaNewTime: Int) {
        let seconds = mediaNewTime - mediaCurrentTime
        if seconds < 0 {
            mediaPlayer.jumpBackward(Int32(abs(seconds/1000)))
        } else {
            mediaPlayer.jumpForward(Int32(seconds/1000))
        }
        changeCurrentTime(mediaCurrentTime + seconds)
    }
    
    // VLC Callbacks
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        changeCurrentTime(Int(mediaPlayer!.time.intValue))
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        let mediaPlayerState: Int = self.mediaPlayer!.state.rawValue
        switch mediaPlayerState {
        case 0:
            // VLCMediaPlayerStateStopped
            checkStoppedCause()
            break
        case 2:
            // VLCMediaPlayerStateBuffering
            checkBufferingCause()
            break
        case 4:
            // VLCMediaPlayerStateError
            changeState(.error)
            break
        case 5:
            // VLCMediaPlayerStatePlaying
            checkPlayCause()
            break
        default:
            break
        }
    }
}
