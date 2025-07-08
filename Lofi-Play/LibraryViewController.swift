//
//  LibraryViewController.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/19/25.
//

import UIKit
import FirebaseAuth

class LibraryViewController: UIViewController {
    
    // MARK: - Properties
    private var savedAlbums: [Album] = []
    private var albumViews: [DraggableAlbumView] = []
    private var stackCenter: CGPoint = CGPoint.zero
    
    // 현재 사용자 ID (하드코딩)
    private var currentUserID: String? {
        return "4313788658"
    }
    
    // MARK: - 생명주기
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedAlbums()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 화면 중앙 하단 위치 설정
        stackCenter = CGPoint(x: view.bounds.midX, y: view.bounds.height - 150)
        
        // 이미 앨범 뷰들이 생성되어 있다면 위치 재조정
        if !albumViews.isEmpty {
            repositionAlbumViews()
        }
    }
    
    // 뷰가 다시 나타날 때마다 앨범 데이터 갱신
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSavedAlbums()
    }
    
    // MARK: - UI 설정
    private func setupUI() {
        view.backgroundColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0) // #F8F4F1
        title = "My Albums"
        
        // 네비게이션 바 스타일
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.black
        ]
        navigationController?.navigationBar.barTintColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0)
        
        // 디버깅을 위한 새로고침 버튼 추가
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshAlbums)
        )
    }
    
    @objc private func refreshAlbums() {
        print("Manual refresh triggered")
        loadSavedAlbums()
    }
    
    // MARK: - 저장된 앨범 불러오기
    private func loadSavedAlbums() {
        guard let userID = currentUserID else {
            print("❌ User not logged in")
            showEmptyState(message: "로그인이 필요합니다")
            return
        }
        
        print("🔍 Loading saved albums for user: \(userID)")
        
        // 로딩 인디케이터 표시 (옵션)
        showLoadingState()
        
        FirebaseManager.shared.getUserSavedAlbums(forUserID: userID) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingState()
                
                switch result {
                case .success(let albums):
                    print("✅ Successfully loaded \(albums.count) albums")
                    for (index, album) in albums.enumerated() {
                        print("Album \(index + 1): \(album.title) by \(album.artist)")
                    }
                    
                    self?.savedAlbums = albums
                    self?.setupAlbumViews()
                    
                    if albums.isEmpty {
                        self?.showEmptyState(message: "저장된 앨범이 없습니다\n\n음악을 검색해서 앨범을 추가해보세요!")
                    } else {
                        self?.hideEmptyState()
                    }
                    
                case .failure(let error):
                    print("❌ Load albums error: \(error)")
                    print("Error details: \(error.localizedDescription)")
                    self?.showEmptyState(message: "앨범을 불러오는데 실패했습니다\n\n다시 시도해주세요")
                    self?.showErrorAlert(message: "앨범을 불러오는데 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 앨범 뷰 설정
    private func setupAlbumViews() {
        print("🎨 Setting up album views for \(savedAlbums.count) albums")
        
        // 기존 앨범 뷰들 제거
        albumViews.forEach { $0.removeFromSuperview() }
        albumViews.removeAll()
        
        // stackCenter가 올바르게 설정되었는지 확인
        if stackCenter == CGPoint.zero {
            stackCenter = CGPoint(x: view.bounds.midX, y: view.bounds.height - 150)
        }
        
        print("Stack center position: \(stackCenter)")
        
        // 새로운 앨범 뷰들 생성
        for (index, album) in savedAlbums.enumerated() {
            print("Creating view for album \(index + 1): \(album.title)")
            
            let albumView = DraggableAlbumView(album: album)
            albumView.delegate = self
            view.addSubview(albumView)
            albumViews.append(albumView)
            
            // 초기 위치를 스택 중앙에 설정 (약간씩 오프셋)
            let offsetX = CGFloat(index * 2) // 카드가 살짝 어긋나게
            let offsetY = CGFloat(index * -3) // 카드가 위로 살짝씩 쌓이게
            
            let initialPosition = CGPoint(
                x: stackCenter.x + offsetX,
                y: stackCenter.y + offsetY
            )
            
            albumView.center = initialPosition
            print("Album view \(index + 1) positioned at: \(initialPosition)")
            
            // 회전 효과 (더 자연스러운 카드 쌓임 효과)
            let rotation = CGFloat.random(in: -0.1...0.1)
            albumView.transform = CGAffineTransform(rotationAngle: rotation)
            
            // 애니메이션으로 나타나게 하기
            albumView.alpha = 0
            albumView.transform = albumView.transform.scaledBy(x: 0.8, y: 0.8)
            
            UIView.animate(withDuration: 0.5, delay: Double(index) * 0.1, options: .curveEaseOut) {
                albumView.alpha = 1
                albumView.transform = CGAffineTransform(rotationAngle: rotation)
            }
        }
        
        // 마지막 앨범이 가장 위에 오도록 z-order 조정
        for (index, albumView) in albumViews.enumerated().reversed() {
            view.bringSubviewToFront(albumView)
        }
        
        print("✅ Finished setting up \(albumViews.count) album views")
    }
    
    // 앨범 뷰들의 위치를 재조정 (화면 회전 등에 대응)
    private func repositionAlbumViews() {
        for (index, albumView) in albumViews.enumerated() {
            
            // ⭐️ 이미 유저가 움직인 경우는 무시 ⭐️
            // 만약 albumView.layer.presentation() == nil 이고, center가 기본 stackCenter랑 다르면 유저가 드래그한 것
            // 그냥 현재 위치 유지

            let currentPos = albumView.center
            let defaultPos = CGPoint(
                x: self.stackCenter.x + CGFloat(index * 2),
                y: self.stackCenter.y + CGFloat(index * -3)
            )
            
            // 1. 현재 위치랑 defaultPos 비교해서 "이미 드래그됨" 여부 판단
            let distance = hypot(currentPos.x - defaultPos.x, currentPos.y - defaultPos.y)
            
            if distance < 10 {
                // 거의 원래 자리면 reposition 해줌 (예: 화면 회전 시)
                UIView.animate(withDuration: 0.3) {
                    albumView.center = defaultPos
                }
            } else {
                // 이미 사용자가 움직였으면 그대로 둠 (안 건드림)
                print("🚫 Skipping reposition for album \(index + 1): \(albumView.album.title), user-moved")
            }
        }
    }
    
    // MARK: - Loading State
    private func showLoadingState() {
        let loadingView = UIView()
        loadingView.backgroundColor = view.backgroundColor
        loadingView.tag = 998
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .gray
        activityIndicator.startAnimating()
        
        let loadingLabel = UILabel()
        loadingLabel.text = "앨범을 불러오는 중..."
        loadingLabel.textColor = .gray
        loadingLabel.font = UIFont.systemFont(ofSize: 16)
        loadingLabel.textAlignment = .center
        
        view.addSubview(loadingView)
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(loadingLabel)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),
            
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor)
        ])
    }
    
    private func hideLoadingState() {
        view.subviews.forEach { subview in
            if subview.tag == 998 {
                subview.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Empty State 처리
    private func showEmptyState(message: String) {
        hideEmptyState() // 기존 empty state 제거
        
        let emptyLabel = UILabel()
        emptyLabel.text = message
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .gray
        emptyLabel.numberOfLines = 0
        emptyLabel.font = UIFont.systemFont(ofSize: 16)
        emptyLabel.tag = 999
        
        view.addSubview(emptyLabel)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func hideEmptyState() {
        view.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Error Alert
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        // 다시 시도 버튼 추가
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { _ in
            self.loadSavedAlbums()
        })
        
        present(alert, animated: true)
    }
}

// MARK: - DraggableAlbumViewDelegate
extension LibraryViewController: DraggableAlbumViewDelegate {
    func albumViewDidStartDragging(_ albumView: DraggableAlbumView) {
        // 드래그 시작 시 해당 뷰를 최상단으로
        view.bringSubviewToFront(albumView)
        
        // 현재 회전 각도를 유지하면서 살짝 확대 효과
        let currentRotation = atan2(albumView.transform.b, albumView.transform.a)
        
        UIView.animate(withDuration: 0.2) {
            albumView.transform = CGAffineTransform(rotationAngle: currentRotation).scaledBy(x: 1.1, y: 1.1)
        }
    }
    
    func albumViewDidEndDragging(_ albumView: DraggableAlbumView) {
        // 드래그 종료 시 원래 크기로 (회전 각도는 유지)
        let currentRotation = atan2(albumView.transform.b, albumView.transform.a)
        
        UIView.animate(withDuration: 0.2) {
            albumView.transform = CGAffineTransform(rotationAngle: currentRotation)
        }
    }
    
    func albumViewWasTapped(_ albumView: DraggableAlbumView) {
        print("Album tapped: \(albumView.album.title)")
        // 앨범 상세 페이지로 이동 (배경 앨범 정보와 함께)
        performSegue(withIdentifier: "LibraryToAlbumDetail", sender: albumView.album)
    }
}

// MARK: - Navigation
extension LibraryViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "LibraryToAlbumDetail",
           let albumDetailVC = segue.destination as? AlbumDetailViewController,
           let album = sender as? Album {
            albumDetailVC.album = album
            // 현재 배치된 모든 앨범 뷰들을 배경으로 전달
            // albumDetailVC.backgroundAlbumViews = albumViews
        }
    }
}

