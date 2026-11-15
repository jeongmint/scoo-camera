#!/usr/bin/env python3
"""교배 이미지 시험 도구.

    python3 tools/breeding/breed.py prompts               # 12개 조합 프롬프트를 prompts.md로 저장 (API 키 불필요)
    python3 tools/breeding/breed.py generate --model <모델 ID> [--pair nyamo:mori]
                                                          # 이미지 API로 생성 (OPENAI_API_KEY 필요)
    python3 tools/breeding/breed.py cutout <이미지> [--name nyamo-mori] [--to-assets]
                                                          # 배경 제거 + 정사각형 800px 정리

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
ASSETS = ROOT / "ios/SCOO/Resources/Assets.xcassets"

STYLE = (
    "Keep the exact look of the reference images: a soft needle-felted plush toy, matte felt fibers, "
    "gentle studio light from the upper left, front view, centered, the whole character visible and "
    "filling about 80% of a square canvas. Keep the face of image 1 exactly: small dark-brown dot eyes "
    "and a thin small smile, nothing else added to the face. One single character only, no text, "
    "no props, no ground shadow."
)
BACKGROUND = {
    "transparent": "Transparent background.",
    # Only for tools without transparency: a flat color the cutout step can remove.
    "gray": "Plain flat mid-gray (#808080) background with no gradient, no floor and no shadow.",
}


def load():
    data = json.loads((HERE / "characters.json").read_text())
    return data["characters"], data.get("overrides", {})


def pairs(characters, include_events=False):
    keys = [k for k, c in characters.items() if include_events or not c.get("event")]
    return list(itertools.permutations(keys, 2))


def summary_ko(a, b, characters, overrides):
    key = f"{a} x {b}"
    if key in overrides:
        return overrides[key]
    A, B = characters[a], characters[b]
    return f"{A['name']} 몸 + {B['color_ko']} 포인트 + {B['feature_ko']}"


def prompt(a, b, characters, background):
    A, B = characters[a], characters[b]
    return (
        f"Image 1 is {A['name']} and image 2 is {B['name']}, two characters from the same family. "
        f"Create their child. Body: keep the body, silhouette and face of image 1 ({A['body']}). "
        f"Color: tint only the tips and edges (ears, tail, top, rim) with the point color of image 2 ({B['color']}), "
        f"the rest keeps the colors of image 1. Feature: add exactly one signature feature from image 2: {B['feature']}, "
        f"small and naturally attached. {STYLE} {BACKGROUND[background]}"
    )


def cmd_prompts(args):
    characters, overrides = load()
    lines = [
        "# 교배 프롬프트 (시험용)",
        "",
        "규칙: 첫 번째 부모가 몸·얼굴, 두 번째 부모가 포인트 색과 대표 특징 하나 (노트 #2 외형 유전 검토안).",
        "",
        "ChatGPT에서 쓰는 법: 부모 PNG를 **첫 번째 → 두 번째 순서로** 첨부하고 아래 프롬프트를 붙여 넣으세요.",
        "결과를 받으면 `python3 tools/breeding/breed.py cutout <파일> --name <a>-<b>`로 배경을 지워요.",
        "",
    ]
    for a, b in pairs(characters, args.events):
        A, B = characters[a], characters[b]
        lines += [
            f"## {A['name']} × {B['name']} — {summary_ko(a, b, characters, overrides)}",
            "",
            f"첨부: 1) `{A['image']}`  2) `{B['image']}`",
            "",
            "```",
            prompt(a, b, characters, args.background),
            "```",
            "",
        ]
    path = HERE / "prompts.md"
    path.write_text("\n".join(lines))
    print(f"{len(pairs(characters, args.events))}개 조합 → {path.relative_to(ROOT)}")


def cmd_generate(args):
    try:
        from openai import OpenAI
    except ImportError:
        sys.exit("pip install openai 후 다시 실행하세요.")
    if not os.environ.get("OPENAI_API_KEY"):
        sys.exit("OPENAI_API_KEY 환경 변수가 필요해요.")
    characters, _ = load()
    todo = [tuple(p.split(":")) for p in args.pair] if args.pair else pairs(characters, args.events)
    client = OpenAI()
    OUT.mkdir(exist_ok=True)
    for a, b in todo:
        for n in range(args.count):
            target = OUT / f"{a}-{b}-{n + 1}.png"
            if target.exists() and not args.force:
                print(f"건너뜀 {target.name} (이미 있음)")
                continue
            print(f"생성 중 {characters[a]['name']} × {characters[b]['name']} #{n + 1} …", flush=True)
            with open(ROOT / characters[a]["image"], "rb") as first, open(ROOT / characters[b]["image"], "rb") as second:
                result = client.images.edit(
                    model=args.model,
                    image=[first, second],
                    prompt=prompt(a, b, characters, "transparent"),
                    background="transparent",
                    output_format="png",
                    size="1024x1024",
                )
            target.write_bytes(base64.b64decode(result.data[0].b64_json))
            cutout(target, target.with_name(target.stem + "-clean.png"))
            print(f"  → {target.relative_to(ROOT)}")


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


def cmd_cutout(args):
    source = Path(args.image)
    name = args.name or source.stem
    if args.to_assets:
        folder = ASSETS / f"Breed-{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{name}.png"
        (folder / "Contents.json").write_text(json.dumps(
            {"images": [{"filename": target.name, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
            indent=2) + "\n")
    else:
        OUT.mkdir(exist_ok=True)
        target = OUT / f"{name}-clean.png"
    cutout(source, target)
    print(f"→ {target.relative_to(ROOT) if target.is_relative_to(ROOT) else target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prompts", help="조합별 프롬프트를 prompts.md로 저장")
    p.add_argument("--background", choices=BACKGROUND, default="transparent", help="기본은 투명 배경, 투명이 안 되는 도구는 gray")
    p.add_argument("--events", action="store_true", help="이벤트 친구(해피)도 포함")
    p.set_defaults(func=cmd_prompts)
    g = sub.add_parser("generate", help="이미지 API로 생성 (OPENAI_API_KEY 필요)")
    g.add_argument("--model", required=True, help="이미지 모델 ID (OpenAI 문서에서 정확한 ID 확인)")
    g.add_argument("--pair", action="append", help="a:b 형식, 여러 번 지정 가능. 없으면 전체 조합")
    g.add_argument("--count", type=int, default=1, help="조합마다 몇 장 만들지 (그림체 흔들림 비교용)")
    g.add_argument("--events", action="store_true", help="이벤트 친구(해피)도 포함")
    g.add_argument("--force", action="store_true", help="이미 있는 결과도 다시 생성")
    g.set_defaults(func=cmd_generate)
    c = sub.add_parser("cutout", help="배경 제거 + 정사각형 정리")
    c.add_argument("image")
    c.add_argument("--name", help="결과 이름, 예: nyamo-mori")
    c.add_argument("--to-assets", action="store_true", help="앱 Assets에 Breed-<name> 이미지 세트로 저장")
    c.set_defaults(func=cmd_cutout)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
