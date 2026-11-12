import {
  FILTERS,
  photoQuality,
  rewardFor,
  growthFor,
  applyFilm,
} from "./core.js";
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
let state = { name: "모리", xp: 0, moments: 0, created: Date.now() };
let storageOK = true;
try {
  const raw = JSON.parse(localStorage.getItem("scoo-state-v1") || "null");
  if (
    raw &&
    typeof raw.name === "string" &&
    Number.isFinite(raw.xp) &&
    Number.isFinite(raw.moments)
  )
    state = {
      ...state,
      ...raw,
      xp: Math.max(0, raw.xp),
      moments: Math.max(0, raw.moments),
    };
} catch {
  storageOK = false;
}
let filterIndex = 0,
  mode = "daily",
  dateOn = true,
  flashOn = false,
  zoom = 1,
  stream = null,
  facing = "environment",
  source = "sample",
  busy = false,
  photos = [],
  selected = null,
  toastTimer = null,
  db = null,
  objectUrl = null;
function toast(message) {
  $("#toast").textContent = message;
  $("#toast").classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => $("#toast").classList.remove("visible"), 3500);
}
function saveState() {
  try {
    localStorage.setItem("scoo-state-v1", JSON.stringify(state));
    return true;
  } catch {
    storageOK = false;
    return false;
  }
}
function dateString(time = Date.now()) {
  const d = new Date(time);
  return `${String(d.getFullYear()).slice(2)}. ${String(d.getMonth() + 1).padStart(2, "0")}. ${String(d.getDate()).padStart(2, "0")}`;
}
function renderState() {
  const g = growthFor(state.xp);
  $("#petName").textContent = state.name;
  $("#levelLabel").textContent = `LV. ${String(g.level).padStart(2, "0")}`;
  $("#dayLabel").textContent =
    `DAY ${String(Math.max(1, Math.floor((Date.now() - state.created) / 86400000) + 1)).padStart(2, "0")}`;
  $("#xpLabel").textContent = `${g.progress} / 100`;
  $("#growthFill").style.width = `${g.progress}%`;
  $("#momentStat").innerHTML = `${state.moments} <small>컷</small>`;
  $("#sizeStat").innerHTML = `${g.size} <small>cm</small>`;
  $("#moodStat").textContent = state.moments ? "몽글몽글" : "두근두근";
  $("#photoCount").textContent = String(state.moments).padStart(4, "0");
  const size = Math.min(160, 125 + Math.sqrt(state.xp) * 0.6);
  $("#marimo").style.width = `${size}px`;
  $("#marimo").style.height = `${size}px`;
}
function paintMarimo() {
  const c = $("#marimo"),
    ctx = c.getContext("2d");
  ctx.clearRect(0, 0, 420, 420);
  let seed = 4182;
  const rnd = () => {
    seed = (seed * 16807) % 2147483647;
    return (seed - 1) / 2147483646;
  };
  const cx = 210,
    cy = 220,
    r = 143;
  const gradient = ctx.createRadialGradient(167, 158, 12, cx, cy, r);
  gradient.addColorStop(0, "#7da64e");
  gradient.addColorStop(0.45, "#4f7b32");
  gradient.addColorStop(0.8, "#315729");
  gradient.addColorStop(1, "#1b3c26");
  ctx.fillStyle = gradient;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
  for (let i = 0; i < 17000; i++) {
    const a = rnd() * Math.PI * 2,
      d = Math.sqrt(rnd()) * (r + 2);
    const x = cx + Math.cos(a) * d,
      y = cy + Math.sin(a) * d;
    const brightness = (1 - (x - 80 + y - 70) / 620) * 38;
    const light = 20 + brightness + rnd() * 15;
    ctx.strokeStyle = `hsla(${85 + rnd() * 35},${28 + rnd() * 25}%,${light}%,${0.4 + rnd() * 0.55})`;
    ctx.lineWidth = 0.45 + rnd() * 1.5;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + Math.cos(a) * 3 + (rnd() - 0.5) * 6, y - 3 - rnd() * 9);
    ctx.stroke();
  }
  ctx.fillStyle = "#142e20";
  for (const x of [180, 241]) {
    ctx.beginPath();
    ctx.ellipse(x, 229, 5, 6.8, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#e4eecb";
    ctx.beginPath();
    ctx.arc(x - 1, 227, 1.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#142e20";
  }
  ctx.strokeStyle = "#203e25";
  ctx.lineWidth = 2.5;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.arc(211, 236, 8, 0.2, Math.PI - 0.2);
  ctx.stroke();
  ctx.fillStyle = "#e4bda43d";
  [164, 257].forEach((x) => {
    ctx.beginPath();
    ctx.ellipse(x, 244, 10, 5, 0, 0, Math.PI * 2);
    ctx.fill();
  });
}
function setFilter(i) {
  filterIndex = (i + FILTERS.length) % FILTERS.length;
  const f = FILTERS[filterIndex];
  $("#viewfinder").style.setProperty("--photo-filter", f.css);
  $("#screenFilter").textContent = f.name.toUpperCase();
  $$(".filter-option").forEach((el, n) => {
    el.classList.toggle("active", n === filterIndex);
    el.setAttribute("aria-pressed", String(n === filterIndex));
  });
}
FILTERS.forEach((f, i) => {
  const btn = document.createElement("button");
  btn.className = "filter-option";
  btn.innerHTML = `<div class="filter-thumb" style="filter:${f.css}"></div><span>${f.name}<small class="filter-index">0${i + 1}</small></span>`;
  btn.onclick = () => setFilter(i);
  $("#filters").append(btn);
});
function showSource(which) {
  source = which;
  $("#sample").hidden = which !== "sample";
  $("#video").hidden = which !== "camera";
  $("#imported").hidden = which !== "imported";
  $("#screenCenter").hidden = which !== "sample";
  $("#cameraHint").textContent =
    which === "sample"
      ? "셔터를 누르면 샘플 장면으로 체험할 수 있어요."
      : which === "camera"
        ? "준비됐으면, 오늘의 한 컷을 찰칵."
        : "불러온 사진도 셔터를 눌러 마리모에게 선물해요.";
}
function stopCamera() {
  if (stream) stream.getTracks().forEach((t) => t.stop());
  stream = null;
  $("#video").srcObject = null;
}
async function startCamera() {
  if (busy) return;
  if (!navigator.mediaDevices?.getUserMedia) {
    toast(
      "카메라는 HTTPS 또는 localhost에서 열어 주세요. 사진 불러오기도 가능해요.",
    );
    return;
  }
  busy = true;
  $("#startCamera").disabled = true;
  stopCamera();
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: { ideal: facing },
        width: { ideal: 1600 },
        height: { ideal: 1200 },
      },
      audio: false,
    });
    $("#video").srcObject = stream;
    await $("#video").play();
    showSource("camera");
    $("#power").setAttribute("aria-label", "카메라 끄기");
    toast("카메라 준비 완료. 오늘의 빛을 담아봐요.");
  } catch (error) {
    stopCamera();
    if (source === "camera") showSource("sample");
    const denied = error.name === "NotAllowedError";
    toast(
      denied
        ? "카메라 권한을 허용해 주세요. 앨범 사진도 불러올 수 있어요."
        : "카메라를 열 수 없어요. 앨범 사진으로 시작해 보세요.",
    );
  } finally {
    busy = false;
    $("#startCamera").disabled = false;
  }
}
$("#startCamera").onclick = startCamera;
$("#power").onclick = () => {
  if (stream) {
    stopCamera();
    showSource("sample");
    $("#power").setAttribute("aria-label", "카메라 켜기");
    toast("카메라를 껐어요.");
  } else startCamera();
};
$("#flipCamera").onclick = async () => {
  if (busy) return;
  facing = facing === "environment" ? "user" : "environment";
  await startCamera();
};
$("#prevFilter").onclick = () => setFilter(filterIndex - 1);
$("#nextFilter").onclick = () => setFilter(filterIndex + 1);
function setZoom(n) {
  zoom = Math.max(1, Math.min(3, Math.round(n * 10) / 10));
  $("#viewfinder").style.setProperty("--zoom", zoom);
  $("#zoomValue").textContent = zoom.toFixed(1) + "×";
}
$("#zoomIn").onclick = () => setZoom(zoom + 0.2);
$("#zoomOut").onclick = () => setZoom(zoom - 0.2);
$("#dateToggle").onclick = () => {
  dateOn = !dateOn;
  $("#dateToggle").setAttribute("aria-pressed", String(dateOn));
  $("#dateStamp").textContent = dateOn ? dateString() : "";
  toast(dateOn ? "날짜를 사진에 새겨요." : "날짜 인쇄를 껐어요.");
};
$("#flash").onclick = () => {
  flashOn = !flashOn;
  $("#flashBadge").textContent = flashOn ? "ϟ ON" : "ϟ OFF";
  $("#flash").setAttribute("aria-pressed", String(flashOn));
  toast(flashOn ? "밝은 플래시 느낌을 더해요." : "플래시 효과를 껐어요.");
};
$$("[data-mode]").forEach(
  (btn) =>
    (btn.onclick = () => {
      mode = btn.dataset.mode;
      $$("[data-mode]").forEach((b) => {
        b.classList.toggle("active", b === btn);
        b.setAttribute("aria-pressed", String(b === btn));
      });
      $("#modeBadge").textContent = mode === "food" ? "FOOD" : "AUTO";
      toast(
        mode === "food"
          ? "음식 모드 · 든든한 한 끼 +20"
          : "일상 모드 · 작은 순간 +12",
      );
    }),
);
$("#importButton").onclick = () => $("#fileInput").click();
$("#fileInput").onchange = async (e) => {
  const file = e.target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith("image/")) {
    toast("이미지 파일을 골라 주세요.");
    return;
  }
  if (file.size > 35 * 1024 * 1024) {
    toast("35MB 이하의 사진을 골라 주세요.");
    e.target.value = "";
    return;
  }
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = url;
    await img.decode();
    stopCamera();
    if (objectUrl) URL.revokeObjectURL(objectUrl);
    objectUrl = url;
    $("#imported").src = url;
    showSource("imported");
    setZoom(1);
    toast("사진을 불러왔어요. 색을 고르고 셔터를 눌러요.");
  } catch {
    URL.revokeObjectURL(url);
    toast("이 사진 형식을 열 수 없어요. JPEG 또는 PNG로 다시 골라 주세요.");
  }
  e.target.value = "";
};
function openDB() {
  return new Promise((resolve, reject) => {
    if (!window.indexedDB) {
      reject(new Error("IndexedDB unavailable"));
      return;
    }
    const request = indexedDB.open("scoo-camera-v1", 1);
    request.onupgradeneeded = () => {
      request.result.createObjectStore("photos", { keyPath: "id" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}
function dbRun(action, value) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(
      "photos",
      action === "getAll" ? "readonly" : "readwrite",
    );
    const store = tx.objectStore("photos");
    const req = action === "getAll" ? store.getAll() : store[action](value);
    tx.oncomplete = () => resolve(req.result);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () =>
      reject(tx.error || new Error("Storage transaction aborted"));
  });
}
function drawCrop(ctx, img, w, h) {
  const sw = img.videoWidth || img.naturalWidth,
    sh = img.videoHeight || img.naturalHeight;
  if (!sw || !sh) throw new Error("Image not ready");
  const ratio = w / h;
  let cw = sw,
    ch = sh;
  if (sw / sh > ratio) cw = sh * ratio;
  else ch = sw / ratio;
  cw /= zoom;
  ch /= zoom;
  ctx.drawImage(img, (sw - cw) / 2, (sh - ch) / 2, cw, ch, 0, 0, w, h);
}
function happy() {
  const card = $(".garden-card");
  card.classList.remove("happy");
  requestAnimationFrame(() => card.classList.add("happy"));
  setTimeout(() => card.classList.remove("happy"), 1700);
}
function shutterSound() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    const a = new AudioContext(),
      o = a.createOscillator(),
      g = a.createGain();
    o.type = "triangle";
    o.frequency.setValueAtTime(650, a.currentTime);
    o.frequency.exponentialRampToValueAtTime(90, a.currentTime + 0.07);
    g.gain.setValueAtTime(0.035, a.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, a.currentTime + 0.1);
    o.connect(g);
    g.connect(a.destination);
    o.start();
    o.stop(a.currentTime + 0.12);
    o.onended = () => a.close();
  } catch {}
}
async function capture() {
  if (busy) return;
  busy = true;
  $("#capture").disabled = true;
  try {
    const img =
      source === "camera"
        ? $("#video")
        : source === "imported"
          ? $("#imported")
          : $("#sample");
    if (img instanceof HTMLImageElement) await img.decode();
    const c = document.createElement("canvas");
    c.width = 1200;
    c.height = 900;
    const ctx = c.getContext("2d", { willReadFrequently: true });
    drawCrop(ctx, img, c.width, c.height);
    const small = document.createElement("canvas");
    small.width = 96;
    small.height = 72;
    const sc = small.getContext("2d", { willReadFrequently: true });
    sc.drawImage(c, 0, 0, 96, 72);
    const quality = photoQuality(sc.getImageData(0, 0, 96, 72).data, 96, 72);
    const f = { ...FILTERS[filterIndex] };
    if (flashOn) f.light += 18;
    const pixels = ctx.getImageData(0, 0, 1200, 900);
    applyFilm(pixels.data, f);
    ctx.putImageData(pixels, 0, 0);
    const v = ctx.createRadialGradient(600, 450, 230, 600, 450, 760);
    v.addColorStop(0, "rgba(10,20,8,0)");
    v.addColorStop(1, "rgba(18,24,10,.2)");
    ctx.fillStyle = v;
    ctx.fillRect(0, 0, 1200, 900);
    const time = Date.now();
    if (dateOn) {
      ctx.font = "24px monospace";
      ctx.fillStyle = "#ffc58c";
      ctx.shadowColor = "#4d331d";
      ctx.shadowBlur = 3;
      ctx.textAlign = "right";
      ctx.fillText(dateString(time), 1150, 853);
      ctx.shadowBlur = 0;
    }
    const blob = await new Promise((resolve) =>
      c.toBlob(resolve, "image/jpeg", 0.88),
    );
    if (!blob) throw new Error("Photo export failed");
    const gain = rewardFor(mode, quality);
    const photo = {
      id: crypto.randomUUID?.() || `${time}-${Math.random()}`,
      time,
      blob,
      filter: f.name,
      mode,
      gain,
      bonus: quality.bonus,
      sample: source === "sample",
    };
    // Commit the photo first. Storage failures must not award imaginary permanent growth.
    if (!db) {
      toast("사진 저장소를 쓸 수 없어요. 브라우저 저장 공간을 확인해 주세요.");
      return;
    }
    await dbRun("put", photo);
    photos.unshift({ ...photo, url: URL.createObjectURL(blob) });
    const oldLevel = growthFor(state.xp).level;
    state.xp += gain;
    state.moments += 1;
    const stateSaved = saveState();
    renderState();
    renderAlbum();
    happy();
    shutterSound();
    $("#shutterFlash").classList.remove("fire");
    void $("#shutterFlash").offsetWidth;
    $("#shutterFlash").classList.add("fire");
    $("#petMessage").textContent =
      mode === "food" ? "냠냠, 든든한 순간 고마워!" : "이 빛, 마음에 쏙 들어!";
    const levelUp = growthFor(state.xp).level > oldLevel;
    toast(
      !stateSaved
        ? "사진은 저장했어요. 성장 기록은 저장 공간을 확인해 주세요."
        : levelUp
          ? `무럭무럭! ${state.name}가 LV. ${growthFor(state.xp).level}이 됐어요 🌱`
          : `${source === "sample" ? "샘플 체험 · " : ""}${state.name}에게 +${gain} EXP · 빛·선명도 보너스 +${quality.bonus}`,
    );
  } catch (error) {
    console.error("Capture failed:", error.name);
    toast(
      error.name === "QuotaExceededError"
        ? "저장 공간이 부족해요. 사진을 내려받고 앨범에서 정리해 주세요."
        : "사진을 저장하지 못했어요. 카메라나 이미지를 다시 준비해 주세요.",
    );
  } finally {
    busy = false;
    $("#capture").disabled = false;
  }
}
$("#capture").onclick = capture;
$("#emptyCapture").onclick = () => {
  window.scrollTo({
    top: $(".camera-zone").offsetTop - 20,
    behavior: "smooth",
  });
  toast("가운데 초록 셔터를 눌러보세요.");
};
function renderAlbum() {
  $("#albumTotal").textContent = String(photos.length).padStart(2, "0");
  if (!photos.length) {
    $("#album").innerHTML = "";
    const btn = document.createElement("button");
    btn.className = "empty-photo";
    btn.innerHTML =
      "<span>＋</span><strong>첫 순간을 담아볼까요?</strong><small>작은 기록이 초록을 키워요</small>";
    btn.onclick = () => {
      window.scrollTo({
        top: $(".camera-zone").offsetTop - 20,
        behavior: "smooth",
      });
      toast("가운데 초록 셔터를 눌러보세요.");
    };
    $("#album").append(btn);
    const line = document.createElement("div");
    line.className = "empty-line";
    line.innerHTML = "<span>your everyday, a little greener.</span>";
    $("#album").append(line);
    return;
  }
  $("#album").innerHTML = "";
  photos.forEach((p) => {
    const b = document.createElement("button");
    b.className = "photo-card";
    b.setAttribute("aria-label", `${dateString(p.time)} ${p.filter} 사진 열기`);
    const im = document.createElement("img");
    im.src = p.url;
    im.alt = p.sample
      ? "샘플 체험 사진"
      : p.mode === "food"
        ? "음식 모드 사진"
        : "일상 사진";
    im.loading = "lazy";
    const caption = document.createElement("p");
    const label = document.createElement("span");
    label.textContent = dateString(p.time);
    const xp = document.createElement("strong");
    xp.textContent = `+${p.gain} EXP`;
    caption.append(label, xp);
    b.append(im, caption);
    b.onclick = () => openPhoto(p);
    $("#album").append(b);
  });
}
function openPhoto(p) {
  selected = p;
  $("#fullPhoto").src = p.url;
  $("#photoTitle").textContent = p.filter;
  $("#photoDetail").textContent =
    `${dateString(p.time)} · ${p.sample ? "샘플 체험" : p.mode === "food" ? "음식" : "일상"} · +${p.gain} EXP`;
  $("#photoDialog").showModal();
}
$("#downloadPhoto").onclick = async () => {
  if (!selected) return;
  const file = new File([selected.blob], `scoo-${selected.time}.jpg`, {
    type: "image/jpeg",
  });
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: "SCOO의 작은 순간" });
      return;
    } catch (e) {
      if (e.name === "AbortError") return;
    }
  }
  const a = document.createElement("a");
  a.href = selected.url;
  a.download = file.name;
  document.body.append(a);
  a.click();
  a.remove();
  toast(
    "사진을 내려받아요. iPhone에서는 공유 메뉴로 사진 앱에 저장할 수 있어요.",
  );
};
$("#deletePhoto").onclick = async () => {
  if (!selected || busy || !db) return;
  busy = true;
  $("#deletePhoto").disabled = true;
  try {
    const target = selected;
    await dbRun("delete", target.id);
    photos = photos.filter((p) => p.id !== target.id);
    URL.revokeObjectURL(target.url);
    selected = null;
    $("#photoDialog").close();
    renderAlbum();
    toast("사진을 삭제했어요. 마리모의 성장은 간직해요.");
  } catch {
    toast("삭제하지 못했어요. 다시 시도해 주세요.");
  } finally {
    busy = false;
    $("#deletePhoto").disabled = false;
  }
};
$("#petTouch").onclick = () => {
  happy();
  const lines = [
    "보송보송, 오늘도 잘 자라는 중!",
    "너의 다음 순간이 궁금해.",
    "가끔은 아무것도 안 해도 좋아.",
    "나를 초록으로 키우는 건 너야.",
  ];
  $("#petMessage").textContent =
    lines[Math.floor(Math.random() * lines.length)];
};
$("#aboutOpen").onclick = () => $("#aboutDialog").showModal();
$$("[data-close]").forEach(
  (b) => (b.onclick = () => document.getElementById(b.dataset.close).close()),
);
$$("dialog").forEach((d) =>
  d.addEventListener("click", (e) => {
    if (e.target === d) {
      const r = d.getBoundingClientRect();
      if (
        e.clientX < r.left ||
        e.clientX > r.right ||
        e.clientY < r.top ||
        e.clientY > r.bottom
      )
        d.close();
    }
  }),
);
$("#rename").onclick = () => {
  $("#nameInput").value = state.name;
  $("#renameDialog").showModal();
  $("#nameInput").focus();
};
$("#renameForm").onsubmit = (e) => {
  e.preventDefault();
  const name = $("#nameInput").value.trim();
  if (!name) return;
  state.name = name.slice(0, 12);
  const saved = saveState();
  renderState();
  $("#renameDialog").close();
  toast(
    saved
      ? `안녕, ${state.name}!`
      : "이름을 바꿨어요. 저장 공간을 확인해 주세요.",
  );
};
document.addEventListener("visibilitychange", () => {
  if (document.hidden && stream) {
    stopCamera();
    showSource("sample");
  }
});
window.addEventListener("pagehide", () => {
  stopCamera();
  if (objectUrl) URL.revokeObjectURL(objectUrl);
  photos.forEach((p) => URL.revokeObjectURL(p.url));
});
window.addEventListener("pageshow", (e) => {
  if (e.persisted) location.reload();
});
paintMarimo();
renderState();
setFilter(0);
$("#dateStamp").textContent = dateString();
try {
  db = await openDB();
  const loaded = await dbRun("getAll");
  photos = loaded
    .sort((a, b) => b.time - a.time)
    .map((p) => ({ ...p, url: URL.createObjectURL(p.blob) }));
  renderAlbum();
  if (!storageOK)
    toast("성장 기록을 저장할 수 없어요. 브라우저 저장 설정을 확인해 주세요.");
} catch {
  toast(
    "이 브라우저에서는 사진을 보관할 수 없어요. 저장 공간을 허용해 주세요.",
  );
}
