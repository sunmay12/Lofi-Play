//
//  PlayerViewController.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import UIKit
import AVFoundation
import Combine

class PlayerViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var albumCoverImageView: UIImageView!
    @IBOutlet weak var emptyLPImageView: UIImageView!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var myButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var backView: UIImageView!
    @IBOutlet weak var tonearmImageView: UIImageView!
    @IBOutlet weak var playButtonLabel: UILabel!
    @IBOutlet weak var myButtonLabel: UILabel!
    @IBOutlet weak var previousButtonLabel: UILabel!
    @IBOutlet weak var nextButtonLabel: UILabel!
    
    // MARK: - Properties
    private let playerData = PlayerData.shared
    private var isSaved: Bool = false
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var rotationAnimation: CABasicAnimation?
    private var cancellables = Set<AnyCancellable>()
    
    // UserManager를 통한 사용자 ID 프로퍼티 추가
    private var currentUserID: String? {
        return UserManager.shared.currentUserID
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAudioSession()
        setupBindings()
        setupPlayerWithCurrentData()
        checkIfAlbumIsSaved()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopProgressTimer()
    }
    
    deinit {
        progressTimer?.invalidate()
        audioPlayer?.stop()
        cancellables.removeAll()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        // BackView를 화면 맨 아래로 설정
        setupBackView()
        
        // EmptyLP 이미지 설정 (앨범 커버보다 뒤에 배치)
        setupEmptyLPImageView()
        
        // LP 이미지를 원형으로 만들기
        albumCoverImageView.layer.cornerRadius = albumCoverImageView.frame.width / 2
        albumCoverImageView.layer.masksToBounds = true
        
        // 진행바 설정
        setupProgressSlider()
        
        // 버튼 설정
        setupButtons()
        
        // Tonearm 설정
        setupTonearm()
    }
    
    private func setupBackView() {
        // BackView를 화면 맨 아래 배치
        view.sendSubviewToBack(backView)
    }
    
    private func setupEmptyLPImageView() {
        // EmptyLP 이미지뷰를 원형으로 만들기
        emptyLPImageView.layer.cornerRadius = emptyLPImageView.frame.width / 2
        emptyLPImageView.layer.masksToBounds = true
        
        // 앨범 커버보다 뒤에 배치
        view.bringSubviewToFront(emptyLPImageView)
        view.sendSubviewToBack(emptyLPImageView)
        view.sendSubviewToBack(backView)
    }
    
    private func setupTonearm() {
        // Tonearm을 왼쪽으로 살짝 기울임
//        tonearmImageView.transform = CGAffineTransform(rotationAngle: -0.15)
        
        // Tonearm의 기본 설정
        tonearmImageView.contentMode = .scaleAspectFit
        tonearmImageView.backgroundColor = UIColor.clear
    }
    
    private func setupProgressSlider() {
        progressSlider.minimumValue = 0
        progressSlider.addTarget(self, action: #selector(progressSliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        
        // 진행바 커스터마이징 - 동그라미(thumb) 제거하고 색깔로만 표시
        progressSlider.setThumbImage(UIImage(), for: .normal)
        progressSlider.setThumbImage(UIImage(), for: .highlighted)
        
        // 진행바 색상 설정
        progressSlider.minimumTrackTintColor = UIColor.systemGray2
        progressSlider.maximumTrackTintColor = UIColor.systemGray5
        
        // 진행바 높이 조절
        progressSlider.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
    }
    
    private func setupButtons() {
        // 버튼 기본 설정
        let buttons = [playButton, myButton, previousButton, nextButton]
        
        buttons.forEach { button in
            guard let btn = button else { return }
            
            // 3D 버튼 효과 설정
            btn.backgroundColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0)
            btn.layer.cornerRadius = 12
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.systemGray.cgColor
            
            // 그림자 효과 (튀어나온 효과)
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowOpacity = 0.3
            btn.layer.shadowRadius = 3
            btn.layer.masksToBounds = false
            
            // 내부 그림자 효과를 위한 추가 레이어
            let innerShadowLayer = CALayer()
            innerShadowLayer.frame = btn.bounds
            innerShadowLayer.cornerRadius = 12
            innerShadowLayer.backgroundColor = UIColor.white.withAlphaComponent(0.2).cgColor
            innerShadowLayer.shadowColor = UIColor.white.cgColor
            innerShadowLayer.shadowOffset = CGSize(width: 0, height: -1)
            innerShadowLayer.shadowOpacity = 0.1
            innerShadowLayer.shadowRadius = 2
            btn.layer.insertSublayer(innerShadowLayer, at: 0)
            
            btn.setTitle("", for: .normal)
        }
        
        // 버튼 아래 텍스트 라벨들 설정
        setupButtonLabels()
    }
    
    private func setupButtonLabels() {
        let labels = [playButtonLabel, myButtonLabel, previousButtonLabel, nextButtonLabel]
        let labelTexts = ["play", "my", "◀◀", "▶▶"]
        
        for (index, label) in labels.enumerated() {
            guard let lbl = label else { continue }
            
            lbl.text = labelTexts[index]
            lbl.textAlignment = .center
            lbl.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            lbl.textColor = UIColor.darkGray
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupBindings() {
        // PlayerData의 변경사항을 UI에 반영
        playerData.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadCurrentTrack()
            }
            .store(in: &cancellables)
        
        playerData.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.updatePlayButton(isPlaying: isPlaying)
                if isPlaying {
                    self?.playAudio()
                } else {
                    self?.pauseAudio()
                }
            }
            .store(in: &cancellables)
        
        // 현재 시간 업데이트를 직접 바인딩하지 않고 타이머로 처리
        playerData.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.updateDurationDisplay(duration: duration)
            }
            .store(in: &cancellables)
    }
    
    private func setupPlayerWithCurrentData() {
        // PlayerData에서 현재 트랙 정보 가져와서 UI 업데이트
        guard playerData.hasCurrentTrack else {
            print("재생할 트랙이 없습니다.")
            return
        }
        
        loadCurrentTrack()
    }
    
    // MARK: - 통일된 버튼 상태 관리 메서드
    private func setButtonState(_ button: UIButton, pressed: Bool) {
        let baseColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0)
        
        if pressed {
            // 눌려있는 상태 - 배경색을 아주 살짝 어둡게, 그림자 제거
            button.backgroundColor = baseColor.withAlphaComponent(3)
            button.layer.shadowOpacity = 0
        } else {
            // 일반 상태 - 원래 배경색, 그림자 복원
            button.backgroundColor = baseColor
            button.layer.shadowOpacity = 0.3
        }
    }
    
    // MARK: - Track Loading
    private func loadCurrentTrack() {
        guard let track = playerData.currentTrack,
              let album = playerData.currentAlbum else { return }
        
        updateUI(with: track, album: album)
        loadAudio(from: track.audioURL)
    }
    
    private func updateUI(with track: Track, album: Album) {
        trackTitleLabel.text = track.title
        artistLabel.text = track.artist
        
        // 앨범 커버 이미지 로드
        albumCoverImageView.loadImage(from: album.coverImageURL)
        
        progressSlider.maximumValue = Float(track.duration)
        progressSlider.value = 0
        
        // PlayerData에 duration 설정
        playerData.setDuration(track.duration)
    }
    
    private func loadAudio(from urlString: String) {
        NetworkManager.shared.downloadAudio(from: urlString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.setupAudioPlayer(with: data)
                case .failure(let error):
                    print("Failed to load audio: \(error)")
                    self?.showErrorAlert("음악을 불러올 수 없습니다.")
                }
            }
        }
    }
    
    private func setupAudioPlayer(with data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = playerData.volume
            
            // PlayerData의 재생 상태에 따라 자동 재생
            if playerData.isPlaying {
                playAudio()
            }
        } catch {
            print("Failed to setup audio player: \(error)")
            showErrorAlert("음악 재생 중 오류가 발생했습니다.")
        }
    }
    
    // MARK: - Audio Control
    private func playAudio() {
        guard let player = audioPlayer else { return }
        
        player.play()
        startProgressTimer()
        startLPRotation()
        
        // Tonearm 애니메이션 (재생 시 LP 위로 이동)
        animateTonearmToPlay()
    }
    
    private func pauseAudio() {
        audioPlayer?.pause()
        stopProgressTimer()
        pauseLPRotation()
        
        // Tonearm 애니메이션 (일시정지 시 원위치)
        animateTonearmToPause()
    }
    
    private func updatePlayButton(isPlaying: Bool) {
        playButtonLabel.text = isPlaying ? "pause" : "play"
        setButtonState(playButton, pressed: isPlaying)
    }
    
    // MARK: - Tonearm Animation
    private func animateTonearmToPlay() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {
            self.tonearmImageView.transform = CGAffineTransform(rotationAngle: 0.005) // LP 위로 이동
        }
    }
    
    private func animateTonearmToPause() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {
            self.tonearmImageView.transform = CGAffineTransform(rotationAngle: -0.1) // 원위치
        }
    }
    
    // MARK: - LP Animation (앨범 커버와 EmptyLP 함께 회전)
    private func startLPRotation() {
        // 이미 애니메이션이 실행 중이면 재개
        guard albumCoverImageView.layer.animation(forKey: "rotation") == nil else {
            resumeLPRotation()
            return
        }
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 3.0
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        
        // 앨범 커버와 EmptyLP 모두에 회전 애니메이션 적용
        albumCoverImageView.layer.add(rotation, forKey: "rotation")
        emptyLPImageView.layer.add(rotation, forKey: "rotation")
        rotationAnimation = rotation
    }
    
    private func pauseLPRotation() {
        let pausedTime = albumCoverImageView.layer.convertTime(CACurrentMediaTime(), from: nil)
        
        // 앨범 커버 일시정지
        albumCoverImageView.layer.speed = 0.0
        albumCoverImageView.layer.timeOffset = pausedTime
        
        // EmptyLP 일시정지
        emptyLPImageView.layer.speed = 0.0
        emptyLPImageView.layer.timeOffset = pausedTime
    }
    
    private func resumeLPRotation() {
        let pausedTime = albumCoverImageView.layer.timeOffset
        let timeSincePause = albumCoverImageView.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        
        // 앨범 커버 재개
        albumCoverImageView.layer.speed = 1.0
        albumCoverImageView.layer.timeOffset = 0.0
        albumCoverImageView.layer.beginTime = 0.0
        albumCoverImageView.layer.beginTime = timeSincePause
        
        // EmptyLP 재개
        emptyLPImageView.layer.speed = 1.0
        emptyLPImageView.layer.timeOffset = 0.0
        emptyLPImageView.layer.beginTime = 0.0
        emptyLPImageView.layer.beginTime = timeSincePause
    }
    
    private func stopLPRotation() {
        // 앨범 커버 애니메이션 정지
        albumCoverImageView.layer.removeAnimation(forKey: "rotation")
        albumCoverImageView.layer.speed = 1.0
        albumCoverImageView.layer.timeOffset = 0.0
        
        // EmptyLP 애니메이션 정지
        emptyLPImageView.layer.removeAnimation(forKey: "rotation")
        emptyLPImageView.layer.speed = 1.0
        emptyLPImageView.layer.timeOffset = 0.0
    }
    
    // MARK: - Progress Timer
    private var isUserInteractingWithSlider = false
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer, !isUserInteractingWithSlider else { return }
        
        let currentTime = player.currentTime
        
        // UI 직접 업데이트 (사용자가 슬라이더를 조작하지 않을 때만)
        updateTimeDisplay(currentTime: currentTime)
        
        // PlayerData도 업데이트 (다른 곳에서 사용할 수 있으므로)
        playerData.updateCurrentTime(currentTime)
    }
    
    private func updateTimeDisplay(currentTime: TimeInterval) {
        progressSlider.value = Float(currentTime)
    }
    
    private func updateDurationDisplay(duration: TimeInterval) {
        progressSlider.maximumValue = Float(duration)
    }
    
    // MARK: - Library Management
    private func checkIfAlbumIsSaved() {
        guard let album = playerData.currentAlbum,
              let userID = currentUserID else {
            updateMyButtonState()
            return
        }
        
        FirebaseManager.shared.isAlbumSaved(albumId: album.id, forUserID: userID) { [weak self] isSaved in
            DispatchQueue.main.async {
                self?.isSaved = isSaved
                self?.updateMyButtonState()
            }
        }
    }
    
    private func updateMyButtonState() {
        myButtonLabel.text = "my"
        setButtonState(myButton, pressed: isSaved)
        
        // 로그인되지 않은 경우 버튼 비활성화
        myButton.isEnabled = currentUserID != nil
    }
    
    private func toggleSaveAlbum() {
        guard let album = playerData.currentAlbum,
              let userID = currentUserID else {
            showErrorAlert("로그인이 필요합니다.")
            return
        }
        
        if isSaved {
            // 라이브러리에서 제거
            FirebaseManager.shared.removeAlbumFromLibrary(albumId: album.id, forUserID: userID) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.isSaved = false
                        self?.updateMyButtonState()
                        self?.showToast("라이브러리에서 제거되었습니다.")
                    } else {
                        self?.showErrorAlert("제거에 실패했습니다.")
                    }
                }
            }
        } else {
            // 라이브러리에 추가
            FirebaseManager.shared.saveAlbumToLibrary(album: album, forUserID: userID) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.isSaved = true
                        self?.updateMyButtonState()
                        self?.showToast("라이브러리에 저장되었습니다.")
                    } else {
                        self?.showErrorAlert("저장에 실패했습니다.")
                    }
                }
            }
        }
    }
    
    // MARK: - IBActions
    @IBAction func playButtonTapped(_ sender: UIButton) {
        playerData.togglePlayPause()
    }
    
    @IBAction func myButtonTapped(_ sender: UIButton) {
        toggleSaveAlbum()
    }
    
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        stopLPRotation()
        playerData.previousTrack()
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        stopLPRotation()
        playerData.nextTrack()
    }
    
    @objc private func progressSliderChanged(_ sender: UISlider) {
        guard let player = audioPlayer else { return }
        
        let newTime = TimeInterval(sender.value)
        player.currentTime = newTime
        
        // UI 즉시 업데이트
        playerData.updateCurrentTime(newTime)
    }
    
    @objc private func progressSliderTouchDown(_ sender: UISlider) {
        isUserInteractingWithSlider = true
    }
    
    @objc private func progressSliderTouchUp(_ sender: UISlider) {
        isUserInteractingWithSlider = false
    }
    
    // MARK: - Utility Methods
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension PlayerViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            stopLPRotation()
            animateTonearmToPause()
            playerData.nextTrack()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        showErrorAlert("음악 재생 중 오류가 발생했습니다.")
        playerData.isPlaying = false
    }
}
