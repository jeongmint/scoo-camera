#!/usr/bin/env python3
"""스쿠카메라 교배 이미지 도구.

    python3 tools/breeding/breed.py prompts                     # prompts.md 다시 만들기 (프롬프트 + 부모 목록)
    python3 tools/breeding/breed.py generate --model <모델 ID> [--pair chiko:sia] [--count 3]
                                                                # 이미지 API로 아기 생성 + 성체(데이지) 버전 (OPENAI_API_KEY 필요)
    python3 tools/breeding/breed.py adult <아기 PNG> [--name chiko-sia] [--to-assets]
                                                                # 교배를 마친 성체: 데이지 꽃 붙이기
    python3 tools/breeding/breed.py cutout <이미지> [--name chiko-sia] [--to-assets]
                                                                # 떠다니는 점 제거 + 정사각형 800px 정리
    python3 tools/breeding/breed.py add <PNG> --key <영문 키> --name <이름> [--event]
                                                                # 새 캐릭터를 부모 목록에 추가

필요한 패키지: pillow, numpy (generate는 openai 패키지도 필요)
"""
import argparse
import base64
import itertools
import json
import os
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
CHARACTERS = HERE / "characters"
DAISY = HERE / "daisy.png"
ASSETS = ROOT / "ios/SCOO/Resources/Assets.xcassets"

# 교배 프롬프트 원문. 첨부 순서: 1번 이미지 = 부모 A, 2번 이미지 = 부모 B.
PROMPT = """첨부한 두 캐릭터를 부모로 삼아, 스쿠카메라 세계관의 새로운 아기 캐릭터 한 마리를 만들어줘.

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

최종 결과는 “부모 A의 형태 + 부모 B의 색상과 특징 하나 + 부모 A의 원래 순한 표정”을 가진, 사랑스럽고 완성도 있는 새로운 스쿠카메라 캐릭터여야 한다."""

# 성체 데이지: 캐릭터 폭 대비 크기, 몸 윤곽 위 어느 가로 위치에 꽂을지, 기울기(도).
# 캐릭터마다 characters.json의 "daisy": {"x": 0.4, "below_ears": true}로 바꿀 수 있고,
# 교배 결과(이름이 a-b)는 부모 A의 설정을 따른다.
DAISY_WIDTH = 0.26
DAISY_X = 0.27
DAISY_TILT = 12


def load():
    return json.loads((HERE / "characters.json").read_text())["characters"]


def save(characters):
    path = HERE / "characters.json"
    data = json.loads(path.read_text())
    data["characters"] = characters
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def pairs(characters, include_events=False):
    keys = [k for k, c in characters.items() if include_events or not c.get("event")]
    return list(itertools.permutations(keys, 2))


def cmd_prompts(args):
    characters = load()
    regular = [k for k, c in characters.items() if not c.get("event")]
    lines = [
        "# 교배 프롬프트",
        "",
        f"부모 후보 {len(characters)}종(이벤트 제외 {len(regular)}종) · 부모 순서까지 따지면 {len(pairs(characters))}가지 조합.",
        "",
        "## 쓰는 법",
        "",
        "1. 아래 표에서 부모 A, 부모 B의 PNG를 **A → B 순서로** 첨부해요.",
        "2. 아래 프롬프트를 그대로 붙여 넣어요.",
        "3. 받은 아기 PNG를 정리하고 성체 버전(데이지)도 만들어요.",
        "",
        "```bash",
        "python3 tools/breeding/breed.py cutout ~/Downloads/baby.png --name chiko-sia",
        "python3 tools/breeding/breed.py adult tools/breeding/out/chiko-sia-clean.png --name chiko-sia",
        "```",
        "",
        "## 프롬프트",
        "",
        "```",
        PROMPT,
        "```",
        "",
        "## 부모 후보",
        "",
        "| 키 | 이름 | 이미지 | 비고 |",
        "| --- | --- | --- | --- |",
    ]
    for key, c in characters.items():
        lines.append(f"| `{key}` | {c['name']} | `{c['image']}` | {'이벤트' if c.get('event') else ''} |")
    path = HERE / "prompts.md"
    path.write_text("\n".join(lines) + "\n")
    print(f"{len(characters)}종 → {path.relative_to(ROOT)}")


