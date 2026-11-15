# 교배 프롬프트 (시험용)

규칙: 첫 번째 부모가 몸·얼굴, 두 번째 부모가 포인트 색과 대표 특징 하나 (노트 #2 외형 유전 검토안).

ChatGPT에서 쓰는 법: 부모 PNG를 **첫 번째 → 두 번째 순서로** 첨부하고 아래 프롬프트를 붙여 넣으세요.
결과를 받으면 `python3 tools/breeding/breed.py cutout <파일> --name <a>-<b>`로 배경을 지워요.

## 귀요 × 쿠르 — 귀요 몸 + 구름빛 하양 포인트 + 작은 구름 뭉치

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`

```
Image 1 is 귀요 and image 2 is 쿠르, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round brushed-gold jingle bell body with a raised rim around the middle and a keyhole slit at the bottom). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (soft cloud white with a faint sky-blue tint), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a small fluffy cloud puff, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 귀요 × 모리 — 귀요 몸 + 이끼 초록 포인트 + 작은 새싹

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`

```
Image 1 is 귀요 and image 2 is 모리, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round brushed-gold jingle bell body with a raised rim around the middle and a keyhole slit at the bottom). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (fresh moss green), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny green sprout with two leaves, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 귀요 × 냐모 — 귀요 몸 + 복숭아빛 줄무늬 포인트 + 고양이 귀

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`

```
Image 1 is 귀요 and image 2 is 냐모, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round brushed-gold jingle bell body with a raised rim around the middle and a keyhole slit at the bottom). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (peach-orange tabby stripes), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: two small pointed cat ears, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 쿠르 × 귀요 — 은은한 금빛 구름 + 작은 방울 장식 (노트 #2 예시)

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`

```
Image 1 is 쿠르 and image 2 is 귀요, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a fluffy white cotton cloud body made of soft round puffs). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (warm brushed gold), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny brushed-gold jingle bell charm, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 쿠르 × 모리 — 쿠르 몸 + 이끼 초록 포인트 + 작은 새싹

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`

```
Image 1 is 쿠르 and image 2 is 모리, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a fluffy white cotton cloud body made of soft round puffs). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (fresh moss green), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny green sprout with two leaves, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 쿠르 × 냐모 — 쿠르 몸 + 복숭아빛 줄무늬 포인트 + 고양이 귀

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`

```
Image 1 is 쿠르 and image 2 is 냐모, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a fluffy white cotton cloud body made of soft round puffs). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (peach-orange tabby stripes), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: two small pointed cat ears, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 모리 × 귀요 — 모리 몸 + 은은한 금빛 포인트 + 작은 방울 장식

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`

```
Image 1 is 모리 and image 2 is 귀요, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round marimo moss ball body covered in dense green grass-like fibers). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (warm brushed gold), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny brushed-gold jingle bell charm, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 모리 × 쿠르 — 모리 몸 + 구름빛 하양 포인트 + 작은 구름 뭉치

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`

```
Image 1 is 모리 and image 2 is 쿠르, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round marimo moss ball body covered in dense green grass-like fibers). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (soft cloud white with a faint sky-blue tint), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a small fluffy cloud puff, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 모리 × 냐모 — 모리 몸 + 복숭아빛 줄무늬 포인트 + 고양이 귀

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`

```
Image 1 is 모리 and image 2 is 냐모, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round marimo moss ball body covered in dense green grass-like fibers). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (peach-orange tabby stripes), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: two small pointed cat ears, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 냐모 × 귀요 — 냐모 몸 + 은은한 금빛 포인트 + 작은 방울 장식

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-gwiyo.imageset/gwiyo.png`

```
Image 1 is 냐모 and image 2 is 귀요, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round cream-and-peach tabby cat body with soft felt fur, short whiskers, two pointed ears and a curled tail). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (warm brushed gold), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny brushed-gold jingle bell charm, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 냐모 × 쿠르 — 냐모 몸 + 구름빛 하양 포인트 + 작은 구름 뭉치

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-kuru.imageset/kuru.png`

```
Image 1 is 냐모 and image 2 is 쿠르, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round cream-and-peach tabby cat body with soft felt fur, short whiskers, two pointed ears and a curled tail). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (soft cloud white with a faint sky-blue tint), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a small fluffy cloud puff, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```

## 냐모 × 모리 — 크림색 고양이 + 초록 귀·꼬리 (노트 #2 예시)

첨부: 1) `ios/SCOO/Resources/Assets.xcassets/Companion-nyamo.imageset/nyamo.png`  2) `ios/SCOO/Resources/Assets.xcassets/Companion-mori.imageset/mori.png`

```
Image 1 is 냐모 and image 2 is 모리, two characters from the same family. Create their child. Body: keep the body, silhouette and face of image 1 (a round cream-and-peach tabby cat body with soft felt fur, short whiskers, two pointed ears and a curled tail). Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 (fresh moss green), the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: a tiny green sprout with two leaves, small and naturally attached. Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, gentle studio light from the upper left, front view, centered, the whole character visible and filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes and a thin small smile, nothing else added to the face. One single character only, no text, no props, no ground shadow. Transparent background.
```
