//
//  FirebaseManager.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/19/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}

    // MARK: - User Management
    func checkUserExists(userID: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userID).getDocument { document, error in
            completion(document?.exists == true)
        }
    }
    
    func createUser(user: User, completion: @escaping (Bool) -> Void) {
        do {
            try db.collection("users").document(user.uid).setData(from: user) { error in
                completion(error == nil)
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - Firestore Operations
    func searchMusic(query: String, completion: @escaping (Result<[Album], Error>) -> Void) {
        print("FirebaseManager: Starting search for query: '\(query)'")
        
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 먼저 제목으로 검색
        let titleQuery = db.collection("albums")
            .whereField("titleLowercase", isGreaterThanOrEqualTo: lowercaseQuery)
            .whereField("titleLowercase", isLessThan: lowercaseQuery + "\u{f8ff}")
            .limit(to: 20)
        
        titleQuery.getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("FirebaseManager: Title search error: \(error.localizedDescription)")
                // 제목 검색이 실패하면 아티스트로도 검색 시도
                self?.searchByArtist(query: lowercaseQuery, completion: completion)
                return
            }
            
            print("FirebaseManager: Title search completed. Documents count: \(snapshot?.documents.count ?? 0)")
            
            let titleResults = snapshot?.documents.compactMap { document -> Album? in
                do {
                    let album = try document.data(as: Album.self)
                    print("FirebaseManager: Successfully parsed album: \(album.title)")
                    return album
                } catch {
                    print("FirebaseManager: Error parsing album document: \(error)")
                    return nil
                }
            } ?? []
            
            // 아티스트로도 검색해서 결과 합치기
            self?.searchByArtist(query: lowercaseQuery) { artistResult in
                switch artistResult {
                case .success(let artistResults):
                    // 중복 제거하여 결과 합치기
                    var combinedResults = titleResults
                    for artistAlbum in artistResults {
                        if !combinedResults.contains(where: { $0.id == artistAlbum.id }) {
                            combinedResults.append(artistAlbum)
                        }
                    }
                    print("FirebaseManager: Combined search results: \(combinedResults.count) albums")
                    completion(.success(combinedResults))
                    
                case .failure(_):
                    // 아티스트 검색이 실패해도 제목 검색 결과는 반환
                    print("FirebaseManager: Artist search failed, returning title results only")
                    completion(.success(titleResults))
                }
            }
        }
    }
    
    private func searchByArtist(query: String, completion: @escaping (Result<[Album], Error>) -> Void) {
        print("FirebaseManager: Starting artist search for query: '\(query)'")
        
        db.collection("albums")
            .whereField("artistLowercase", isGreaterThanOrEqualTo: query)
            .whereField("artistLowercase", isLessThan: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("FirebaseManager: Artist search error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                print("FirebaseManager: Artist search completed. Documents count: \(snapshot?.documents.count ?? 0)")
                
                let albums = snapshot?.documents.compactMap { document -> Album? in
                    do {
                        let album = try document.data(as: Album.self)
                        print("FirebaseManager: Successfully parsed artist album: \(album.title) by \(album.artist)")
                        return album
                    } catch {
                        print("FirebaseManager: Error parsing artist album document: \(error)")
                        return nil
                    }
                } ?? []
                
                completion(.success(albums))
            }
    }
    
    // 모든 앨범 가져오기 (검색 결과가 없을 때 테스트용)
    func getAllAlbums(completion: @escaping (Result<[Album], Error>) -> Void) {
        print("FirebaseManager: Getting all albums")
        
        db.collection("albums")
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("FirebaseManager: Get all albums error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                print("FirebaseManager: Get all albums completed. Documents count: \(snapshot?.documents.count ?? 0)")
                
                let albums = snapshot?.documents.compactMap { document -> Album? in
                    do {
                        let data = document.data()
                        print("FirebaseManager: Document data: \(data)")
                        let album = try document.data(as: Album.self)
                        return album
                    } catch {
                        print("FirebaseManager: Error parsing album document: \(error)")
                        // 수동으로 파싱 시도
                        return self.parseAlbumManually(from: document.data(), documentId: document.documentID)
                    }
                } ?? []
                
                completion(.success(albums))
            }
    }
    
    // 수동 파싱 메서드 (Codable이 실패할 경우)
    private func parseAlbumManually(from data: [String: Any], documentId: String) -> Album? {
        guard let title = data["title"] as? String,
              let artist = data["artist"] as? String,
              let coverImageURL = data["coverImageURL"] as? String else {
            print("FirebaseManager: Missing required fields in document \(documentId)")
            return nil
        }
        
        // tracks 배열 파싱
        var tracks: [Track] = []
        if let tracksData = data["tracks"] as? [[String: Any]] {
            tracks = tracksData.compactMap { trackDict in
                Track(dictionary: trackDict)
            }
        }
        
        return Album(
            id: data["id"] as? String ?? documentId,
            title: title,
            artist: artist,
            coverImageURL: coverImageURL,
            tracks: tracks
        )
    }
    
    func getAlbums(albumIDs: [String], completion: @escaping (Result<[Album], Error>) -> Void) {
        print("🔍 FirebaseManager: Getting albums for IDs: \(albumIDs)")
        
        guard !albumIDs.isEmpty else {
            print("⚠️ No album IDs provided")
            completion(.success([]))
            return
        }

        let group = DispatchGroup()
        var albums: [Album] = []
        var errors: [Error] = []
        
        for albumID in albumIDs {
            group.enter()
            print("🔍 Fetching album: \(albumID)")
            
            db.collection("albums").document(albumID).getDocument { document, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ Error fetching album \(albumID): \(error.localizedDescription)")
                    errors.append(error)
                    return
                }
                
                guard let document = document else {
                    print("❌ No document returned for album \(albumID)")
                    return
                }
                
                guard document.exists else {
                    print("❌ Album document \(albumID) does not exist")
                    return
                }
                
                print("✅ Album document \(albumID) found, raw data: \(document.data() ?? [:])")
                
                if let album = try? document.data(as: Album.self) {
                    print("✅ Successfully parsed album: \(album.title)")
                    albums.append(album)
                } else {
                    print("❌ Failed to parse album \(albumID), trying manual parsing...")
                    
                    // 수동 파싱 시도
                    if let data = document.data(),
                       let manualAlbum = self.parseAlbumManually(from: data, documentId: albumID) {
                        print("✅ Successfully parsed album manually: \(manualAlbum.title)")
                        albums.append(manualAlbum)
                    } else {
                        print("❌ Manual parsing also failed for album \(albumID)")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("🏁 Finished fetching albums. Success: \(albums.count), Errors: \(errors.count)")
            
            if let firstError = errors.first, albums.isEmpty {
                completion(.failure(firstError))
            } else {
                completion(.success(albums))
            }
        }
    }
    
    // MARK: - Album Library Management
    func saveAlbumToLibrary(album: Album, forUserID userID: String, completion: @escaping (Bool) -> Void) {
        print("FirebaseManager: Saving album to library")
        
        // Album의 toDictionary() 메서드 사용 (모든 필드가 non-optional이므로)
        let albumData = album.toDictionary()
        
        print("Album data: \(albumData)")
        
        db.collection("albums").document(album.id).setData(albumData) { [weak self] error in
            if let error = error {
                print("Error saving album to albums collection: \(error)")
                completion(false)
                return
            }
            
            print("Album successfully saved to albums collection")
            
            // 사용자의 savedAlbums에 앨범 ID 추가
            self?.db.collection("users").document(userID).updateData([
                "savedAlbums": FieldValue.arrayUnion([album.id])
            ]) { error in
                if let error = error {
                    print("Error adding album to user's saved albums: \(error)")
                    completion(false)
                } else {
                    print("Album successfully added to user's saved albums")
                    completion(true)
                }
            }
        }
    }
    
    func removeAlbumFromLibrary(albumId: String, forUserID userID: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userID).updateData([
            "savedAlbums": FieldValue.arrayRemove([albumId])
        ]) { error in
            if let error = error {
                print("Error removing album from library: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func isAlbumSaved(albumId: String, forUserID userID: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error checking saved album: \(error)")
                completion(false)
                return
            }
            
            guard let user = try? document?.data(as: User.self) else {
                completion(false)
                return
            }
            
            completion(user.savedAlbums.contains(albumId))
        }
    }
    
    func getUserSavedAlbums(forUserID userID: String, completion: @escaping (Result<[Album], Error>) -> Void) {
        print("🔍 FirebaseManager: Getting saved albums for user: \(userID)")
        
        db.collection("users").document(userID).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ Error getting user document: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ User document does not exist for userID: \(userID)")
                completion(.success([]))
                return
            }
            
            print("✅ User document found, raw data: \(document.data() ?? [:])")
            
            // 두 가지 방법으로 시도
            // 1. User 모델로 파싱 시도
            if let user = try? document.data(as: User.self) {
                print("✅ Successfully parsed as User model")
                print("📚 User's saved albums: \(user.savedAlbums)")
                
                guard let strongSelf = self else {
                    completion(.success([]))
                    return
                }
                
                if user.savedAlbums.isEmpty {
                    print("⚠️ User has no saved albums")
                    completion(.success([]))
                } else {
                    print("🔍 Getting albums for IDs: \(user.savedAlbums)")
                    strongSelf.getAlbums(albumIDs: user.savedAlbums, completion: completion)
                }
            }
            // 2. 직접 딕셔너리에서 추출
            else if let data = document.data(),
                    let savedAlbumsArray = data["savedAlbums"] as? [String] {
                print("✅ Successfully extracted savedAlbums from raw data")
                print("📚 Saved albums from raw data: \(savedAlbumsArray)")
                
                guard let strongSelf = self else {
                    completion(.success([]))
                    return
                }
                
                if savedAlbumsArray.isEmpty {
                    print("⚠️ savedAlbums array is empty")
                    completion(.success([]))
                } else {
                    print("🔍 Getting albums for IDs: \(savedAlbumsArray)")
                    strongSelf.getAlbums(albumIDs: savedAlbumsArray, completion: completion)
                }
            }
            // 3. 모든 파싱 실패
            else {
                print("❌ Failed to parse user document. Raw data structure:")
                if let data = document.data() {
                    for (key, value) in data {
                        print("  \(key): \(value) (type: \(type(of: value)))")
                    }
                }
                
                // savedAlbums 필드가 다른 형태로 저장되어 있는지 확인
                if let data = document.data() {
                    if let savedAlbums = data["savedAlbums"] {
                        print("❓ savedAlbums exists but type is: \(type(of: savedAlbums))")
                        print("❓ savedAlbums value: \(savedAlbums)")
                    } else {
                        print("❌ savedAlbums field not found in document")
                    }
                }
                
                completion(.success([]))
            }
        }
    }
    
    // MARK: - Storage Operations
    func uploadAudioFile(data: Data, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let audioRef = storage.reference().child("audio/\(fileName)")
        
        audioRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            audioRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                }
            }
        }
    }

    func uploadAlbumCover(data: Data, albumId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let imageRef = storage.reference().child("covers/\(albumId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                }
            }
        }
    }
    
    func getAlbumsByArtist(artist: String, completion: @escaping (Result<[Album], Error>) -> Void) {
        db.collection("albums")
            .whereField("artist", isEqualTo: artist)
            .order(by: "title")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let albums = snapshot?.documents.compactMap { document -> Album? in
                    try? document.data(as: Album.self)
                } ?? []
                
                completion(.success(albums))
            }
    }

    func getPopularAlbums(limit: Int = 20, completion: @escaping (Result<[Album], Error>) -> Void) {
        db.collection("albums")
            .order(by: "playCount", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let albums = snapshot?.documents.compactMap { document -> Album? in
                    try? document.data(as: Album.self)
                } ?? []
                
                completion(.success(albums))
            }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        var chunks: [[Element]] = []
        var index = 0
        while index < self.count {
            let chunk = Array(self[index..<Swift.min(index + size, self.count)])
            chunks.append(chunk)
            index += size
        }
        return chunks
    }
}

