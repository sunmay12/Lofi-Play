//
//  AudioManager.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - AudioManagerDelegate
protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didUpdatePlaybackTime currentTime: TimeInterval, totalTime: TimeInterval)
    func audioManager(_ manager: AudioManager, didChangePlaybackState isPlaying: Bool)
    func audioManager(_ manager: AudioManager, didChangeTrack track: Track?)
    func audioManager(_ manager: AudioManager, didFinishPlaying track: Track)
    func audioManagerDidEncounterError(_ manager: AudioManager, error: Error)
    func audioManager(_ manager: AudioManager, didUpdateBufferProgress progress: Float)
}

class AudioManager: NSObject {
    
    // MARK: - Singleton
    static let shared = AudioManager()
    
    // MARK: - Properties
    weak var delegate: AudioManagerDelegate?
    
    private var audioPlayer: AVAudioPlayer?
    private var vinylNoisePlayer: AVAudioPlayer?  // 바이닐 노이즈 플레이어
    private var playbackTimer: Timer?
    private var bufferTimer: Timer?
    private var currentTrackIndex: Int = 0
    private var playlist: [Track] = []
    private var currentAlbum: Album?
    
    // Firebase Storage 스트리밍을 위한 프로퍼티
    private var downloadTask: URLSessionDataTask?
    private var expectedContentLength: Int64 = 0
    private var receivedContentLength: Int64 = 0
    
    // 바이닐 노이즈 설정 (항상 활성화)
    private let vinylNoiseVolume: Float = 0.5  // 고정 노이즈 볼륨 (25%)
    
    // MARK: - Public Properties
    var currentTrack: Track? {
        return playlist.isEmpty ? nil : playlist[currentTrackIndex]
    }
    
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    var volume: Float {
        get { return audioPlayer?.volume ?? 0.5 }
        set {
            audioPlayer?.volume = newValue
            // 메인 볼륨에 따라 노이즈 볼륨도 조정
            updateVinylNoiseVolume()
        }
    }
    
    var currentPlaylist: [Track] {
        return playlist
    }
    
    var bufferProgress: Float {
        guard expectedContentLength > 0 else { return 0 }
        return Float(receivedContentLength) / Float(expectedContentLength)
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNotifications()
        setupVinylNoise()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlaybackTimer()
        stopBufferTimer()
        downloadTask?.cancel()
        vinylNoisePlayer?.stop()
    }
    