// MARK: - 드래그 가능한 앨범 뷰 델리게이트
protocol DraggableAlbumViewDelegate: AnyObject {
    func albumViewDidStartDragging(_ albumView: DraggableAlbumView)
    func albumViewDidEndDragging(_ albumView: DraggableAlbumView)
    func albumViewWasTapped(_ albumView: DraggableAlbumView)
}

// MARK: - 드래그 가능한 앨범 뷰
class DraggableAlbumView: UIView {
    
    // MARK: - Properties
    weak var delegate: DraggableAlbumViewDelegate?
    let album: Album
    
    private let albumImageView = UIImageView()
    
    private var initialTouchPoint: CGPoint = CGPoint.zero
    private var initialCenter: CGPoint = CGPoint.zero
    
    // MARK: - Initialization
    init(album: Album) {
        self.album = album
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: 180)) // 정사각형으로 변경
        setupUI()
        configure()
        setupGestures()
        
        print("🎵 Created DraggableAlbumView for: \(album.title)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 앨범 이미지 설정
        albumImageView.contentMode = .scaleAspectFill
        albumImageView.clipsToBounds = true
        albumImageView.backgroundColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0) // #F8F4F1
        
        // 그림자 효과
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 8
        
        addSubview(albumImageView)
        albumImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 오토레이아웃 설정 - 앨범 이미지가 전체 뷰를 채우도록
        NSLayoutConstraint.activate([
            albumImageView.topAnchor.constraint(equalTo: topAnchor),
            albumImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            albumImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            albumImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func configure() {
        print("🖼️ Loading image for album: \(album.title)")
        print("Image URL: \(album.coverImageURL)")
        
        // 이미지 로드
        loadImage(from: album.coverImageURL)
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            albumImageView.image = UIImage(named: "default_album_cover")
            return
        }
        
        // ImageCacheManager가 없는 경우를 대비한 기본 이미지 로딩
        if let imageCacheManager = NSClassFromString("ImageCacheManager") {
            ImageCacheManager.shared.loadImage(from: url) { [weak self] image in
                DispatchQueue.main.async {
                    self?.albumImageView.image = image ?? UIImage(named: "default_album_cover")
                    if image != nil {
                        print("✅ Image loaded successfully for: \(self?.album.title ?? "")")
                    } else {
                        print("⚠️ Failed to load image for: \(self?.album.title ?? "")")
                    }
                }
            }
        } else {
            // ImageCacheManager가 없는 경우 URLSession 사용
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let data = data, let image = UIImage(data: data) {
                        self?.albumImageView.image = image
                        print("✅ Image loaded via URLSession for: \(self?.album.title ?? "")")
                    } else {
                        print("❌ Failed to load image via URLSession: \(error?.localizedDescription ?? "Unknown error")")
                        self?.albumImageView.image = UIImage(named: "default_album_cover")
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Gesture Setup
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        
        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
        
        isUserInteractionEnabled = true
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 현재 뷰의 중심점을 기준으로 터치 시작점 저장
            initialTouchPoint = gesture.location(in: self)
            initialCenter = center
            delegate?.albumViewDidStartDragging(self)
            print("🎯 Drag began at: \(initialTouchPoint), center: \(initialCenter)")
            
        case .changed:
            // 부모 뷰 기준으로 현재 터치 위치 계산
            let currentTouchPoint = gesture.location(in: superview)
            
            // 새로운 중심점 계산 (초기 터치점과의 차이를 고려)
            let newCenter = CGPoint(
                x: currentTouchPoint.x - initialTouchPoint.x + (bounds.width / 2),
                y: currentTouchPoint.y - initialTouchPoint.y + (bounds.height / 2)
            )
            
            center = newCenter
            
        case .ended, .cancelled:
            delegate?.albumViewDidEndDragging(self)
            print("🎯 Drag ended at: \(center)")
            
            // 손 떼면 그 자리에 멈추게 새 기준 위치 저장
            initialCenter = center
            
        default:
            break
        }
    }

    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
       print("Album view tapped: \(album.title)")
       
       // 현재 회전 각도 유지하면서 탭 애니메이션
       let currentRotation = atan2(transform.b, transform.a)
       
       UIView.animate(withDuration: 0.1, animations: {
           self.transform = CGAffineTransform(rotationAngle: currentRotation).scaledBy(x: 1.1, y: 1.1)
       }) { _ in
           UIView.animate(withDuration: 0.1, animations: {
               self.transform = CGAffineTransform(rotationAngle: currentRotation)
           }) { _ in
               self.delegate?.albumViewWasTapped(self)
           }
       }
    }
}
