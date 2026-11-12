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
5. 앱에서 카메라 사용을 허용하고 화면에 떠 있는 **모리를 짧게 눌러 촬영**합니다. 카메라가 없는 시뮬레이터에서는 아래 사진 불러오기 버튼으로 체험할 수 있습니다.

서명된 IPA / TestFlight / App Store 배포는 아직 제공하지 않습니다. Apple 개발 계정과 Mac에서의 서명·실기기 확인이 필요합니다.

### iOS 기능

- **전체화면 카메라**: 노치부터 화면 아래까지 미리보기가 채워집니다. 사각 LCD 프레임과 필터 선택 바를 없애고 작은 조작부만 사진 위에 겹칩니다.
- **모리가 셔터**: 화면에 떠 있는 모리를 짧게 누르면 한 장을 촬영합니다. 별도의 원형 셔터는 없습니다.
- **롱탭 + 이동**: 모리를 0.35초 동안 누른 뒤 끌어 위치를 옮깁니다. 이동 손떼기는 촬영으로 연결되지 않도록 LongPress → Drag와 Tap을 배타적으로 조합했습니다. 위치를 화면 비율로 저장하고 재실행 시 복원합니다. 노치·홈 영역과 버튼에는 겹치지 않도록 제한합니다.
- **모리 성장**: 사진을 먹고 EXP, 레벨, 표시 크기가 증가합니다. 화면 위 이름을 누르면 성장 기록·이름 바꾸기·쓰다듬기 화면을 엽니다. 모리는 어항 없이 떠 있습니다.
- **Eternal 하나**: Core Image 32³ sRGB LUT를 미리보기와 저장 사진에 공통 적용합니다. 회청색 그림자, 따뜻한 빛, 짙은 검정, 차분한 초록을 목표로 합니다. 저장 시 아주 약한 소프트닝·어두운 영역의 디지털 입자·비네팅을 더합니다.
- **네이티브 촬영**: AVFoundation 전면·후면 전환, 탭 초점, 1–3배 줌, 지원 기기의 실제 플래시.
- **사진 비율**: 촬영은 전체화면 미리보기 비율로 크롭합니다. 앨범에서 불러온 사진은 원래 비율을 유지합니다. 긴 변 최대 2400px JPEG로 저장합니다. 모리와 UI는 결과 사진에 찍히지 않습니다.
- **음식 자동 분류**: Apple Vision의 `VNClassifyImageRequest`와 음식 라벨 목록을 이용한 기기 내 추정. 일상/음식 모드 직접 지정도 가능합니다.
- **앨범과 저장**: PhotosPicker로 사진 불러오기, 앱 앨범 보관, 사진 앱으로 내보내기·자동 저장. 추가 전용 권한만 필요한 순간에 요청합니다.
- **접근성**: 모리는 버튼으로 읽히며 VoiceOver 기본 동작으로 촬영할 수 있습니다. “중앙 아래로 이동” 접근성 동작도 제공합니다.

### Eternal의 기준

사용자가 제공한 낮·밤·실내·인물 사진의 분위기를 기준으로 만든 **첫 번째 색감 구현**입니다. 특정 Canon 센서/렌즈를 측정한 프로파일이나 동일 장면의 전후 비교로 보정한 LUT는 아닙니다. iPhone 원본의 자동 노출·HDR·화이트밸런스에 따라 차이가 생기므로 실기기 사진으로 추가 튜닝해야 합니다.

원하는 방향은 전역 노란 세피아 대신 **차가운 중성 그림자와 따뜻한 조명**, 검정을 회색으로 띄우지 않는 대비, 강한 빨강·주황 조명의 색 유지, 과한 인물 보정 없이 남는 작은 디지털 질감입니다. 미리보기는 최대 15fps / 긴 변 640px로 처리하며, 저장 시 입자·소프트닝·비네팅이 추가됩니다.

