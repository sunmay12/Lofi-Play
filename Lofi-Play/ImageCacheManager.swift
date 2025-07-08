//
//  ImageCacheManager.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/20/25.
//

import UIKit
import Foundation

// MARK: - Image Cache Manager
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // MARK: - Properties
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var downloadTasks: [URL: URLSessionDataTask] = [:]
    private let diskCacheURL: URL
    
    // Cache configuration
    private let maxMemoryCost = 50 * 1024 * 1024 // 50MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Initialization
    private init() {
        // URLSession 설정
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        // NSCache 설정
        cache.totalCostLimit = maxMemoryCost
        cache.name = "ImageCache"
        
        // 디스크 캐시 디렉토리 설정
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory,
                                                    in: .userDomainMask).first!
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache")
        createCacheDirectoryIfNeeded()
        
        // 메모리 부족 시 캐시 정리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 앱이 백그라운드로 갈 때 오래된 캐시 정리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanExpiredDiskCache),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// URL에서 이미지를 로드합니다 (메모리 캐시 -> 디스크 캐시 -> 네트워크 순서)
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: url.absoluteString)
        
        // 1. 메모리 캐시 확인
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // 2. 디스크 캐시 확인
        if let diskImage = loadImageFromDisk(url: url) {
            // 메모리 캐시에도 저장
            let cost = Int(diskImage.size.width * diskImage.size.height * 4) // RGBA
            cache.setObject(diskImage, forKey: cacheKey, cost: cost)
            completion(diskImage)
            return
        }
        
        // 3. 이미 다운로드 중인지 확인
        if downloadTasks[url] != nil {
            // 이미 다운로드 중이면 대기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadImage(from: url, completion: completion)
            }
            return
        }
        
        // 4. 네트워크에서 다운로드
        downloadImage(from: url, completion: completion)
    }
    
    /// 문자열 URL에서 이미지를 로드합니다
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        loadImage(from: url, completion: completion)
    }
    
    /// 이미지를 사전에 캐시합니다 (prefetch)
    func prefetchImages(urls: [URL]) {
        for url in urls {
            let cacheKey = NSString(string: url.absoluteString)
            
            // 이미 캐시되어 있거나 다운로드 중이면 스킵
            if cache.object(forKey: cacheKey) != nil || downloadTasks[url] != nil {
                continue
            }
            
            // 디스크 캐시에 있는지 확인
            if loadImageFromDisk(url: url) != nil {
                continue
            }
            
            // 네트워크에서 다운로드 (결과는 무시)
            downloadImage(from: url) { _ in }
        }
    }
    
    // MARK: - Cache Management
    
    /// 메모리 캐시를 정리합니다
    @objc private func clearMemoryCache() {
        cache.removeAllObjects()
    }
    
    /// 특정 이미지를 캐시에서 제거합니다
    func removeImage(for url: URL) {
        let cacheKey = NSString(string: url.absoluteString)
        cache.removeObject(forKey: cacheKey)
        removeImageFromDisk(url: url)
    }
    
    /// 모든 캐시를 정리합니다
    func clearAllCache() {
        cache.removeAllObjects()
        clearDiskCache()
    }
    
    /// 캐시 사용량 정보를 반환합니다
    func getCacheInfo() -> (memoryUsage: Int, diskUsage: Int64) {
        let memoryUsage = cache.totalCostLimit
        let diskUsage = getDiskCacheSize()
        return (memoryUsage, diskUsage)
    }
    
    // MARK: - Private Methods
    
    /// 네트워크에서 이미지를 다운로드합니다
    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            defer {
                self?.downloadTasks.removeValue(forKey: url)
            }
            
            if let error = error {
                print("Image download error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Invalid HTTP response for image download")
                completion(nil)
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("Invalid image data")
                completion(nil)
                return
            }
            
            // 캐시에 저장
            self?.cacheImage(image, for: url, data: data)
            completion(image)
        }
        
        downloadTasks[url] = task
        task.resume()
    }
    
    /// 이미지를 메모리와 디스크 캐시에 저장합니다
    private func cacheImage(_ image: UIImage, for url: URL, data: Data) {
        let cacheKey = NSString(string: url.absoluteString)
        
        // 메모리 캐시에 저장
        let cost = Int(image.size.width * image.size.height * 4) // RGBA
        cache.setObject(image, forKey: cacheKey, cost: cost)
        
        // 디스크 캐시에 저장
        saveImageToDisk(data: data, url: url)
    }
    
    // MARK: - Disk Cache Methods
    
    /// 캐시 디렉토리를 생성합니다
    private func createCacheDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: diskCacheURL.path) {
            try? FileManager.default.createDirectory(at: diskCacheURL,
                                                   withIntermediateDirectories: true)
        }
    }
    
    /// 디스크에서 이미지를 로드합니다
    private func loadImageFromDisk(url: URL) -> UIImage? {
        let filename = url.absoluteString.md5
        let fileURL = diskCacheURL.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 파일이 너무 오래되었는지 확인
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let creationDate = attributes[.creationDate] as? Date {
            if Date().timeIntervalSince(creationDate) > maxCacheAge {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
        }
        
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    /// 디스크에 이미지를 저장합니다
    private func saveImageToDisk(data: Data, url: URL) {
        let filename = url.absoluteString.md5
        let fileURL = diskCacheURL.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
    }
    
    /// 디스크에서 특정 이미지를 제거합니다
    private func removeImageFromDisk(url: URL) {
        let filename = url.absoluteString.md5
        let fileURL = diskCacheURL.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// 디스크 캐시를 모두 정리합니다
    private func clearDiskCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL,
                                                                      includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    /// 만료된 디스크 캐시를 정리합니다
    @objc private func cleanExpiredDiskCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }
        
        let now = Date()
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
               let creationDate = attributes.creationDate {
                if now.timeIntervalSince(creationDate) > maxCacheAge {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
    
    /// 디스크 캐시 사용량을 계산합니다
    private func getDiskCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        return files.reduce(0) { totalSize, file in
            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return totalSize + Int64(fileSize)
        }
    }
}

// MARK: - String Extension for MD5
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes in
            return bytes.bindMemory(to: UInt8.self)
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = CC_MD5(hash.baseAddress, CC_LONG(data.count), &digest)
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// CommonCrypto import 필요
import CommonCrypto

// MARK: - UIImageView Extension
extension UIImageView {
    /// ImageCacheManager를 사용하여 이미지를 로드합니다
    func loadCachedImage(from urlString: String, placeholder: UIImage? = nil) {
        // 플레이스홀더 설정
        if let placeholder = placeholder {
            self.image = placeholder
        } else {
            self.image = UIImage(named: "default_album_cover")
        }
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        ImageCacheManager.shared.loadImage(from: url) { [weak self] image in
            DispatchQueue.main.async {
                self?.image = image ?? UIImage(named: "default_album_cover")
            }
        }
    }
    
    /// 이미지 로딩을 취소합니다 (메모리 최적화)
    func cancelImageLoading() {
        // 현재 로딩 중인 작업이 있다면 취소
        // 실제 구현에서는 더 정교한 취소 로직이 필요할 수 있습니다
        self.image = UIImage(named: "default_album_cover")
    }
}
