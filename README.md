# 🎵 Lofi-Play

제작 기간

2025.06.18 ~ 2025.06.22

--

Lofi-Play는 Firebase 기반의 iOS 음악 스트리밍 앱으로, 실제 LP 레코드의 감성을 시각적으로 구현한 재생 화면이 핵심인 프로젝트입니다.  
카카오 로그인, 음원 스트리밍, 앨범 관리, 사용자 보관함 기능 등을 제공합니다.

--

## 📱 주요 기능

- 🔐 **카카오 간편 로그인**  
- 🔍 **앨범 검색 기능 (앨범명 / 가수명 기준)**  
- 🎵 **LP 모양의 음악 재생 화면** (Play/Pause 시 LP 회전 & Tonearm 이동 애니메이션)  
- ❤️ **앨범 즐겨찾기 및 보관함 저장**  
- 🛠️ **관리자 페이지**를 통한 앨범 및 음원 등록/삭제 기능 (Firebase 연동)  

--

## 🧱 기술 스택

| 구성 요소       | 사용 기술                         |
|----------------|-----------------------------------|
| Language        | Swift (UIKit, Storyboard)        |
| Backend         | Firebase (Firestore, Storage, Auth) |
| API             | Kakao Login API                  |
| AV 처리         | AVFoundation (AVAudioPlayer)     |
| 애니메이션      | Core Animation, UIViewPropertyAnimator |
| 아키텍처 패턴   | MVC                               |

--

## 🖥️ 화면 구성

| 화면 이름       | 설명                                                         |
|----------------|------------------------------------------------------------|
| 로그인         | 카카오 API로 간편 로그인 및 회원가입                          |
| 홈             | 재생, 보관함, 검색 화면 이동 버튼 / 관리자 접근 버튼 (관리자만 표시) |
| 검색           | 앨범명 또는 가수명으로 검색 / 결과 리스트 → 앨범 상세 이동     |
| 앨범 상세      | 앨범 커버, 정보, 트랙 리스트 (테이블 뷰) → 곡 선택 시 재생 화면 이동 |
| 재생           | LP 회전 애니메이션, Tonearm 동작, 트랙 컨트롤, 보관함 저장 버튼 |
| 보관함         | 즐겨찾기한 앨범 리스트 확인 및 접근                            |
| 관리자         | 앨범 정보, 음원 파일 등록/삭제 기능 (Firebase 연동)            |

--

## 🗂️ Firebase 구조

- **Firestore**
  - `users` (uid, favorites)
  - `albums` (title, artist, imageURL, etc.)
  - `tracks` (albumId, title, audioURL, order)
- **Storage**
  - `/images/` 앨범 커버
  - `/audios/` 음원 파일

--

## 📺 시연 영상

- [YouTube 시연 영상 보기](https://youtu.be/TUUkYDfnQS8?si=WsskNkLIJh8sWTPa)
