export const FILTERS = [
  {
    id: "warm",
    name: "Warm CCD",
    css: "sepia(.24) saturate(.85) contrast(.94) brightness(1.06)",
    warm: 14,
    saturation: 0.82,
    contrast: 0.94,
    light: 5,
    grain: 12,
  },
  {
    id: "flash",
    name: "Soft Flash",
    css: "saturate(.65) contrast(.88) brightness(1.2)",
    warm: 3,
    saturation: 0.65,
    contrast: 0.88,
    light: 23,
    grain: 15,
  },
  {
    id: "mint",
    name: "Mint Day",
    css: "sepia(.12) saturate(.65) hue-rotate(20deg) brightness(1.06)",
    warm: -9,
    saturation: 0.65,
    contrast: 0.92,
    light: 9,
    grain: 10,
  },
  {
    id: "mono",
    name: "Mono 2006",
    css: "grayscale(1) contrast(1.1)",
    warm: 0,
    saturation: 0,
    contrast: 1.1,
    light: 2,
    grain: 18,
  },
];
// Local technical estimate only: no semantic food detection or aesthetic AI.
export function photoQuality(pixels, width, height) {
  let sum = 0,
    sum2 = 0,
    edges = 0,
    count = 0;
  const luma = [];
  for (let i = 0; i < pixels.length; i += 4) {
    const l =
      0.2126 * pixels[i] + 0.7152 * pixels[i + 1] + 0.0722 * pixels[i + 2];
    luma.push(l);
    sum += l;
    sum2 += l * l;
    count++;
  }
  if (!count || width * height !== count)
    return { bonus: 0, light: 0, detail: 0 };
  const avg = sum / count;
  const variance = Math.max(0, sum2 / count - avg * avg);
  for (let y = 1; y < height; y++)
    for (let x = 1; x < width; x++) {
      const p = y * width + x;
      edges +=
        Math.abs(luma[p] - luma[p - 1]) + Math.abs(luma[p] - luma[p - width]);
    }
  const light = Math.max(0, 1 - Math.abs(avg - 132) / 115);
  const detail =
    Math.min(1, Math.sqrt(variance) / 55) * 0.5 +
    Math.min(1, edges / (Math.max(1, (width - 1) * (height - 1)) * 35)) * 0.5;
  return { bonus: Math.round(light * 5 + detail * 5), light, detail };
}
export function rewardFor(mode, quality) {
  return (
    (mode === "food" ? 20 : 12) +
    Math.max(0, Math.min(10, Number(quality.bonus) || 0))
  );
}
export function growthFor(xp) {
  const safe = Math.max(0, Number(xp) || 0);
  return {
    level: 1 + Math.floor(safe / 100),
    progress: safe % 100,
    size: (1 + Math.sqrt(safe) * 0.065).toFixed(1),
  };
}
export function applyFilm(data, filter, random = Math.random) {
  for (let i = 0; i < data.length; i += 4) {
    let r = data[i],
      g = data[i + 1],
      b = data[i + 2];
    const l = 0.299 * r + 0.587 * g + 0.114 * b;
    const grain = (random() - 0.5) * filter.grain;
    data[i] =
      (l + (r - l) * filter.saturation - 128) * filter.contrast +
      128 +
      filter.light +
      filter.warm +
      grain;
    data[i + 1] =
      (l + (g - l) * filter.saturation - 128) * filter.contrast +
      128 +
      filter.light +
      grain;
    data[i + 2] =
      (l + (b - l) * filter.saturation - 128) * filter.contrast +
      128 +
      filter.light -
      filter.warm +
      grain;
  }
  return data;
}
