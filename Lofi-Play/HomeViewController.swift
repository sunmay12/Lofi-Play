//
//  HomeViewController.swift
//  Lofi-Play
//
//  Created by 김민서 on 6/19/25.
//

import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - IBOutlet 연결
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var libraryButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var adminButton: UIButton!
    
    // MARK: - 생명주기
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()  // UI 초기 설정
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 뷰가 완전히 나타난 후에 버튼 활성화
        enableButtons()
    }
    
    // MARK: - UI 설정
    private func setupUI() {
        view.backgroundColor = UIColor(red: 248/255.0, green: 244/255.0, blue: 241/255.0, alpha: 1.0)
        title = "Home"  // 네비게이션 타이틀
        
        // 각 버튼에 타이틀 설정
        setupHomeButton(playButton, title: "Turn Table", imageName: "")
        setupHomeButton(libraryButton, title: "My Albums", imageName: "")
        setupHomeButton(searchButton, title: "Search LP", imageName: "")
        setupHomeButton(adminButton, title: "Admin", imageName: "")
        
        // 초기에는 버튼 비활성화
        disableButtons()
    }
    
    // 홈 화면 버튼 공통 스타일 설정
    private func setupHomeButton(_ button: UIButton, title: String, imageName: String) {
        // 볼드체로 텍스트 설정
        let boldTitle = NSAttributedString(
            string: title,
            attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17)]
        )
        button.setAttributedTitle(boldTitle, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
    }
    
    // MARK: - 버튼 상태 관리
    private func disableButtons() {
        playButton.isEnabled = false
        libraryButton.isEnabled = false
        searchButton.isEnabled = false
        adminButton.isEnabled = false
    }
    
    private func enableButtons() {
        playButton.isEnabled = true
        libraryButton.isEnabled = true
        searchButton.isEnabled = true
        adminButton.isEnabled = true
    }
    

    
    // MARK: - 버튼 탭 액션 (Segue 사용)
    @IBAction func playButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toPlayerViewController", sender: self)
    }
    
    @IBAction func libraryButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toLibraryViewController", sender: self)
    }
    
    @IBAction func searchButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toSearchViewController", sender: self)
    }
    
    @IBAction func adminButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toAlbumUploadViewController", sender: self)
    }
}
