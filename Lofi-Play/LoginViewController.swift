import UIKit
import KakaoSDKAuth
import KakaoSDKUser

class LoginViewController: UIViewController {
    
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var kakaoLoginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        logoImageView.layer.cornerRadius = logoImageView.frame.width / 2
        logoImageView.backgroundColor = .black
        logoImageView.contentMode = .center
        
        // 로고 이미지 무한 회전 애니메이션
        startLogoRotation()
        
        kakaoLoginButton.backgroundColor = .systemYellow
        kakaoLoginButton.setTitleColor(.black, for: .normal)
        kakaoLoginButton.layer.cornerRadius = 8
        kakaoLoginButton.setTitle("카카오톡으로 로그인", for: .normal)
    }
    
    private func startLogoRotation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 3.0 // 2초에 한 바퀴
        rotation.repeatCount = Float.infinity // 무한 반복
        rotation.isRemovedOnCompletion = false
        
        logoImageView.layer.add(rotation, forKey: "rotationAnimation")
    }
    
    @IBAction func kakaoLoginTapped(_ sender: UIButton) {
        sender.isEnabled = false
        
        // 카카오톡 설치 여부 확인
        if UserApi.isKakaoTalkLoginAvailable() {
            UserApi.shared.loginWithKakaoTalk { [weak self] oauthToken, error in
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    
                    if let error = error {
                        self?.showAlert(message: "카카오톡 로그인 실패: \(error.localizedDescription)")
                    } else {
                        // 로그인 성공 → 사용자 정보 가져오기
                        self?.fetchUserInfo()
                    }
                }
            }
        } else {
            // 카카오계정(웹) 로그인
            UserApi.shared.loginWithKakaoAccount { [weak self] oauthToken, error in
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    
                    if let error = error {
                        self?.showAlert(message: "카카오계정 로그인 실패: \(error.localizedDescription)")
                    } else {
                        // 로그인 성공 → 사용자 정보 가져오기
                        self?.fetchUserInfo()
                    }
                }
            }
        }
    }
    
    // 카카오 사용자 정보 가져오기 및 Firebase 저장
    private func fetchUserInfo() {
        UserApi.shared.me { [weak self] user, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(message: "사용자 정보 가져오기 실패: \(error.localizedDescription)")
                    return
                }
                
                guard let kakaoUser = user, let userID = kakaoUser.id else {
                    self?.showAlert(message: "사용자 ID를 가져올 수 없습니다.")
                    return
                }
                
                // UserManager에 사용자 ID 저장
                let userIDString = String(userID)
                UserManager.shared.setKakaoUserID(userIDString)
                
                // Firebase에 사용자 생성 (처음 로그인하는 경우에만)
                UserManager.shared.createUserIfNeeded(userID: userIDString) { success in
                    DispatchQueue.main.async {
                        if success {
                            // Firebase 사용자 생성 성공 → 홈 화면으로
                            self?.performSegue(withIdentifier: "LoginToHome", sender: nil)
                        } else {
                            self?.showAlert(message: "사용자 정보 저장에 실패했습니다.")
                        }
                    }
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
