//
//  PlayerData.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation
import Combine

// MARK: - PlayerData 클래스 (플레이어 상태 관리)
class PlayerData: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentAlbum: Album?
    @Published var currentTrack: Track?
    @Published var currentTrackIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .none
    @Published var volume: Float = 1.0
    @Published var playbackRate: Float = 1.0
    
    // MARK: - Private Properties
    private var tracks: [Track] = []
    private var originalTrackOrder: [Track] = []
    private var shuffledIndices: [Int] = []
    
    // MARK: - Singleton
    static let shared = PlayerData()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 앨범과 트랙 설정
    func setAlbumAndTrack(album: Album, trackIndex: Int = 0) {
        self.currentAlbum = album
        self.tracks = album.tracks
        self.originalTrackOrder = album.tracks
        self.currentTrackIndex = min(trackIndex, tracks.count - 1)
        self.currentTrack = tracks.isEmpty ? nil : tracks[currentTrackIndex]
        
        // 셔플이 활성화되어 있다면 다시 셔플
        if isShuffleEnabled {
            shuffleTracks()
        }
    }
    
    /// 특정 트랙으로 이동
    func setCurrentTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        currentTrackIndex = index
        currentTrack = tracks[index]
    }
    
    /// 다음 트랙으로 이동
    func nextTrack() {
        switch repeatMode {
        case .none:
            if currentTrackIndex < tracks.count - 1 {
                currentTrackIndex += 1
                currentTrack = tracks[currentTrackIndex]
            } else {
                // 마지막 트랙이면 정지
                isPlaying = false
            }
        case .one:
            // 현재 트랙 반복 (인덱스 변경 없음)
            break
        case .all:
            currentTrackIndex = (currentTrackIndex + 1) % tracks.count
            currentTrack = tracks[currentTrackIndex]
        }
        
        resetTrackTime()
    }
    
    /// 이전 트랙으로 이동
    func previousTrack() {
        // 재생 시간이 3초 이상이면 현재 트랙을 처음부터 재생
        if currentTime > 3.0 {
            currentTime = 0
            return
        }
        
        if currentTrackIndex > 0 {
            currentTrackIndex -= 1
        } else {
            // 첫 번째 트랙에서 이전 버튼을 누르면 마지막 트랙으로
            currentTrackIndex = tracks.count - 1
        }
        
        currentTrack = tracks[currentTrackIndex]
        resetTrackTime()
    }
    
    /// 셔플 토글
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            shuffleTracks()
        } else {
            restoreOriginalOrder()
        }
    }
    
    /// 반복 모드 변경
    func toggleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .none
        }
    }
    
    /// 재생/일시정지 토글
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    /// 재생 시간 업데이트
    func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
    }
    
    /// 트랙 지속시간 설정
    func setDuration(_ duration: TimeInterval) {
        self.duration = duration
    }
    
    /// 진행률 계산 (0.0 ~ 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// 현재 트랙 정보가 있는지 확인
    var hasCurrentTrack: Bool {
        return currentTrack != nil
    }
    
    /// 다음 트랙이 있는지 확인
    var hasNextTrack: Bool {
        if repeatMode == .all || repeatMode == .one {
            return true
        }
        return currentTrackIndex < tracks.count - 1
    }
    
    /// 이전 트랙이 있는지 확인
    var hasPreviousTrack: Bool {
        return currentTrackIndex > 0 || currentTime > 3.0
    }
    
    // MARK: - Private Methods
    
    /// 트랙 시간 초기화
    private func resetTrackTime() {
        currentTime = 0
        duration = currentTrack?.duration ?? 0
    }
    
    /// 트랙 셔플
    private func shuffleTracks() {
        guard tracks.count > 1 else { return }
        
        let currentTrack = self.currentTrack
        
        // 셔플된 인덱스 배열 생성
        shuffledIndices = Array(0..<tracks.count).shuffled()
        
        // 현재 재생 중인 트랙을 첫 번째로 이동
        if let currentTrack = currentTrack,
           let originalIndex = originalTrackOrder.firstIndex(of: currentTrack),
           let shuffledPosition = shuffledIndices.firstIndex(of: originalIndex) {
            shuffledIndices.swapAt(0, shuffledPosition)
        }
        
        // 셔플된 순서로 트랙 배열 재구성
        tracks = shuffledIndices.map { originalTrackOrder[$0] }
        currentTrackIndex = 0
        self.currentTrack = tracks[0]
    }
    
    /// 원래 순서로 복원
    private func restoreOriginalOrder() {
        let currentTrack = self.currentTrack
        tracks = originalTrackOrder
        
        // 현재 트랙의 원래 인덱스 찾기
        if let currentTrack = currentTrack,
           let originalIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = originalIndex
        }
    }
}

// MARK: - RepeatMode 열거형
enum RepeatMode: CaseIterable {
    case none   // 반복 없음
    case all    // 전체 반복
    case one    // 한 곡 반복
    
    var icon: String {
        switch self {
        case .none:
            return "repeat"
        case .all:
            return "repeat.circle.fill"
        case .one:
            return "repeat.1.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "반복 없음"
        case .all:
            return "전체 반복"
        case .one:
            return "한 곡 반복"
        }
    }
}
