import Foundation

// MARK: - Album 데이터 모델
struct Album: Codable {
    let id: String
    let title: String
    let artist: String
    let coverImageURL: String
    let tracks: [Track]
    
    // 검색 최적화를 위한 소문자 필드들
    let titleLowercase: String
    let artistLowercase: String
    
    // Firestore 문서 ID를 위한 초기화
    init(id: String, title: String, artist: String, coverImageURL: String, tracks: [Track] = []) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverImageURL = coverImageURL
        self.tracks = tracks
        
        // 검색 최적화를 위한 소문자 버전 자동 생성
        self.titleLowercase = title.lowercased()
        self.artistLowercase = artist.lowercased()
    }
    
    // Firestore 딕셔너리로부터 초기화
    init?(dictionary: [String: Any], id: String) {
        guard let title = dictionary["title"] as? String,
              let artist = dictionary["artist"] as? String,
              let coverImageURL = dictionary["coverImageURL"] as? String else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.artist = artist
        self.coverImageURL = coverImageURL
        
        // tracks 배열 파싱
        if let tracksData = dictionary["tracks"] as? [[String: Any]] {
            self.tracks = tracksData.compactMap { trackDict in
                Track(dictionary: trackDict)
            }
        } else {
            self.tracks = []
        }
        
        // 소문자 필드들 - 기존 데이터와의 호환성을 위해 있으면 사용, 없으면 생성
        self.titleLowercase = dictionary["titleLowercase"] as? String ?? title.lowercased()
        self.artistLowercase = dictionary["artistLowercase"] as? String ?? artist.lowercased()
    }
    
    // Codable을 위한 커스텀 초기화 (Firestore에서 자동 디코딩할 때)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        coverImageURL = try container.decode(String.self, forKey: .coverImageURL)
        tracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        
        // 소문자 필드들 - 없으면 자동 생성
        titleLowercase = try container.decodeIfPresent(String.self, forKey: .titleLowercase) ?? title.lowercased()
        artistLowercase = try container.decodeIfPresent(String.self, forKey: .artistLowercase) ?? artist.lowercased()
    }
    
    // Codable을 위한 커스텀 인코딩
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encode(coverImageURL, forKey: .coverImageURL)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(titleLowercase, forKey: .titleLowercase)
        try container.encode(artistLowercase, forKey: .artistLowercase)
    }
    
    // CodingKeys 정의
    enum CodingKeys: String, CodingKey {
        case id, title, artist, coverImageURL, tracks, titleLowercase, artistLowercase
    }
    
    // Firestore에 저장하기 위한 딕셔너리 변환
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "artist": artist,
            "coverImageURL": coverImageURL,
            "tracks": tracks.map { $0.toDictionary() },
            "titleLowercase": titleLowercase,
            "artistLowercase": artistLowercase
        ]
    }
}

// MARK: - Album 확장 (Hashable, Equatable)
extension Album: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.id == rhs.id
    }
}