def cmd_generate(args):
    try:
        from openai import OpenAI
    except ImportError:
        sys.exit("pip install openai 후 다시 실행하세요.")
    if not os.environ.get("OPENAI_API_KEY"):
        sys.exit("OPENAI_API_KEY 환경 변수가 필요해요.")
    characters = load()
    todo = [tuple(p.split(":")) for p in args.pair] if args.pair else pairs(characters, args.events)
    for a, b in todo:
        if a not in characters or b not in characters:
            sys.exit(f"모르는 캐릭터: {a}:{b} (characters.json의 키를 쓰세요)")
    client = OpenAI()
    OUT.mkdir(exist_ok=True)
    for a, b in todo:
        for n in range(args.count):
            stem = f"{a}-{b}" + (f"-{n + 1}" if args.count > 1 else "")
            raw = OUT / f"{stem}-raw.png"
            if raw.exists() and not args.force:
                print(f"건너뜀 {raw.name} (이미 있음)")
                continue
            print(f"생성 중 {characters[a]['name']} × {characters[b]['name']} {stem} …", flush=True)
            with open(ROOT / characters[a]["image"], "rb") as first, open(ROOT / characters[b]["image"], "rb") as second:
                result = client.images.edit(
                    model=args.model,
                    image=[first, second],
                    prompt=PROMPT,
                    background="transparent",
                    output_format="png",
                    size="1024x1024",
                )
            raw.write_bytes(base64.b64decode(result.data[0].b64_json))
            baby = cutout(raw, OUT / f"{stem}-baby.png")
            x_ratio, below_ears, drop = daisy_settings(a)
            add_daisy(baby, OUT / f"{stem}-adult.png", x_ratio=x_ratio, below_ears=below_ears, drop=drop)
            print(f"  → {stem}-baby.png, {stem}-adult.png")


# ---- cutout --------------------------------------------------------------

def _largest_component(mask):
    import numpy as np
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    best = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        comp = [(y0, x0)]
        seen[y0, x0] = True
        queue = deque(comp)
        while queue:
            y, x = queue.popleft()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    comp.append((ny, nx))
                    queue.append((ny, nx))
        if len(comp) > len(best):
            best = comp
    out = np.zeros_like(mask, dtype=bool)
    if best:
        ys, xs = zip(*best)
        out[list(ys), list(xs)] = True
    return out


def _grow(mask, n):
    out = mask.copy()
    for _ in range(n):
        g = out.copy()
        g[1:] |= out[:-1]; g[:-1] |= out[1:]; g[:, 1:] |= out[:, :-1]; g[:, :-1] |= out[:, 1:]
        out = g
    return out


