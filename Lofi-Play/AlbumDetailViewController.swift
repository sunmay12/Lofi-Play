//
//  AlbumDetailViewController.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/19/25.
//

import UIKit

// 앨범 상세 화면을 오버레이 스타일로 보여주는 ViewController
class AlbumDetailViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var trackListTableView: UITableView!
    
    // 이전 화면에서 전달받는 앨범 데이터 (안전한 옵셔널로 변경)
    var album: Album? {
        didSet {
            print("🔄 Album didSet called: \(album?.title ?? "nil")")
            print("🔄 isViewLoaded: \(isViewLoaded)")
            
            // album이 설정될 때마다 UI 업데이트
            if isViewLoaded {
                configureWithAlbum()
            }
        }
    }
    
    // 배경에 표시할 앨범 뷰들 (LibraryViewController에서 전달받음)
    var backgroundAlbumViews: [DraggableAlbumView] = []
    
    // MARK: - 생명 주기
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("✅ AlbumDetailViewController viewDidLoad")
        print("✅ Album at viewDidLoad: \(album?.title ?? "nil")")
        
        setupUI()
        setupTableView()
        
        // album이 이미 설정되어 있다면 UI 구성
        if album != nil {
            print("🔄 Calling configureWithAlbum from viewDidLoad")
            configureWithAlbum()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // viewDidAppear에서도 album 체크 (데이터가 늦게 설정되는 경우 대비)
        if album != nil {
            print("🔄 Calling configureWithAlbum from viewDidAppear")
            configureWithAlbum()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 네비게이션 바 숨기기
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 애니메이션으로 등장
        animateAppearance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 네비게이션 바 다시 보이기
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - UI 설정
    private func setupUI() {
        // 배경 뷰 색상 설정
        backgroundView.backgroundColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0)
        
        // 배경 앨범들 추가
        setupBackgroundAlbums()
        
        // 컨테이너 뷰 스타일 설정 - 밝은 블러 효과로 변경
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        
        // 추가적인 블러 효과를 위한 배경 설정
        setupBlurBackground()
        
        // 앨범 이미지 설정
        setupAlbumImageView()
        
        // 라벨들 설정
        setupLabels()
        
    }
    
    // 블러 배경 효과 추가 설정
    private func setupBlurBackground() {
        // 기존 블러 효과가 너무 어두우면 추가 블러 레이어 생성
        let additionalBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        additionalBlur.frame = containerView.bounds
        additionalBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        additionalBlur.alpha = 0.7
        containerView.insertSubview(additionalBlur, at: 0)
    }
    
    private func setupBackgroundAlbums() {
        // LibraryViewController에서 전달받은 앨범 뷰들을 배경에 배치
        for albumView in backgroundAlbumViews {
            // 원본 뷰를 복사해서 배경에 추가
            let backgroundAlbumView = DraggableAlbumView(album: albumView.album)
            backgroundAlbumView.center = albumView.center
            backgroundAlbumView.transform = albumView.transform
            backgroundAlbumView.isUserInteractionEnabled = false // 상호작용 비활성화
            backgroundView.addSubview(backgroundAlbumView)
        }
    }
    
    private func setupAlbumImageView() {
        albumImageView.contentMode = .scaleAspectFill
        albumImageView.clipsToBounds = true
        albumImageView.layer.cornerRadius = 16
        albumImageView.backgroundColor = UIColor.systemGray5
        
        // 그림자 효과 - 밝은 배경에 맞게 조정
        albumImageView.layer.shadowColor = UIColor.black.cgColor
        albumImageView.layer.shadowOffset = CGSize(width: 0, height: 3)
        albumImageView.layer.shadowOpacity = 0.3
        albumImageView.layer.shadowRadius = 4
        albumImageView.layer.masksToBounds = false
    }
    
    private func setupLabels() {
        // 앨범 제목 - 어두운 텍스트로 변경
        albumTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        albumTitleLabel.textColor = UIColor.black
        albumTitleLabel.textAlignment = .center
        albumTitleLabel.numberOfLines = 2
        
        // 아티스트 이름 - 회색 텍스트로 변경
        artistLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        artistLabel.textColor = UIColor.darkGray // 기존: UIColor.lightGray에서 UIColor.darkGray로 변경
        artistLabel.textAlignment = .center
        artistLabel.numberOfLines = 1
        
        // 기본값 설정 (앨범 데이터가 없을 때)
        albumTitleLabel.text = "Loading..."
        artistLabel.text = "Loading..."
    }
    
    // 테이블뷰 설정
    private func setupTableView() {
        trackListTableView.delegate = self
        trackListTableView.dataSource = self
        trackListTableView.backgroundColor = UIColor.clear
        trackListTableView.separatorStyle = .none
        trackListTableView.showsVerticalScrollIndicator = false
        
        // 테이블뷰 셀 등록
        trackListTableView.register(TrackTableViewCell.self, forCellReuseIdentifier: "TrackCell")
    }
    
    // MARK: - 앨범 데이터 설정 메소드
    func setAlbum(_ album: Album) {
        print("🔄 Setting album: \(album.title)")
        print("🔄 View loaded: \(isViewLoaded)")
        
        self.album = album
        // didSet이 호출되어 자동으로 configureWithAlbum() 처리됨
    }
    
    // 정적 생성 메소드 (권장)
    static func create(with album: Album, backgroundViews: [DraggableAlbumView] = []) -> AlbumDetailViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "AlbumDetailViewController") as! AlbumDetailViewController
        
        viewController.album = album
        viewController.backgroundAlbumViews = backgroundViews
        
        print("🔄 Created AlbumDetailViewController with album: \(album.title)")
        return viewController
    }
    
    // 앨범 정보로 UI 구성 (통합된 버전)
    private func configureWithAlbum() {
        guard let album = album else {
            print("⚠️ Album data is nil")
            // 로딩 상태 표시 (IBOutlet이 nil일 수 있으므로 안전하게 처리)
            albumTitleLabel?.text = "Loading..."
            artistLabel?.text = "Loading..."
            albumImageView?.image = UIImage(named: "default_album_cover")
            return
        }
        
        print("✅ 앨범 데이터 로드: \(album.title)")
        print("✅ Artist: \(album.artist)")
        print("✅ Cover URL: \(album.coverImageURL)")
        
        // IBOutlet 연결 상태 확인
        print("✅ albumTitleLabel exists: \(albumTitleLabel != nil)")
        print("✅ artistLabel exists: \(artistLabel != nil)")
        print("✅ albumImageView exists: \(albumImageView != nil)")
        
        // 메인 스레드에서 UI 업데이트 보장
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // IBOutlet 연결 확인
            guard let titleLabel = self.albumTitleLabel,
                  let artistLabel = self.artistLabel,
                  let imageView = self.albumImageView else {
                print("❌ IBOutlets are not connected!")
                return
            }
            
            titleLabel.text = album.title
            artistLabel.text = album.artist
            
            print("✅ UI 업데이트 완료: \(album.title)")
            
            self.loadImage(from: album.coverImageURL)
            self.trackListTableView?.reloadData()
        }
    }
    
    // 앨범 커버 이미지 로딩
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            albumImageView.image = UIImage(named: "default_album_cover")
            return
        }
        
        ImageCacheManager.shared.loadImage(from: url) { [weak self] image in
            DispatchQueue.main.async {
                self?.albumImageView.image = image ?? UIImage(named: "default_album_cover")
            }
        }
    }
    
    // MARK: - 애니메이션
    private func animateAppearance() {
        // 초기 상태 설정
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        blurEffectView.alpha = 0
        
        // 애니메이션 실행
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.containerView.alpha = 1
            self.containerView.transform = CGAffineTransform.identity
            self.blurEffectView.alpha = 1
        }
    }
    
    private func animateDisappearance(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.blurEffectView.alpha = 0
        }) { _ in
            completion()
        }
    }
    
    // MARK: - Player 화면으로 이동
    private func navigateToPlayer() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.modalPresentationStyle = .fullScreen
            present(playerVC, animated: true, completion: nil)
        } else {
            print("❌ PlayerViewController를 찾을 수 없습니다")
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension AlbumDetailViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return album?.tracks.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as! TrackTableViewCell
        
        guard let album = album, indexPath.row < album.tracks.count else {
            // 안전장치: 기본 셀 반환
            print("⚠️ Invalid album or track index")
            return cell
        }
        
        let track = album.tracks[indexPath.row]
        cell.configure(with: track, trackNumber: indexPath.row + 1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let album = album, indexPath.row < album.tracks.count else {
            print("⚠️ Invalid album or track index")
            return
        }
        
        print("🎵 트랙 선택됨: \(album.tracks[indexPath.row].title)")
        
        // 셀 선택 애니메이션
        if let cell = tableView.cellForRow(at: indexPath) as? TrackTableViewCell {
            cell.animateSelection()
        }
        
        // PlayerData에 앨범과 트랙 정보 설정
        PlayerData.shared.setAlbumAndTrack(album: album, trackIndex: indexPath.row)
        
        // 약간의 딜레이 후 PlayerViewController로 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.navigateToPlayer()
        }
    }
}

// MARK: - 커스텀 트랙 테이블뷰 셀
class TrackTableViewCell: UITableViewCell {
    
    private let trackNumberLabel = UILabel()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        // 컨테이너 뷰 - 밝은 배경에 맞게 조정
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.1) // 기존: UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 8
        contentView.addSubview(containerView)
        
        // 트랙 번호 - 어두운 텍스트로 변경
        trackNumberLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        trackNumberLabel.textColor = UIColor.darkGray
        trackNumberLabel.textAlignment = .center
        containerView.addSubview(trackNumberLabel)
        
        // 제목 - 어두운 텍스트로 변경
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.black
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        trackNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            trackNumberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            trackNumberLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            trackNumberLabel.widthAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: trackNumberLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
        ])
    }
    
    func configure(with track: Track, trackNumber: Int) {
        trackNumberLabel.text = "\(trackNumber)"
        titleLabel.text = track.title
    }
    
    func animateSelection() {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.backgroundColor = UIColor.black.withAlphaComponent(0.2) // 밝은 배경에 맞게 조정
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.containerView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
                self.transform = CGAffineTransform.identity
            }
        }
    }
}