    // MARK: - Setup Methods
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            delegate?.audioManagerDidEncounterError(self, error: error)
        }
    }
    
    // 바이닐 노이즈 설정
    private func setupVinylNoise() {
        // 번들에서 바이닐 노이즈 파일을 찾거나, 프로그래밍적으로 생성
        if let vinylNoiseURL = createVinylNoiseFile() {
            do {
                vinylNoisePlayer = try AVAudioPlayer(contentsOf: vinylNoiseURL)
                vinylNoisePlayer?.numberOfLoops = -1  // 무한 반복
                vinylNoisePlayer?.volume = 0
                vinylNoisePlayer?.prepareToPlay()
            } catch {
                print("Failed to setup vinyl noise: \(error)")
            }
        }
    }
    
    // 바이닐 노이즈 파일 생성 (간단한 화이트 노이즈)
    private func createVinylNoiseFile() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vinylNoiseURL = documentsPath.appendingPathComponent("vinyl_noise.wav")
        
        // 이미 파일이 있으면 반환
        if FileManager.default.fileExists(atPath: vinylNoiseURL.path) {
            return vinylNoiseURL
        }
        
        // 간단한 화이트 노이즈 생성
        generateVinylNoiseFile(at: vinylNoiseURL)
        return vinylNoiseURL
    }
    
    private func generateVinylNoiseFile(at url: URL) {
        let sampleRate: Double = 44100
        let duration: Double = 10.0  // 10초 루프
        let frameCount = UInt32(sampleRate * duration)
        
        guard let audioFile = try? AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        ) else { return }
        
        let format = audioFile.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        // 바이닐 스타일 노이즈 생성 (화이트 노이즈 + 약간의 크래클)
        for channel in 0..<Int(format.channelCount) {
            guard let channelData = buffer.floatChannelData?[channel] else { continue }
            
            for frame in 0..<Int(frameCount) {
                // 베이스 화이트 노이즈
                let whiteNoise = Float.random(in: -0.1...0.1)
                
                // 크래클 효과 (가끔 튀는 소리)
                let crackle = (Float.random(in: 0...1) < 0.001) ? Float.random(in: -0.3...0.3) : 0
                
                // 저주파 럼블 (LP의 모터 소음)
                let rumble = sin(Float(frame) * 0.001) * 0.05
                
                channelData[frame] = whiteNoise + crackle + rumble
            }
        }
        
        try? audioFile.write(from: buffer)
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Vinyl Noise Control
    private func startVinylNoise() {
        guard let vinylNoisePlayer = vinylNoisePlayer, isPlaying else { return }
        
        if !vinylNoisePlayer.isPlaying {
            updateVinylNoiseVolume()
            vinylNoisePlayer.play()
        }
    }
    
    private func stopVinylNoise() {
        vinylNoisePlayer?.pause()
    }
    
    private func updateVinylNoiseVolume() {
        guard let vinylNoisePlayer = vinylNoisePlayer else { return }
        
        // 메인 볼륨과 고정 노이즈 레벨을 곱해서 최종 볼륨 결정
        let finalVolume = (audioPlayer?.volume ?? 0.5) * vinylNoiseVolume
        vinylNoisePlayer.volume = finalVolume
    }
    
    // MARK: - Notification Handlers
    @objc private func audioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func audioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            pause()
        default:
            break
        }
    }
    
    // MARK: - Playback Control
    func setPlaylist(_ tracks: [Track], startIndex: Int = 0, album: Album? = nil) {
        playlist = tracks
        currentTrackIndex = max(0, min(startIndex, tracks.count - 1))
        currentAlbum = album
    }
    
    func play(track: Track? = nil) {
        if let track = track {
            if let index = playlist.firstIndex(where: { $0.id == track.id }) {
                currentTrackIndex = index
            } else {
                playlist = [track]
                currentTrackIndex = 0
                currentAlbum = nil
            }
        }
        
        guard let currentTrack = currentTrack else { return }
        
        if audioPlayer?.url?.absoluteString == currentTrack.audioURL && audioPlayer != nil {
            audioPlayer?.play()
            startPlaybackTimer()
            startVinylNoise()  // 바이닐 노이즈 시작
            delegate?.audioManager(self, didChangePlaybackState: true)
            updateNowPlayingInfo()
            return
        }
        
        loadAndPlayTrack(currentTrack)
    }
    
    private func loadAndPlayTrack(_ track: Track) {
        downloadTask?.cancel()
        downloadTask = nil
        
        guard let url = URL(string: track.audioURL) else {
            delegate?.audioManagerDidEncounterError(self, error: AudioManagerError.invalidURL)
            return
        }
        
        if url.scheme == "http" || url.scheme == "https" {
            streamFromURL(url: url, track: track)
        } else {
            playLocalFile(url: url, track: track)
        }
    }
    
    private func streamFromURL(url: URL, track: Track) {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        
        downloadTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    if (error as NSError).code != NSURLErrorCancelled {
                        self.delegate?.audioManagerDidEncounterError(self, error: error)
                    }
                    return
                }
                
                guard let data = data else {
                    self.delegate?.audioManagerDidEncounterError(self, error: AudioManagerError.downloadFailed)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self.expectedContentLength = httpResponse.expectedContentLength
                    self.receivedContentLength = Int64(data.count)
                }
                
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.setupAudioPlayer(track: track)
                } catch {
                    self.delegate?.audioManagerDidEncounterError(self, error: error)
                }
            }
        }
        
        downloadTask?.resume()
        startBufferTimer()
    }
    
    private func playLocalFile(url: URL, track: Track) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            setupAudioPlayer(track: track)
        } catch {
            delegate?.audioManagerDidEncounterError(self, error: error)
        }
    }
    
    private func setupAudioPlayer(track: Track) {
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
        startPlaybackTimer()
        startVinylNoise()  // 바이닐 노이즈 시작
        delegate?.audioManager(self, didChangeTrack: track)
        delegate?.audioManager(self, didChangePlaybackState: true)
        updateNowPlayingInfo()
    }
    
    func pause() {
        audioPlayer?.pause()
        stopVinylNoise()  // 바이닐 노이즈 정지
        stopPlaybackTimer()
        stopBufferTimer()
        delegate?.audioManager(self, didChangePlaybackState: false)
        updateNowPlayingInfo()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopVinylNoise()  // 바이닐 노이즈 정지
        downloadTask?.cancel()
        downloadTask = nil
        stopPlaybackTimer()
        stopBufferTimer()
        delegate?.audioManager(self, didChangePlaybackState: false)
        clearNowPlayingInfo()
    }
    
    func playNext() {
        guard !playlist.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % playlist.count
        play()
    }
    
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        
        if currentTime > 3.0 {
            seek(to: 0)
        } else {
            currentTrackIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.count - 1
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = max(0, min(time, duration))
        delegate?.audioManager(self, didUpdatePlaybackTime: currentTime, totalTime: duration)
        updateNowPlayingInfo()
    }
    
    // MARK: - Timer Management
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.audioManager(self, didUpdatePlaybackTime: self.currentTime, totalTime: self.duration)
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func startBufferTimer() {
        stopBufferTimer()
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.audioManager(self, didUpdateBufferProgress: self.bufferProgress)
        }
    }
    
    private func stopBufferTimer() {
        bufferTimer?.invalidate()
        bufferTimer = nil
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        
        if let album = currentAlbum {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album.title
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let album = currentAlbum {
            ImageCacheManager.shared.loadImage(from: album.coverImageURL) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                            return image
                        }
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Utility Methods
    func skipToTrack(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        currentTrackIndex = index
        play()
    }
    
    func getCurrentTrackIndex() -> Int {
        return currentTrackIndex
    }
    
    func isCurrentTrack(_ track: Track) -> Bool {
        return currentTrack?.id == track.id
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopBufferTimer()
        
        // 메인 오디오가 끝났는지 확인 (바이닐 노이즈가 아닌)
        if player == audioPlayer {
            guard let track = currentTrack else { return }
            delegate?.audioManager(self, didFinishPlaying: track)
            
            if currentTrackIndex < playlist.count - 1 {
                playNext()
            } else {
                stop()
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if player == audioPlayer {
            stopBufferTimer()
            if let error = error {
                delegate?.audioManagerDidEncounterError(self, error: error)
            }
        }
    }
}

// MARK: - AudioManagerError
enum AudioManagerError: LocalizedError {
    case invalidURL
    case downloadFailed
    case playbackFailed
    case networkError
    case audioSessionError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .downloadFailed:
            return "Failed to download audio file"
        case .playbackFailed:
            return "Failed to play audio"
        case .networkError:
            return "Network connection error"
        case .audioSessionError:
            return "Audio session error"
        }
    }
}
