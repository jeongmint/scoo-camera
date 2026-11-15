# 교배 이미지 도구

교배 결과를 이미지 모델(지금은 GPT Image 2.6)로 만들고, 앱에 넣을 PNG로 정리하는 도구예요.

- **부모 후보**: 25종 (`characters.json`). 기존 5종(귀요·쿠르·모리·냐모·해피)은 앱 이미지를 쓰고, 새 20종은 `characters/`에 있어요. 해피는 이벤트라 기본 조합에서 빠져요.
- **교배 규칙**: 부모 A의 몸·실루엣·표정 + 부모 B의 대표 색 + 부모 B의 특징 하나. 원문 프롬프트는 [`prompts.md`](prompts.md)와 `breed.py`의 `PROMPT`에 있어요.
- **아기 → 성체**: 교배로 태어난 건 아기예요. 교배를 마친 성체는 아기 그림 왼쪽 위에 데이지 꽃(`daisy.png`)을 꽂아요.

## ChatGPT에서 만들기

1. [`prompts.md`](prompts.md)의 표에서 부모 A, 부모 B PNG를 **A → B 순서로** 첨부해요.
2. 프롬프트를 그대로 붙여 넣어요.
3. 받은 아기 PNG를 정리하고 성체 버전을 만들어요.

```bash
python3 tools/breeding/breed.py cutout ~/Downloads/baby.png --name chiko-sia
python3 tools/breeding/breed.py adult tools/breeding/out/chiko-sia-clean.png --name chiko-sia
```

결과는 `tools/breeding/out/`에 생겨요(커밋되지 않음). 앱에 바로 넣으려면 두 명령에 `--to-assets`를 붙여요. 그러면 `Breed-chiko-sia`(아기), `Adult-chiko-sia`(성체) 이미지 세트로 저장돼요.

## API로 한꺼번에 만들기

```bash
pip install openai pillow numpy
export OPENAI_API_KEY=...
python3 tools/breeding/breed.py generate --model <모델 ID> --pair chiko:sia --count 3
```

- `--model`은 OpenAI 문서에서 GPT Image 2.6의 정확한 ID를 확인해서 넣어요. 이 명령은 아직 실제 API로 돌려보지 못했어요.
- 조합마다 `-raw`(원본), `-baby`(정리), `-adult`(데이지) 세 장이 생겨요.
- `--pair`를 빼면 이벤트를 뺀 24종의 552개 조합 전부예요. 비용이 크니 먼저 몇 조합으로 시험하세요.

## 캐릭터 추가

```bash
python3 tools/breeding/breed.py add ~/Downloads/new.png --key bori --name 보리
python3 tools/breeding/breed.py prompts
```

## 데이지 위치 조절

`breed.py` 위쪽의 `DAISY_WIDTH`(캐릭터 폭 대비 크기, 기본 0.34), `DAISY_X`(왼쪽에서 몇 % 지점, 기본 0.27), `DAISY_TILT`(기울기)를 바꾸면 돼요. 꽃은 그 가로 위치의 몸 윤곽 맨 위에 꽂혀요.
