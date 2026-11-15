# 교배 프롬프트

부모 후보 25종(이벤트 제외 24종) · 부모 순서까지 따지면 552가지 조합.

## 쓰는 법

1. 아래 표에서 부모 A, 부모 B의 PNG를 **A → B 순서로** 첨부해요.
2. 아래 프롬프트를 그대로 붙여 넣어요.
3. 받은 아기 PNG를 정리하고 성체 버전(데이지)도 만들어요.

```bash
python3 tools/breeding/breed.py cutout ~/Downloads/baby.png --name chiko-sia
python3 tools/breeding/breed.py adult tools/breeding/out/chiko-sia-clean.png --name chiko-sia
```

## 프롬프트

```
첨부한 두 캐릭터를 부모로 삼아, 스쿠카메라 세계관의 새로운 아기 캐릭터 한 마리를 만들어줘.

[유전 규칙]

* 첫 번째 이미지의 캐릭터를 부모 A, 두 번째 이미지의 캐릭터를 부모 B로 지정한다.
* 부모 A의 둥근 몸 형태와 전체 실루엣을 기본으로 유지한다.
* 부모 B의 대표 색상을 아기 캐릭터의 주된 몸 색상으로 적용한다. 원래 색을 얼룩처럼 남기지 말고 자연스럽고 일관된 색상으로 표현한다.
* 부모 B를 알아볼 수 있는 특징을 정확히 하나 골라 물려준다. 귀, 잎, 줄무늬, 고리, 꼬리, 껍질 무늬, 소재 중 부모 A의 형태와 가장 잘 어울리는 특징을 선택한다.
* 특징을 붙여 놓은 합성물처럼 만들지 말고, 처음부터 하나의 캐릭터로 태어난 것처럼 자연스럽게 통합한다.
* 얼굴은 부모 A의 원래 표정을 유지한다. 작은 갈색 점눈 두 개와 원래의 작고 순한 웃는 입을 그대로 따른다. 코나 부리가 있는 캐릭터는 그 얼굴 구조도 유지한다.
* 눈썹, 날카로운 눈매, 능글맞은 표정, 이빨, 과장된 볼살을 추가하지 않는다.

[그림체]
첨부 이미지와 동일한 포근한 캐릭터 그림체.
통통하고 동그란 몸, 짧고 작은 부속, 부드러운 파스텔 색상.
미세한 솜털과 펠트 같은 촉감, 은은한 입체감, 부드러운 확산광.
몸의 소재는 부모 A를 기준으로 유지하되, 물려받은 특징의 소재가 자연스럽게 어우러지게 한다.
실제 동물의 해부학보다 둥근 마스코트 비율을 우선한다.
작은 크기로 보아도 얼굴과 물려받은 특징이 명확하게 읽혀야 한다.

[구도와 출력]

* 아기 캐릭터 단 한 마리만 정면을 바라보게 한다.
* 전체 몸과 귀, 꼬리, 장식이 모두 보이게 한다.
* 정방형 캔버스 중앙에 배치하고 사방에 충분한 투명 여백을 둔다.
* 실제 알파 채널이 있는 투명 배경 PNG로 출력한다.
* 배경색, 체크무늬 배경, 바닥, 바닥 그림자, 글자, 이름, 테두리, 워터마크를 넣지 않는다.
* 부모 캐릭터, 비교 이미지, 여러 시안, 분할 화면을 함께 그리지 않는다.

최종 결과는 “부모 A의 형태 + 부모 B의 색상과 특징 하나 + 부모 A의 원래 순한 표정”을 가진, 사랑스럽고 완성도 있는 새로운 스쿠카메라 캐릭터여야 한다.
```

## 부모 후보

| 키 | 이름 | 이미지 | 비고 |
| --- | --- | --- | --- |
| `gwiyo` | 귀요 | `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png` |  |
| `kuru` | 쿠르 | `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png` |  |
| `mori` | 모리 | `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png` |  |
| `nyamo` | 냐모 | `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png` |  |
| `happy` | 해피 | `ios/SCOO/Resources/Assets.xcassets/Companion-happy.imageset/happy.png` | 이벤트 |
| `huu` | 후우 | `tools/breeding/characters/huu.png` |  |
| `chiko` | 치코 | `tools/breeding/characters/chiko.png` |  |
| `dochi` | 도치 | `tools/breeding/characters/dochi.png` |  |
| `luna` | 루나 | `tools/breeding/characters/luna.png` |  |
| `toto` | 토토 | `tools/breeding/characters/toto.png` |  |
| `sunny` | 써니 | `tools/breeding/characters/sunny.png` |  |
| `suri` | 수리 | `tools/breeding/characters/suri.png` |  |
| `mellu` | 멜루 | `tools/breeding/characters/mellu.png` |  |
| `riru` | 리루 | `tools/breeding/characters/riru.png` |  |
| `popo` | 포포 | `tools/breeding/characters/popo.png` |  |
| `tangerine` | 귤 | `tools/breeding/characters/tangerine.png` |  |
| `baseball` | 야구공 | `tools/breeding/characters/baseball.png` |  |
| `otter` | 튜브를 한 수달 | `tools/breeding/characters/otter.png` |  |
| `yarn` | 실타래 | `tools/breeding/characters/yarn.png` |  |
| `tori` | 토리 | `tools/breeding/characters/tori.png` |  |
| `mupu` | 무푸 | `tools/breeding/characters/mupu.png` |  |
| `deogi` | 더기 | `tools/breeding/characters/deogi.png` |  |
| `hechi` | 헤치 | `tools/breeding/characters/hechi.png` |  |
| `sia` | 시아 | `tools/breeding/characters/sia.png` |  |
| `dia` | 디아 | `tools/breeding/characters/dia.png` |  |
