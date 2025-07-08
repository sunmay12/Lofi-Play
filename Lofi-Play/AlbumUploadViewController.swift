import UIKit
import FirebaseFirestore
import FirebaseStorage
import AVFoundation
import PhotosUI

class AlbumUploadViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // Album Info Section
    @IBOutlet weak var albumTitleTextField: UITextField!
    @IBOutlet weak var artistTextField: UITextField!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var selectCoverButton: UIButton!
    
    // Tracks Section
    @IBOutlet weak var tracksTableView: UITableView!
    @IBOutlet weak var addTrackButton: UIButton!
    
    // Bottom Buttons
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // Progress View
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressContainer: UIView!
    
    // MARK: - Properties
    private var tracks: [TrackUploadItem] = []
    private var selectedCoverImage: UIImage?
    private var isUploading = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "앨범 업로드"
        
        // Navigation Bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        
        // Cover Image View
        setupCoverImageView()
        
        // Buttons
        selectCoverButton.layer.cornerRadius = 8
        addTrackButton.layer.cornerRadius = 8
        uploadButton.layer.cornerRadius = 12
        cancelButton.layer.cornerRadius = 12
        
        uploadButton.backgroundColor = .systemBlue
        uploadButton.setTitleColor(.white, for: .normal)
        
        // Progress View
        progressContainer.isHidden = true
        progressView.progress = 0
        
        // Text Fields
        albumTitleTextField.delegate = self
        artistTextField.delegate = self
    }
    
    private func setupCoverImageView() {
        coverImageView.layer.cornerRadius = 12
        coverImageView.clipsToBounds = true
        coverImageView.backgroundColor = UIColor.systemGray5
        coverImageView.contentMode = .scaleAspectFill
        
        // 기본 이미지 설정
        if let placeholderImage = UIImage(systemName: "photo.fill") {
            let imageSize = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
            placeholderImage.draw(in: CGRect(origin: .zero, size: imageSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            coverImageView.image = resizedImage
            coverImageView.tintColor = .systemGray3
        }
    }
    
    private func setupTableView() {
        tracksTableView.delegate = self
        tracksTableView.dataSource = self
        tracksTableView.register(TrackUploadCell.self, forCellReuseIdentifier: "TrackUploadCell")
        
        // 스크롤 활성화!
        tracksTableView.isScrollEnabled = true
        
        // 테이블뷰 스타일 설정
        tracksTableView.separatorStyle = .singleLine
        tracksTableView.backgroundColor = .systemBackground
        
        // 행 높이 설정
        tracksTableView.rowHeight = 80
        tracksTableView.estimatedRowHeight = 80
    }
    
    // updateTableViewHeight() 메서드 제거됨!
    
    // MARK: - Actions
    @IBAction func selectCoverButtonTapped(_ sender: UIButton) {
        presentImagePicker()
    }
    
    @IBAction func addTrackButtonTapped(_ sender: UIButton) {
        presentTrackUploadAlert()
    }
    
    @IBAction func uploadButtonTapped(_ sender: UIButton) {
        validateAndUpload()
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Image Picker
    private func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Track Upload Alert
    private func presentTrackUploadAlert() {
        let alert = UIAlertController(title: "트랙 추가", message: "트랙 정보를 입력하세요", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "트랙 제목"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "아티스트"
        }
        
        let addAction = UIAlertAction(title: "추가", style: .default) { [weak self] _ in
            guard let titleField = alert.textFields?[0],
                  let artistField = alert.textFields?[1],
                  let title = titleField.text, !title.isEmpty,
                  let artist = artistField.text, !artist.isEmpty else {
                self?.showAlert(title: "오류", message: "모든 필드를 입력해주세요.")
                return
            }
            
            self?.presentAudioPicker(trackTitle: title, trackArtist: artist)
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Audio Picker
    private func presentAudioPicker(trackTitle: String, trackArtist: String) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        
        // Store track info temporarily
        UserDefaults.standard.set(trackTitle, forKey: "tempTrackTitle")
        UserDefaults.standard.set(trackArtist, forKey: "tempTrackArtist")
        
        present(documentPicker, animated: true)
    }
    
    // MARK: - Validation and Upload
    private func validateAndUpload() {
        guard !isUploading else { return }
        
        guard let albumTitle = albumTitleTextField.text, !albumTitle.isEmpty,
              let artist = artistTextField.text, !artist.isEmpty,
              let coverImage = selectedCoverImage,
              !tracks.isEmpty else {
            showAlert(title: "오류", message: "모든 필드를 입력하고 최소 1개의 트랙을 추가해주세요.")
            return
        }
        
        isUploading = true
        uploadButton.isEnabled = false
        progressContainer.isHidden = false
        
        uploadAlbum(title: albumTitle, artist: artist, coverImage: coverImage)
    }
    
    // MARK: - Upload Methods
    private func uploadAlbum(title: String, artist: String, coverImage: UIImage) {
        let albumId = UUID().uuidString
        
        updateProgress(0.1, "앨범 커버 업로드 중...")
        
        let processedImage = processImageForUpload(coverImage)
        
        guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            handleUploadError("이미지 처리 중 오류가 발생했습니다.")
            return
        }
        
        FirebaseManager.shared.uploadAlbumCover(data: imageData, albumId: albumId) { [weak self] result in
            switch result {
            case .success(let coverURL):
                self?.uploadTracks(albumId: albumId, albumTitle: title, artist: artist, coverURL: coverURL)
            case .failure(let error):
                self?.handleUploadError("커버 이미지 업로드 실패: \(error.localizedDescription)")
            }
        }
    }
    
    private func processImageForUpload(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 1024
        
        let size = image.size
        
        if size.width <= 0 || size.height <= 0 || size.width.isNaN || size.height.isNaN {
            let defaultSize = CGSize(width: 512, height: 512)
            UIGraphicsBeginImageContextWithOptions(defaultSize, false, 1.0)
            UIColor.systemGray5.setFill()
            UIRectFill(CGRect(origin: .zero, size: defaultSize))
            let fallbackImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            return fallbackImage
        }
        
        if size.width > maxSize || size.height > maxSize {
            let ratio = max(size.width / maxSize, size.height / maxSize)
            let newSize = CGSize(width: size.width / ratio, height: size.height / ratio)
            
            if newSize.width > 0 && newSize.height > 0 &&
               !newSize.width.isNaN && !newSize.height.isNaN {
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return resizedImage ?? image
            }
        }
        
        return image
    }

    private func uploadTracks(albumId: String, albumTitle: String, artist: String, coverURL: String) {
        let dispatchGroup = DispatchGroup()
        var uploadedTracks: [Track] = []
        var hasError = false
        
        for (index, trackItem) in tracks.enumerated() {
            dispatchGroup.enter()
            
            let progress = 0.2 + (0.6 * Double(index) / Double(tracks.count))
            updateProgress(progress, "트랙 업로드 중... (\(index + 1)/\(tracks.count))")
            
            let fileName = "\(albumId)_\(trackItem.id).m4a"
            
            FirebaseManager.shared.uploadAudioFile(data: trackItem.audioData, fileName: fileName) { result in
                switch result {
                case .success(let audioURL):
                    let track = Track(
                        id: trackItem.id,
                        title: trackItem.title,
                        artist: trackItem.artist,
                        duration: trackItem.duration,
                        audioURL: audioURL
                    )
                    uploadedTracks.append(track)
                case .failure(let error):
                    print("Track upload failed: \(error)")
                    hasError = true
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            if hasError {
                self?.handleUploadError("일부 트랙 업로드에 실패했습니다.")
            } else {
                self?.saveAlbumToFirestore(albumId: albumId, title: albumTitle, artist: artist, coverURL: coverURL, tracks: uploadedTracks)
            }
        }
    }

    private func saveAlbumToFirestore(albumId: String, title: String, artist: String, coverURL: String, tracks: [Track]) {
        updateProgress(0.9, "앨범 정보 저장 중...")
        
        let album = Album(id: albumId, title: title, artist: artist, coverImageURL: coverURL, tracks: tracks)
        
        print("Saving album with search fields:")
        print("- title: \(album.title)")
        print("- titleLowercase: \(album.titleLowercase)")
        print("- artist: \(album.artist)")
        print("- artistLowercase: \(album.artistLowercase)")
        
        let userID = "4313788658"
        
        FirebaseManager.shared.saveAlbumToLibrary(album: album, forUserID: userID) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.updateProgress(1.0, "업로드 완료!")
                    self?.showSuccessAndDismiss()
                } else {
                    self?.handleUploadError("앨범 저장에 실패했습니다.")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateProgress(_ progress: Double, _ message: String) {
        DispatchQueue.main.async {
            self.progressView.progress = Float(progress)
            self.progressLabel.text = message
        }
    }
    
    private func handleUploadError(_ message: String) {
        DispatchQueue.main.async {
            self.isUploading = false
            self.uploadButton.isEnabled = true
            self.progressContainer.isHidden = true
            self.showAlert(title: "업로드 실패", message: message)
        }
    }
    
    private func showSuccessAndDismiss() {
        let alert = UIAlertController(title: "성공", message: "앨범이 성공적으로 업로드되었습니다!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func removeTrack(at index: Int) {
        tracks.remove(at: index)
        tracksTableView.reloadData()
        // updateTableViewHeight() 호출 제거됨!
    }
}

// MARK: - PHPickerViewControllerDelegate
extension AlbumUploadViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("이미지 로드 오류: \(error)")
                    self?.showAlert(title: "오류", message: "이미지를 불러올 수 없습니다.")
                    return
                }
                
                guard let image = object as? UIImage else {
                    self?.showAlert(title: "오류", message: "올바른 이미지 형식이 아닙니다.")
                    return
                }
                
                let size = image.size
                if size.width <= 0 || size.height <= 0 || size.width.isNaN || size.height.isNaN {
                    self?.showAlert(title: "오류", message: "유효하지 않은 이미지입니다.")
                    return
                }
                
                self?.setSelectedImage(image)
            }
        }
    }
    
    private func setSelectedImage(_ image: UIImage) {
        let size = image.size
        guard size.width > 0 && size.height > 0 &&
              !size.width.isNaN && !size.height.isNaN else {
            showAlert(title: "오류", message: "유효하지 않은 이미지 크기입니다.")
            return
        }
        
        selectedCoverImage = image
        
        DispatchQueue.main.async { [weak self] in
            self?.coverImageView.image = image
            self?.coverImageView.tintColor = nil
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension AlbumUploadViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        let trackTitle = UserDefaults.standard.string(forKey: "tempTrackTitle") ?? ""
        let trackArtist = UserDefaults.standard.string(forKey: "tempTrackArtist") ?? ""
        
        UserDefaults.standard.removeObject(forKey: "tempTrackTitle")
        UserDefaults.standard.removeObject(forKey: "tempTrackArtist")
        
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let audioData = try Data(contentsOf: url)
            
            Task {
                let duration = await self.getAudioDuration(from: url)
                
                let trackItem = TrackUploadItem(
                    id: UUID().uuidString,
                    title: trackTitle,
                    artist: trackArtist,
                    duration: duration,
                    audioData: audioData,
                    fileName: url.lastPathComponent
                )
                
                DispatchQueue.main.async {
                    self.tracks.append(trackItem)
                    self.tracksTableView.reloadData()
                    // updateTableViewHeight() 호출 제거됨!
                }
            }
            
        } catch {
            showAlert(title: "오류", message: "오디오 파일을 읽을 수 없습니다: \(error.localizedDescription)")
        }
    }
    
    private func getAudioDuration(from url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isNaN ? 0.0 : seconds
        } catch {
            print("Failed to load audio duration: \(error)")
            return 0.0
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension AlbumUploadViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackUploadCell", for: indexPath) as! TrackUploadCell
        let track = tracks[indexPath.row]
        cell.configure(with: track)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeTrack(at: indexPath.row)
        }
    }
}

// MARK: - UITextFieldDelegate
extension AlbumUploadViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - TrackUploadItem
struct TrackUploadItem {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let audioData: Data
    let fileName: String
    
    var formattedDuration: String {
        let safeDuration = duration.isNaN ? 0.0 : duration
        let minutes = Int(safeDuration) / 60
        let seconds = Int(safeDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - TrackUploadCell
class TrackUploadCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let durationLabel = UILabel()
    private let fileNameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        artistLabel.font = UIFont.systemFont(ofSize: 14)
        artistLabel.textColor = .systemGray
        durationLabel.font = UIFont.systemFont(ofSize: 14)
        durationLabel.textColor = .systemGray
        fileNameLabel.font = UIFont.systemFont(ofSize: 12)
        fileNameLabel.textColor = .systemGray2
        
        [titleLabel, artistLabel, durationLabel, fileNameLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            fileNameLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 2),
            fileNameLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            fileNameLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            fileNameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            durationLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func configure(with track: TrackUploadItem) {
        titleLabel.text = track.title
        artistLabel.text = track.artist
        durationLabel.text = track.formattedDuration
        fileNameLabel.text = track.fileName
    }
}