def cutout(source, target, size=800):
    """Removes the background (alpha or a flat color), drops stray specks and centers on a square canvas."""
    import numpy as np
    from PIL import Image
    image = Image.open(source).convert("RGBA")
    arr = np.array(image).astype(np.float32)
    alpha = arr[..., 3] / 255
    if alpha.min() > 0.99:   # opaque: key out the flat color found along the border
        border = np.concatenate([arr[0, :, :3], arr[-1, :, :3], arr[:, 0, :3], arr[:, -1, :3]])
        key = np.median(border, axis=0)
        dist = np.sqrt(((arr[..., :3] - key) ** 2).sum(axis=2))
        t = np.clip((dist - 18) / (60 - 18), 0, 1)
        alpha = t * t * (3 - 2 * t)
        # fill enclosed holes (eyes, mouth) that may match the key color
        body = _largest_component(alpha > 0.5)
        outside = np.zeros_like(body)
        h, w = body.shape
        queue = deque()
        edge = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
        for y, x in edge:
            if not body[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
        while queue:
            y, x = queue.popleft()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and not body[ny, nx] and not outside[ny, nx]:
                    outside[ny, nx] = True
                    queue.append((ny, nx))
        alpha = np.where(~outside & ~_grow(outside, 2), 1.0, alpha)
    keep = _grow(_largest_component(alpha >= 0.16), 6)
    alpha = np.where(keep, alpha, 0)
    arr[..., 3] = alpha * 255
    clean = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
    box = clean.getbbox()
    if box is None:
        raise SystemExit(f"{source}: 캐릭터를 찾지 못했어요.")
    clean = clean.crop(box)
    side = max(clean.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(clean, ((side - clean.width) // 2, (side - clean.height) // 2))
    canvas.resize((size, size), Image.LANCZOS).save(target, optimize=True)
    return target


def head_line(alpha, box, min_share=0.4):
    """First row from the top where the silhouette is one piece — i.e. where ears, stems and leaves meet the head."""
    import numpy as np
    left, top, right, bottom = box
    width = right - left
    for y in range(top, bottom):
        row = np.nonzero(alpha[y, left:right] > 128)[0]
        if len(row) and row[-1] - row[0] + 1 == len(row) and len(row) >= width * min_share:
            return y
    return top


def daisy_settings(name):
    """Placement for a character key, or for a bred 'a-b' name (parent A decides the body shape)."""
    characters = load()
    key = name if name in characters else name.split("-")[0]
    custom = characters.get(key, {}).get("daisy", {})
    return custom.get("x", DAISY_X), custom.get("below_ears", False), custom.get("drop", 0.0)


def add_daisy(source, target, size=800, x_ratio=DAISY_X, below_ears=False, drop=0.0):
    """교배를 마친 성체: 몸 윤곽 위에 데이지 꽃을 꽂는다.
    below_ears=True면 귀·꼭지 같은 튀어나온 부분 아래, 머리 윤곽에 꽂는다.
    drop은 거기서 꽃 높이의 몇 배만큼 더 내릴지 (예: 0.3)."""
    import numpy as np
    from PIL import Image
    body = Image.open(source).convert("RGBA")
    daisy = Image.open(DAISY).convert("RGBA")
    alpha = np.array(body)[..., 3]
    box = body.getbbox()
    if box is None:
        raise SystemExit(f"{source}: 캐릭터를 찾지 못했어요.")
    left, top, right, bottom = box
    width = right - left
    x = int(left + width * x_ratio)
    floor = head_line(alpha, box) if below_ears else top
    column = np.nonzero(alpha[floor:, x] > 128)[0]
    edge = floor + int(column[0]) if len(column) else floor
    flower_w = int(width * DAISY_WIDTH)
    flower = daisy.resize((flower_w, int(daisy.height * flower_w / daisy.width)), Image.LANCZOS)
    flower = flower.rotate(DAISY_TILT, resample=Image.BICUBIC, expand=True)
    # room around the character so the flower can stick out over the silhouette
    pad = flower.width
    canvas = Image.new("RGBA", (body.width + pad * 2, body.height + pad * 2), (0, 0, 0, 0))
    canvas.paste(body, (pad, pad))
    cx, cy = pad + x, pad + edge + int(flower.height * (0.12 + drop))
    canvas.alpha_composite(flower, (cx - flower.width // 2, cy - flower.height // 2))
    framed = canvas.crop(canvas.getbbox())
    side = int(max(framed.size) * 1.08)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(framed, ((side - framed.width) // 2, (side - framed.height) // 2))
    square.resize((size, size), Image.LANCZOS).save(target, optimize=True)
    return target


def _to_assets(name, kind):
    folder = ASSETS / f"{kind}-{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{name}.png"
    (folder / "Contents.json").write_text(json.dumps(
        {"images": [{"filename": target.name, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
        indent=2) + "\n")
    return target


def _show(path):
    return path.relative_to(ROOT) if path.is_relative_to(ROOT) else path


def cmd_cutout(args):
    source = Path(args.image)
    name = args.name or source.stem
    if args.to_assets:
        target = _to_assets(name, "Breed")
    else:
        OUT.mkdir(exist_ok=True)
        target = OUT / f"{name}-clean.png"
    cutout(source, target)
    print(f"→ {_show(target)}")


def cmd_adult(args):
    source = Path(args.image)
    name = args.name or source.stem.removesuffix("-clean").removesuffix("-baby")
    if args.to_assets:
        target = _to_assets(name, "Adult")
    else:
        OUT.mkdir(exist_ok=True)
        target = OUT / f"{name}-adult.png"
    x_ratio, below_ears, drop = daisy_settings(args.parent or name)
    add_daisy(source, target, x_ratio=x_ratio, below_ears=below_ears, drop=drop)
    print(f"→ {_show(target)}")


def cmd_add(args):
    characters = load()
    CHARACTERS.mkdir(exist_ok=True)
    target = CHARACTERS / f"{args.key}.png"
    cutout(Path(args.image), target)
    entry = {"name": args.name, "image": str(target.relative_to(ROOT))}
    if args.event:
        entry["event"] = True
    characters[args.key] = entry
    save(characters)
    print(f"{args.name} 추가 → {target.relative_to(ROOT)} (prompts.md는 prompts 명령으로 다시 만드세요)")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prompts", help="prompts.md 다시 만들기")
    p.set_defaults(func=cmd_prompts)
    g = sub.add_parser("generate", help="이미지 API로 아기와 성체 생성 (OPENAI_API_KEY 필요)")
    g.add_argument("--model", required=True, help="이미지 모델 ID (OpenAI 문서에서 정확한 ID 확인)")
    g.add_argument("--pair", action="append", help="a:b 형식(a가 부모 A), 여러 번 지정 가능. 없으면 전체 조합")
    g.add_argument("--count", type=int, default=1, help="조합마다 몇 장 만들지 (그림체 흔들림 비교용)")
    g.add_argument("--events", action="store_true", help="이벤트 친구(해피)도 포함")
    g.add_argument("--force", action="store_true", help="이미 있는 결과도 다시 생성")
    g.set_defaults(func=cmd_generate)
    a = sub.add_parser("adult", help="성체 버전: 데이지 꽃 붙이기")
    a.add_argument("image")
    a.add_argument("--name", help="결과 이름, 예: chiko-sia")
    a.add_argument("--to-assets", action="store_true", help="앱 Assets에 Adult-<name> 이미지 세트로 저장")
    a.add_argument("--parent", help="꽃 위치를 따를 부모 A 키 (기본: 이름 a-b의 a)")
    a.set_defaults(func=cmd_adult)
    c = sub.add_parser("cutout", help="점 제거 + 정사각형 정리")
    c.add_argument("image")
    c.add_argument("--name", help="결과 이름, 예: chiko-sia")
    c.add_argument("--to-assets", action="store_true", help="앱 Assets에 Breed-<name> 이미지 세트로 저장")
    c.set_defaults(func=cmd_cutout)
    n = sub.add_parser("add", help="새 캐릭터를 부모 목록에 추가")
    n.add_argument("image")
    n.add_argument("--key", required=True, help="영문 키, 예: chiko")
    n.add_argument("--name", required=True, help="이름, 예: 치코")
    n.add_argument("--event", action="store_true", help="이벤트 캐릭터 (기본 조합에서 제외)")
    n.set_defaults(func=cmd_add)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
