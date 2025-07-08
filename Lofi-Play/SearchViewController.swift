import UIKit

class SearchViewController: UIViewController {
    
    // MARK: - IBOutlets (스토리보드에서 연결)
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // 검색 결과
    private var searchResults: [Album] = []
    private var isSearching = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBasic()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 검색 진행 중이면 취소
        isSearching = false
    }
    
    // MARK: - 기본 설정
    private func setupBasic() {
        title = "Search"
        searchBar.placeholder = "노래 제목이나 가수 이름을 입력하세요"
        searchBar.delegate = self
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    // MARK: - 검색 실행
    private func search(query: String) {
        guard !query.isEmpty else { return }
        
        isSearching = true
        
        FirebaseManager.shared.searchMusic(query: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.isSearching else {
                    print("🔄 Search was cancelled or view controller deallocated")
                    return
                }
                
                self.isSearching = false
                
                switch result {
                case .success(let albums):
                    self.searchResults = albums
                    self.collectionView.reloadData()
                    print("✅ Search completed: \(albums.count) results")
                case .failure(let error):
                    print("❌ 검색 실패: \(error)")
                    self.showAlert(message: "검색에 실패했습니다.")
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        guard isViewLoaded,
              view.window != nil,
              presentedViewController == nil else {
            print("⚠️ Cannot show alert - view not ready or another presentation is active")
            return
        }
        
        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Segue 준비
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SearchToAlbumDetail",
           let destinationVC = segue.destination as? AlbumDetailViewController,
           let album = sender as? Album {
            
            print("✅ Preparing segue with album: \(album.title)")
            destinationVC.setAlbum(album)
        }
    }
}

// MARK: - 검색바 델리게이트
extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.placeholder = ""
        searchBar.showsCancelButton = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.placeholder = "노래 제목이나 가수 이름을 입력하세요..."
        searchBar.showsCancelButton = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty {
            search(query: query)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = ""
        isSearching = false
        searchResults = []
        collectionView.reloadData()
    }
}

// MARK: - 컬렉션뷰 델리게이트
extension SearchViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
        
        guard indexPath.item < searchResults.count else {
            print("⚠️ Invalid index path: \(indexPath.item)")
            return cell
        }
        
        cell.setup(album: searchResults[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 인덱스 유효성 검사
        guard indexPath.item < searchResults.count else {
            print("⚠️ Invalid index path: \(indexPath.item)")
            return
        }
        
        // 셀 선택 해제
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let album = searchResults[indexPath.item]
        print("🔄 Selected album: \(album.title)")
        
        // Segue 실행
        performSegue(withIdentifier: "SearchToAlbumDetail", sender: album)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 4
        let spacing: CGFloat = 4
        let availableWidth = collectionView.frame.width - (padding * 2) - spacing
        let itemWidth = availableWidth / 2
        
        // LP 이미지 + 텍스트 공간을 고려한 높이
        let itemHeight = itemWidth + 100 // LP 크기 + 텍스트 영역
        
        return CGSize(width: max(itemWidth, 290), height: max(itemHeight, 300))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

// MARK: - 앨범 셀
class AlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var albumCoverImageView: UIImageView!
    @IBOutlet weak var lpImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    
    // LP 중앙에 들어갈 원형 이미지뷰 (코드로 생성)
    private let circularAlbumImageView = UIImageView()
    
    // 이미지 로딩 취소를 위한 task 저장
    private var imageLoadTask: URLSessionDataTask?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // 이전 이미지 로딩 취소
        imageLoadTask?.cancel()
        albumCoverImageView.image = nil
        circularAlbumImageView.image = nil
        titleLabel.text = ""
        artistLabel.text = ""
    }
    
    private func setupUI() {
        // LP 이미지뷰 설정 (뒤쪽에 위치)
        lpImageView.image = UIImage(named: "empty_LP")
        lpImageView.contentMode = .scaleAspectFit
        lpImageView.clipsToBounds = true
        
        // 앨범 커버 이미지뷰 설정 (기본 크기/모양)
        albumCoverImageView.layer.cornerRadius = 0
        albumCoverImageView.contentMode = .scaleAspectFill
        albumCoverImageView.clipsToBounds = true
        albumCoverImageView.backgroundColor = UIColor.systemGray5
        
        // 원형 앨범 이미지뷰 설정 (LP 중앙에 위치)
        circularAlbumImageView.contentMode = .scaleAspectFill
        circularAlbumImageView.clipsToBounds = true
        circularAlbumImageView.backgroundColor = nil
        circularAlbumImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 원형 이미지뷰를 LP 이미지뷰에 추가
        lpImageView.addSubview(circularAlbumImageView)
        
        // 원형 앨범 이미지를 LP 중앙에 배치하는 제약 조건
        NSLayoutConstraint.activate([
            // LP 이미지뷰 중앙에 위치
            circularAlbumImageView.centerXAnchor.constraint(equalTo: lpImageView.centerXAnchor),
            circularAlbumImageView.centerYAnchor.constraint(equalTo: lpImageView.centerYAnchor),
            
            // 정사각형으로 만들기 (LP 크기의 60% 정도)
            circularAlbumImageView.widthAnchor.constraint(equalTo: lpImageView.widthAnchor, multiplier: 0.45),
            circularAlbumImageView.heightAnchor.constraint(equalTo: circularAlbumImageView.widthAnchor)
        ])
        
        // 제목 레이블 설정
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        // 아티스트 레이블 설정
        artistLabel.font = UIFont.systemFont(ofSize: 14)
        artistLabel.textColor = UIColor.secondaryLabel
        artistLabel.textAlignment = .center
        artistLabel.numberOfLines = 1
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 레이아웃이 완료된 후 원형으로 만들기
        DispatchQueue.main.async { [weak self] in
            self?.makeCircularImage()
        }
    }
    
    private func makeCircularImage() {
        // 원형 앨범 이미지뷰를 원형으로 만들기
        let radius = circularAlbumImageView.frame.width / 2
        circularAlbumImageView.layer.cornerRadius = radius
        
        // 선택적: 테두리 추가 (LP의 홈 부분을 표현)
        circularAlbumImageView.layer.borderWidth = 1.0
        circularAlbumImageView.layer.borderColor = UIColor.systemGray3.cgColor
        
        // 디버깅을 위한 출력
        print("📐 Circular image frame: \(circularAlbumImageView.frame)")
        print("🔵 Corner radius: \(radius)")
    }
    
    func setup(album: Album) {
        // 이전 작업 취소
        imageLoadTask?.cancel()
        
        // 텍스트 설정
        titleLabel.text = album.title
        artistLabel.text = album.artist
        
        // 앨범 커버 이미지 로딩
        if let url = URL(string: album.coverImageURL) {
            // ImageCacheManager가 있다면 사용
            if let imageCacheManager = ImageCacheManager.self as? ImageCacheManager.Type {
                ImageCacheManager.shared.loadImage(from: url) { [weak self] image in
                    DispatchQueue.main.async {
                        let albumImage = image ?? UIImage(named: "default_album_cover")
                        // 같은 이미지를 두 곳에 모두 설정
                        self?.albumCoverImageView.image = albumImage
                        self?.circularAlbumImageView.image = albumImage
                        
                        // 이미지 설정 후 원형으로 만들기
                        self?.makeCircularImageAfterDelay()
                    }
                }
            } else {
                // 기본 이미지 로딩
                loadImage(from: url)
            }
        } else {
            let defaultImage = UIImage(named: "default_album_cover")
            albumCoverImageView.image = defaultImage
            circularAlbumImageView.image = defaultImage
            makeCircularImageAfterDelay()
        }
    }
    
    private func makeCircularImageAfterDelay() {
        // 레이아웃이 완료된 후 원형으로 만들기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.makeCircularImage()
        }
    }
    
    private func loadImage(from url: URL) {
        imageLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    let defaultImage = UIImage(named: "default_album_cover")
                    self?.albumCoverImageView.image = defaultImage
                    self?.circularAlbumImageView.image = defaultImage
                    self?.makeCircularImageAfterDelay()
                }
                return
            }
            
            DispatchQueue.main.async {
                // 같은 이미지를 두 곳에 모두 설정
                self.albumCoverImageView.image = image
                self.circularAlbumImageView.image = image
                
                // 이미지 설정 후 원형으로 만들기
                self.makeCircularImageAfterDelay()
            }
        }
        imageLoadTask?.resume()
    }
}
