# 교배 이미지 시험 도구

교배 결과를 이미지 모델(지금은 GPT Image 2.6)로 만들 때 **그림체가 지켜지는지** 앱·서버 없이 먼저 확인하는 도구예요.

규칙은 노트 #2의 외형 유전 검토안을 따라요. **첫 번째 부모 = 몸·얼굴**, **두 번째 부모 = 포인트 색 + 대표 특징 하나**. 캐릭터 설명은 `characters.json`에 있어요.

## 1. ChatGPT에서 손으로 시험하기 (API 키 필요 없음)

[`prompts.md`](prompts.md)에 기본 친구 4명의 12개 조합 프롬프트가 있어요.

1. 조합 제목 아래 적힌 PNG 두 장을 **1번 → 2번 순서로** 첨부해요.
2. 프롬프트를 그대로 붙여 넣어요. 투명 배경으로 요청해요.
3. 결과를 내려받아 정리해요. 떠다니는 점을 지우고 가운데 맞춰 800px 정사각형으로 만들어요. 투명이 아닌 단색 배경이 오면 그것도 지워요.

```bash
python3 tools/breeding/breed.py cutout ~/Downloads/result.png --name nyamo-mori
```

정리된 PNG는 `tools/breeding/out/`에 생겨요(커밋되지 않음). 앱에 바로 넣으려면 `--to-assets`를 붙여요. 그러면 `Breed-nyamo-mori` 이미지 세트로 저장돼요.

## 2. API로 한꺼번에 만들기

```bash
pip install openai pillow numpy
export OPENAI_API_KEY=...
python3 tools/breeding/breed.py generate --model <모델 ID> --pair nyamo:mori --count 3
```

- `--model`은 OpenAI 문서에서 GPT Image 2.6의 정확한 ID를 확인해서 넣어요. 이 도구는 아직 실제 API로 돌려보지 못했어요.
- `--pair`를 빼면 12개 조합 전부, `--count`는 조합마다 몇 장 만들지예요. 같은 조합을 3장씩 만들어 보면 그림체가 얼마나 흔들리는지 비교하기 좋아요.
- 이벤트 친구 해피까지 넣으려면 `--events`를 붙여요(20개 조합).

## 볼 것

- 얼굴(점 눈 + 작은 입)이 그대로인가
- 펠트 질감과 조명이 원래 캐릭터들과 같은가
- 첫 부모의 몸이 그대로이고, 두 번째 부모의 특징이 **딱 하나**만 붙었는가
- 같은 조합을 여러 번 만들면 얼마나 달라지는가

프롬프트를 고치려면 `breed.py`의 `prompt()`와 `STYLE`, 캐릭터 설명은 `characters.json`을 고친 뒤 `python3 tools/breeding/breed.py prompts`로 `prompts.md`를 다시 만들어요.
