//
//  NetworkManager.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import Foundation
import UIKit

// MARK: - Network Error Types
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case downloadFailed
    case networkUnavailable
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "데이터를 받을 수 없습니다."
        case .decodingError:
            return "데이터 처리 중 오류가 발생했습니다."
        case .downloadFailed:
            return "다운로드에 실패했습니다."
        case .networkUnavailable:
            return "네트워크 연결을 확인해주세요."
        }
    }
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let audioCache = NSCache<NSString, NSData>()
    private let imageCache = NSCache<NSString, UIImage>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        
        // 캐시 메모리 설정
        audioCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50MB
    }
    
    // MARK: - Audio Download Methods
    
    /// 오디오 파일을 다운로드합니다
    func downloadAudio(from urlString: String, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        // 캐시 확인
        let cacheKey = NSString(string: urlString)
        if let cachedData = audioCache.object(forKey: cacheKey) {
            completion(.success(cachedData as Data))
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Audio download error: \(error.localizedDescription)")
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            // 캐시에 저장
            let nsData = NSData(data: data)
            self?.audioCache.setObject(nsData, forKey: cacheKey, cost: data.count)
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    /// 오디오 파일을 비동기로 다운로드합니다 (async/await)
    @available(iOS 13.0, *)
    func downloadAudio(from urlString: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            downloadAudio(from: urlString) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Image Download Methods
    
    /// 이미지를 다운로드합니다
    func downloadImage(from urlString: String, completion: @escaping (Result<UIImage, NetworkError>) -> Void) {
        // 캐시 확인
        let cacheKey = NSString(string: urlString)
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(.success(cachedImage))
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Image download error: \(error.localizedDescription)")
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let data = data,
                  let image = UIImage(data: data) else {
                completion(.failure(.noData))
                return
            }
            
            // 캐시에 저장
            let cost = data.count
            self?.imageCache.setObject(image, forKey: cacheKey, cost: cost)
            
            completion(.success(image))
        }
        
        task.resume()
    }
    
    /// 이미지를 비동기로 다운로드합니다 (async/await)
    @available(iOS 13.0, *)
    func downloadImage(from urlString: String) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            downloadImage(from: urlString) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Generic Network Request Methods
    
    /// JSON 데이터를 GET 요청으로 받아옵니다
    func fetchData<T: Codable>(from urlString: String,
                              type: T.Type,
                              completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Fetch data error: \(error.localizedDescription)")
                completion(.failure(.networkUnavailable))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode(type, from: data)
                completion(.success(decodedData))
            } catch {
                print("JSON decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    /// POST 요청을 보냅니다
    func postData<T: Codable>(to urlString: String,
                             body: [String: Any],
                             responseType: T.Type,
                             completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("POST request error: \(error.localizedDescription)")
                completion(.failure(.networkUnavailable))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(responseType, from: data)
                completion(.success(decodedResponse))
            } catch {
                print("JSON decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Cache Management
    
    /// 오디오 캐시를 정리합니다
    func clearAudioCache() {
        audioCache.removeAllObjects()
    }
    
    /// 이미지 캐시를 정리합니다
    func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    /// 모든 캐시를 정리합니다
    func clearAllCache() {
        clearAudioCache()
        clearImageCache()
    }
    
    /// 캐시 사용량을 확인합니다
    func getCacheInfo() -> (audioCount: Int, imageCount: Int) {
        return (audioCache.totalCostLimit, imageCache.totalCostLimit)
    }
    
    // MARK: - Network Status Check
    
    /// 네트워크 연결 상태를 확인합니다
    func checkNetworkStatus(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://www.google.com") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let task = session.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Download Progress Tracking
    
    /// 진행상황을 추적하면서 큰 파일을 다운로드합니다
    func downloadLargeFile(from urlString: String,
                          progressHandler: @escaping (Double) -> Void,
                          completion: @escaping (Result<Data, NetworkError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = session.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("Large file download error: \(error.localizedDescription)")
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(.downloadFailed))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let data = try Data(contentsOf: tempURL)
                completion(.success(data))
            } catch {
                completion(.failure(.noData))
            }
        }
        
        // 진행상황 관찰
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(progress.fractionCompleted)
            }
        }
        
        task.resume()
    }
}

// MARK: - UIImageView Extension for Async Image Loading
extension UIImageView {
    func loadImage(from urlString: String, placeholder: UIImage? = nil) {
        // 플레이스홀더 설정
        if let placeholder = placeholder {
            self.image = placeholder
        }
        
        NetworkManager.shared.downloadImage(from: urlString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self?.image = image
                case .failure(let error):
                    print("Failed to load image: \(error.localizedDescription)")
                    // 기본 이미지 설정 (선택사항)
                    self?.image = UIImage(systemName: "music.note")
                }
            }
        }
    }
}
