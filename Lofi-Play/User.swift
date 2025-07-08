//
//  User.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation

// MARK: - User 데이터 모델
struct User: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    var savedAlbums: [String] // 저장된 앨범 ID 배열
    
    // 기본 초기화
    init(uid: String, email: String? = nil, displayName: String? = nil, savedAlbums: [String] = []) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.savedAlbums = savedAlbums
    }
    
    // Firestore 딕셔너리로부터 초기화
    init?(dictionary: [String: Any], uid: String) {
        self.uid = uid
        self.email = dictionary["email"] as? String
        self.displayName = dictionary["displayName"] as? String
        self.savedAlbums = dictionary["savedAlbums"] as? [String] ?? []
    }
    
    // Firestore에 저장하기 위한 딕셔너리 변환
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "uid": uid,
            "savedAlbums": savedAlbums
        ]
        
        if let email = email {
            data["email"] = email
        }
        
        if let displayName = displayName {
            data["displayName"] = displayName
        }
        
        return data
    }
    
    // 앨범을 저장 목록에 추가
    mutating func addSavedAlbum(_ albumId: String) {
        if !savedAlbums.contains(albumId) {
            savedAlbums.append(albumId)
        }
    }
    
    // 저장 목록에서 앨범 제거
    mutating func removeSavedAlbum(_ albumId: String) {
        savedAlbums.removeAll { $0 == albumId }
    }
    
    // 앨범이 저장되어 있는지 확인
    func hasAlbumSaved(_ albumId: String) -> Bool {
        return savedAlbums.contains(albumId)
    }
}

// MARK: - User 확장 (Hashable, Equatable)
extension User: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uid == rhs.uid
    }
}
