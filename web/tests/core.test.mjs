import test from "node:test";
import assert from "node:assert/strict";
import {
  photoQuality,
  rewardFor,
  growthFor,
  applyFilm,
  FILTERS,
} from "../dist/core.js";
function pixels(w, h, fn) {
  const a = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const v = fn(x, y);
      a.set([v, v, v, 255], (y * w + x) * 4);
    }
  return a;
}
test("well-exposed detailed images earn more than dark or blank images", () => {
  const q = photoQuality(
    pixels(16, 16, (x, y) => ((x + y) % 2 ? 80 : 180)),
    16,
    16,
  );
  const dark = photoQuality(
    pixels(16, 16, () => 0),
    16,
    16,
  );
  const blank = photoQuality(
    pixels(16, 16, () => 132),
    16,
    16,
  );
  assert.ok(q.bonus > dark.bonus);
  assert.ok(q.bonus > blank.bonus);
  assert.ok(q.bonus <= 10);
});
test("food receives eight more EXP; malformed bonuses stay bounded", () => {
  assert.equal(
    rewardFor("food", { bonus: 7 }) - rewardFor("daily", { bonus: 7 }),
    8,
  );
  assert.equal(rewardFor("food", { bonus: 500 }), 30);
  assert.equal(rewardFor("daily", { bonus: -1 }), 12);
});
test("level boundaries preserve remainder and size increases", () => {
  assert.deepEqual(growthFor(0), { level: 1, progress: 0, size: "1.0" });
  assert.equal(growthFor(99).level, 1);
  assert.equal(growthFor(100).level, 2);
  assert.equal(growthFor(135).progress, 35);
  assert.ok(Number(growthFor(100).size) > Number(growthFor(0).size));
});
test("mono export removes color while preserving alpha", () => {
  const a = new Uint8ClampedArray([220, 70, 30, 128]);
  applyFilm(a, FILTERS[3], () => 0.5);
  assert.equal(a[0], a[1]);
  assert.equal(a[1], a[2]);
  assert.equal(a[3], 128);
});
test("empty quality inputs have no bonus", () =>
  assert.equal(photoQuality(new Uint8ClampedArray(), 0, 0).bonus, 0));
