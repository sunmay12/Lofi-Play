//
//  UserManager.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation
import FirebaseFirestore

class UserManager {
    static let shared = UserManager()
    
    private let userIDKey = "kakao_user_id"
    private let db = Firestore.firestore()
    
    private init() {}
    
    // 카카오 로그인 후 사용자 ID 저장
    func setKakaoUserID(_ userID: String) {
        UserDefaults.standard.set(userID, forKey: userIDKey)
    }
    
    // 현재 로그인된 사용자 ID 가져오기
    var currentUserID: String? {
        return UserDefaults.standard.string(forKey: userIDKey)
    }
    
    // 로그인 상태 확인
    var isLoggedIn: Bool {
        return currentUserID != nil
    }
    
    // 로그아웃 (사용자 ID 삭제)
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }
    
    // Firebase에 사용자 생성 (처음 로그인하는 경우에만)
    func createUserIfNeeded(userID: String, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userID)
        
        // 먼저 해당 사용자가 이미 존재하는지 확인
        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error checking user existence: \(error)")
                completion(false)
                return
            }
            
            // 사용자가 이미 존재하는 경우
            if let document = document, document.exists {
                print("User already exists")
                completion(true)
                return
            }
            
            // 사용자가 존재하지 않는 경우, 새로 생성
            let userData: [String: Any] = [
                "userID": userID,
                "createdAt": Timestamp(date: Date()),
                "lastLoginAt": Timestamp(date: Date())
            ]
            
            userRef.setData(userData) { error in
                if let error = error {
                    print("Error creating user: \(error)")
                    completion(false)
                } else {
                    print("User created successfully")
                    completion(true)
                }
            }
        }
    }
}