참고 사진은 색감 분석에만 사용했으며 공개 저장소에 포함하지 않았습니다. 이전 버전으로 저장된 사진의 필터 이름은 기록으로 유지됩니다.

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
    Processing/                 Eternal LUT / Core Image / Vision / 사진 앱 저장
    Models/                     성장 규칙 / 모리 위치 / 데이터 / 로컬 저장
    Views/                      촬영 / 마리모 / 앨범 / 설정
    Resources/                  권한 설명 / 개인정보 매니페스트 / 앱 아이콘
  SCOOTests/                    성장 / LUT / 모리 위치 테스트
```

Xcode에서 **⌘U**로 성장 규칙·Eternal LUT·모리 위치 테스트를 실행합니다. 명령행 빌드는 다음과 같습니다.

```sh
xcodebuild -project ios/SCOO.xcodeproj -scheme SCOO \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

프로젝트 파일을 다시 생성하려면 `python3 scripts/generate_xcodeproj.py`를 실행합니다. 의존성이 없는 생성기이며, Xcode에서 바꾼 수동 프로젝트 설정은 재생성 전에 생성기에도 반영해야 합니다.

### 확인 상태와 남은 검증

이 코드를 작성한 Linux 환경에는 Xcode와 iOS SDK가 없어 **iOS 컴파일·시뮬레이터·실기기 검증을 실행하지 못했습니다.** Swift 문법과 프로젝트/리소스 참조는 정적으로 점검합니다. XCTest의 실제 실행, 제스처 이벤트 처리, 실시간 색감·성능은 Mac과 iPhone에서 검증해야 합니다.

Mac에서 빌드한 뒤 다음을 확인하세요: 최초 카메라 권한 허용/거절, 앞·뒤 카메라 방향과 탭 초점 좌표, 촬영 중 백그라운드 전환, 플래시, 저장 공간 부족, 사진 추가 권한 거절, 음식 분류 정확도, 작은 iPhone에서의 레이아웃. 현재 UI는 세로 전용입니다. 모리의 짧은 탭/롱탭 이동 구분, 이동 취소, 재실행 위치 복원, Dynamic Island와 홈 영역 여백, 전체화면 미리보기/저장 크롭 일치도도 실기기 확인 대상입니다.

## 홍보용 웹 데모

```sh
cd web
npm run dev
```

Node.js 20 이상, 설치할 패키지는 없습니다. **http://localhost:3000**에서 열고, 휴대폰 카메라 기능은 HTTPS 주소에서 사용하세요. 데모는 초기 컨셉의 별도 홍보용 화면이며, 이번 iOS Eternal·전체화면 변경은 아직 반영하지 않았습니다. iOS 앱과 기록을 동기화하지 않습니다.

웹은 음식 모드를 직접 선택하고, 성장·사진은 브라우저의 localStorage / IndexedDB에 저장합니다. 데모 플래시는 밝기 효과이며 실제 LED가 아닙니다. 자세한 기능과 제한은 [`web/README.md`](web/README.md)를 참고하세요.

```sh
cd web
npm run check
npm test
```

웹 핵심 로직 테스트 5개와 브라우저에서 샘플 촬영·필터 변경·음식 보상·이름 변경·새로고침 후 기록 유지를 확인했습니다.

## 구현 방향

- 중심은 **전체화면 카메라와 떠 있는 모리**. 모리 탭은 촬영, 롱탭 후 드래그는 이동입니다.
- 필터는 **Eternal 하나**에 집중합니다. 성장 화면은 왼쪽 위 이름으로 엽니다.
- 다음 단계는 음식 인식 보정, 실제 사진 미적 평가 모델, 실시간 미리보기 최적화, 성장 단계와 생물 확장입니다.

## 참고 문서

- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [VNClassifyImageRequest](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)
- [PHAccessLevel.addOnly](https://developer.apple.com/documentation/photos/phaccesslevel/addonly)

---

Little moments, little growth. **SCOO**
