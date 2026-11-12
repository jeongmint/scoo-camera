# SCOO Camera 🌱📸

**오늘의 한 컷, 초록이 되는 순간.**

아이폰으로 사진을 찍을 때마다 작은 마리모가 자라는 **iOS 네이티브 빈티지 카메라 앱**입니다. 캐논 IXUS / IXY 시절의 실버 디카와 따뜻한 CCD 색감에서 영감을 받았습니다. 특정 카메라 모델의 색 재현을 보장하는 에뮬레이터는 아닙니다.

이 저장소에는 실제 제품인 **iOS 앱**과 컨셉을 소개하고 체험할 수 있는 **홍보용 웹 데모**가 함께 있습니다. iOS 앱은 웹뷰가 아닌 SwiftUI / AVFoundation 구현입니다.

| 폴더 | 역할 | 실행 |
| --- | --- | --- |
| [`ios/`](ios/) | iPhone용 네이티브 카메라 앱 | Xcode에서 `ios/SCOO.xcodeproj` 열기 |
| [`web/`](web/) | 홍보·컨셉 체험용 웹 데모 | `cd web && npm run dev` |

## iOS에서 시작하기

필요한 환경은 **Mac, Xcode 16 이상, iOS 17 이상 iPhone**입니다. 별도로 설치할 패키지나 API 키는 없습니다.

```sh
git clone https://github.com/jeongmint/scoo-camera.git
cd scoo-camera
open ios/SCOO.xcodeproj
```

1. Xcode에서 **SCOO** scheme을 선택합니다.
2. 프로젝트 → SCOO target → **Signing & Capabilities**에서 본인의 **Team**을 선택합니다.
3. 필요하면 Bundle Identifier `com.jeongmint.scoo`를 본인 계정에 맞게 바꿉니다.
4. 연결한 iPhone을 실행 대상으로 선택하고 **Run (⌘R)** 합니다. 실기기 개발자 모드가 필요할 수 있습니다.
5. 앱에서 카메라 사용을 허용하고 촬영합니다. 카메라가 없는 시뮬레이터에서는 아래 사진 불러오기 버튼으로 체험할 수 있습니다.

서명된 IPA / TestFlight / App Store 배포는 아직 제공하지 않습니다. Apple 개발 계정과 Mac에서의 서명·실기기 확인이 필요합니다.

### iOS 기능

- **네이티브 카메라**: AVFoundation 촬영, 전면·후면 전환, 탭 초점, 1–3배 줌, 후면 플래시 지원.
- **실시간 빈티지 색감**: Warm CCD / Soft Flash / Mint Day / Mono 2006. 미리보기는 최대 15fps, 긴 변 640px로 처리합니다.
- **사진 마무리**: 촬영 결과에 그레인·비네팅·선택적 날짜 인쇄. 촬영 미리보기 영역 비율로 크롭, 긴 변 최대 2400px JPEG.
- **음식 자동 분류**: Apple Vision의 `VNClassifyImageRequest`와 음식 관련 라벨 목록을 이용한 **기기 내 추정**. 외부 서버나 API 키가 필요 없습니다. 촬영 전 일상/음식 모드를 직접 지정할 수도 있습니다.
- **사진 불러오기**: 시스템 PhotosPicker로 선택한 이미지만 읽습니다. 라이브러리 전체 읽기 권한을 요구하지 않습니다.
- **사진 앱 저장**: 앱 앨범에 보관한 결과를 사진 앱에 내보내기. 설정에서 자동 저장을 켤 수 있습니다. 추가 전용 권한을 필요한 순간에 요청합니다.
- **마리모**: 이름 바꾸기, 쓰다듬기, EXP·크기·레벨 저장.
- **앱 앨범**: 사진 상세, 필터·분류 결과·보너스 확인, 확인 후 사진 삭제.

### 성장 규칙

| 사진 | EXP |
| --- | ---: |
| 일상 | +12 |
| 음식 | +20 |
| 적절한 밝기 | 최대 +5 |
| 명암 분포·인접 픽셀 변화량 | 최대 +5 |

100 EXP마다 레벨이 오르고 크기가 점진적으로 커집니다. 사진을 삭제해도 이미 받은 성장은 남습니다. 사진과 기록이 앱에 저장된 후에만 보상을 지급합니다.

**자동 음식 분류는 완벽하지 않습니다.** Vision 결과 상위 25개 중 신뢰도 0.25 이상인 음식 관련 라벨을 찾아 보상을 정합니다. 실제 음식 사진으로 임계값과 라벨 목록을 조정해야 합니다. 인식이 어려우면 촬영 전에 음식 모드를 직접 선택하세요. 자동 분류 실패 시 일상으로 기록하고 상세에 표시합니다.

