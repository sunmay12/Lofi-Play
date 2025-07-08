//
//  Track.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation

// MARK: - Track 데이터 모델
struct Track: Codable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let audioURL: String
    
    // 기본 초기화
    init(id: String, title: String, artist: String, duration: TimeInterval, audioURL: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.audioURL = audioURL
    }
    
    // Firestore 딕셔너리로부터 초기화
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let artist = dictionary["artist"] as? String,
              let duration = dictionary["duration"] as? TimeInterval,
              let audioURL = dictionary["audioURL"] as? String else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.audioURL = audioURL
    }
    
    // Firestore에 저장하기 위한 딕셔너리 변환
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "artist": artist,
            "duration": duration,
            "audioURL": audioURL
        ]
    }
    
    // 재생 시간을 포맷된 문자열로 변환
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Track 확장 (Hashable, Equatable)
extension Track: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
}