**“감탄할 정도로 잘 찍었는지”를 판단하는 미적 평가 모델은 아직 연결하지 않았습니다.** 현재 보너스는 필터 적용 전 이미지의 밝기·명암·픽셀 변화량을 이용한 기술적 추정치입니다. 노이즈가 많은 사진에도 점수가 붙을 수 있습니다.

### 보관과 권한

- 사진과 성장 기록은 앱의 `Application Support/SCOO/`에 저장합니다. 성장·사진 인덱스는 원자적으로 갱신합니다.
- 사진 파일 저장 후 인덱스 저장에 실패하면 새 파일을 정리하고 보상을 지급하지 않습니다.
- 인덱스를 읽지 못하면 기존 데이터를 덮어쓰지 않고 오류를 표시합니다.
- 카메라: `NSCameraUsageDescription`.
- 사진 앱 내보내기: `NSPhotoLibraryAddUsageDescription`, `.addOnly`.
- 마이크, 위치, 라이브러리 전체 읽기 권한은 요청하지 않습니다.
- 앱 자체의 사진 서버 업로드, 광고·추적·분석 SDK가 없습니다. 사진·성장에 대한 iCloud 동기화는 구현하지 않았으며, iOS의 기기 백업 정책은 별개입니다.
- 앱을 삭제하면 앱 안의 사진과 마리모 기록도 사라집니다. 중요한 사진은 사진 앱에 내보내 주세요.
- 카메라 세션은 백그라운드 진입이나 앱 내부 화면 전환 시 중지하고 복귀 시 다시 시작합니다.

### iOS 구성

```text
ios/
  SCOO.xcodeproj/                Xcode 프로젝트 + 공유 scheme
  SCOO/
    App/SCOOApp.swift            시작점 / 색상
    Camera/CameraService.swift   AVFoundation 세션 / 촬영 / 미리보기
    Processing/                 Core Image / Vision / 사진 앱 저장
    Models/                     성장 규칙 / 데이터 / 로컬 저장
    Views/                      촬영 / 마리모 / 앨범 / 설정
    Resources/                  권한 설명 / 개인정보 매니페스트 / 앱 아이콘
  SCOOTests/GrowthRulesTests.swift
```

Xcode에서 **⌘U**로 성장 규칙 테스트를 실행합니다. 명령행 빌드는 다음과 같습니다.

```sh
xcodebuild -project ios/SCOO.xcodeproj -scheme SCOO \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

프로젝트 파일을 다시 생성하려면 `python3 scripts/generate_xcodeproj.py`를 실행합니다. 의존성이 없는 생성기이며, Xcode에서 바꾼 수동 프로젝트 설정은 재생성 전에 생성기에도 반영해야 합니다.

### 확인 상태와 남은 검증

이 코드를 작성한 Linux 환경에는 Xcode와 iOS SDK가 없어 **iOS 컴파일·시뮬레이터·실기기 검증을 실행하지 못했습니다.** 프로젝트/리소스 참조와 문법을 정적으로 점검하며, macOS용 GitHub Actions 빌드·테스트 워크플로를 포함합니다. 워크플로 성공을 확인한 상태는 아닙니다.

Mac에서 빌드한 뒤 다음을 확인하세요: 최초 카메라 권한 허용/거절, 앞·뒤 카메라 방향과 탭 초점 좌표, 촬영 중 백그라운드 전환, 플래시, 저장 공간 부족, 사진 추가 권한 거절, 음식 분류 정확도, 작은 iPhone에서의 레이아웃. 현재 UI는 세로 전용입니다.

## 홍보용 웹 데모

```sh
cd web
npm run dev
```

Node.js 20 이상, 설치할 패키지는 없습니다. **http://localhost:3000**에서 열고, 휴대폰 카메라 기능은 HTTPS 주소에서 사용하세요. 데모는 iOS 앱과 기록을 동기화하지 않습니다.

웹은 음식 모드를 직접 선택하고, 성장·사진은 브라우저의 localStorage / IndexedDB에 저장합니다. 데모 플래시는 밝기 효과이며 실제 LED가 아닙니다. 자세한 기능과 제한은 [`web/README.md`](web/README.md)를 참고하세요.

```sh
cd web
npm run check
npm test
```

웹 핵심 로직 테스트 5개와 브라우저에서 샘플 촬영·필터 변경·음식 보상·이름 변경·새로고침 후 기록 유지를 확인했습니다.

## 구현 방향

- 중심은 **카메라 경험**. 켜자마자 촬영하고 필터를 고릅니다.
- 마리모는 셔터 아래 작은 친구로 함께 있다가 눌렀을 때 정원 화면으로 열립니다.
- 다음 단계는 음식 인식 보정, 실제 사진 미적 평가 모델, 실시간 미리보기 최적화, 성장 단계와 생물 확장입니다.

## 참고 문서

- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [VNClassifyImageRequest](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)
- [PHAccessLevel.addOnly](https://developer.apple.com/documentation/photos/phaccesslevel/addonly)

---

Little moments, little growth. **SCOO**
