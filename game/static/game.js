"use strict";

// colours match what the model was trained on: light strokes on a dark sky
const SKY = "rgb(8, 10, 24)";
const INK = "#78beff";
const PREVIEW_SECONDS = 4;
const NEXT_DELAY_MS = 1800;

const $ = (id) => document.getElementById(id);
const board = $("board");
const ctx = board.getContext("2d");
const previewCanvas = $("preview");
const pctx = previewCanvas.getContext("2d");

let game = null;
let mode = "draw";
let locked = true;
let busy = false;
let penSeen = false;
let stroke = null;
let countdownTimer = null;

function resize() {
  // keep the drawing when the ipad rotates
  const snapshot = board.width ? ctx.getImageData(0, 0, board.width, board.height) : null;
  const ratio = window.devicePixelRatio || 1;
  const { width, height } = board.getBoundingClientRect();
  for (const c of [board, previewCanvas]) {
    c.width = Math.round(width * ratio);
    c.height = Math.round(height * ratio);
  }
  clearBoard();
  if (snapshot) ctx.putImageData(snapshot, 0, 0);
  if (game && game.target && !$("preview-caption").classList.contains("hidden")) drawPreview(game.target);
}

function clearBoard() {
  ctx.fillStyle = SKY;
  ctx.fillRect(0, 0, board.width, board.height);
}

function brushWidth() {
  const base = Math.min(board.width, board.height) * 0.009;
  return mode === "erase" ? base * 6 : Math.max(2, base);
}

function point(e) {
  const r = board.getBoundingClientRect();
  return { x: (e.clientX - r.left) * (board.width / r.width), y: (e.clientY - r.top) * (board.height / r.height) };
}

function strokeStyle() {
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.lineWidth = brushWidth();
  ctx.strokeStyle = mode === "erase" ? SKY : INK;
}

board.addEventListener("pointerdown", (e) => {
  if (locked || busy) return;
  if (e.pointerType === "pen") penSeen = true;
  // once a pencil is used, ignore the palm resting on the screen
  if (penSeen && e.pointerType === "touch") return;
  board.setPointerCapture(e.pointerId);
  stroke = { id: e.pointerId, last: point(e), mid: point(e) };
  strokeStyle();
  ctx.beginPath();
  ctx.arc(stroke.last.x, stroke.last.y, ctx.lineWidth / 2, 0, Math.PI * 2);
  ctx.fillStyle = ctx.strokeStyle;
  ctx.fill();
});

board.addEventListener("pointermove", (e) => {
  if (!stroke || e.pointerId !== stroke.id) return;
  const events = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
  strokeStyle();
  for (const ev of events) {
    const p = point(ev);
    const mid = { x: (stroke.last.x + p.x) / 2, y: (stroke.last.y + p.y) / 2 };
    // quadratic curves through midpoints smooth out jittery pointer samples
    ctx.beginPath();
    ctx.moveTo(stroke.mid.x, stroke.mid.y);
    ctx.quadraticCurveTo(stroke.last.x, stroke.last.y, mid.x, mid.y);
    ctx.stroke();
    stroke.last = p;
    stroke.mid = mid;
  }
});

const endStroke = (e) => {
  if (!stroke || e.pointerId !== stroke.id) return;
  strokeStyle();
  ctx.beginPath();
  ctx.moveTo(stroke.mid.x, stroke.mid.y);
  ctx.lineTo(stroke.last.x, stroke.last.y);
  ctx.stroke();
  stroke = null;
};
board.addEventListener("pointerup", endStroke);
board.addEventListener("pointercancel", endStroke);

function setMode(next) {
  mode = next;
  $("draw-btn").classList.toggle("active", mode === "draw");
  $("erase-btn").classList.toggle("active", mode === "erase");
}

function grade(points) {
  return points >= 70 ? "good" : points >= 30 ? "okay" : "bad";
}

function renderHud() {
  $("points").textContent = game.points;
  $("rounds").textContent = game.rounds;
}

function setLocked(value) {
  locked = value;
  for (const id of ["draw-btn", "erase-btn", "clear-btn", "submit-btn"]) $(id).disabled = value || busy;
}

function drawPreview(target) {
  const w = previewCanvas.width;
  const h = previewCanvas.height;
  pctx.clearRect(0, 0, w, h);
  pctx.fillStyle = "rgba(8, 10, 24, 0.94)";
  pctx.fillRect(0, 0, w, h);
  // keep the shape clear of the caption box at the bottom
  const size = Math.min(w, h * 0.72) * 0.85;
  const ox = (w - size) / 2;
  const oy = (h * 0.78 - size) / 2;
  const pts = target.stars.map(([x, y]) => [ox + x * size, oy + y * size]);
  pctx.strokeStyle = "#fbbf24";
  pctx.lineWidth = Math.max(2, Math.min(w, h) * 0.006);
  pctx.lineCap = "round";
  for (const [i, j] of target.edges) {
    pctx.beginPath();
    pctx.moveTo(...pts[i]);
    pctx.lineTo(...pts[j]);
    pctx.stroke();
  }
  pctx.fillStyle = "#fff6d5";
  for (const [x, y] of pts) {
    pctx.beginPath();
    pctx.arc(x, y, pctx.lineWidth * 1.3, 0, Math.PI * 2);
    pctx.fill();
  }
}

function hidePreview() {
  clearInterval(countdownTimer);
  pctx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
  $("preview-caption").classList.add("hidden");
  setLocked(false);
}

function showTarget() {
  clearBoard();
  setMode("draw");
  renderHud();
  $("round").textContent = game.round;
  $("target-name").textContent = game.target.name;
  setLocked(true);
  drawPreview(game.target);
  $("preview-name").textContent = game.target.name;
  $("preview-caption").classList.remove("hidden");
  let left = PREVIEW_SECONDS;
  $("countdown").textContent = left;
  clearInterval(countdownTimer);
  countdownTimer = setInterval(() => {
    left -= 1;
    $("countdown").textContent = left;
    if (left <= 0) hidePreview();
  }, 1000);
}

function showBanner(result) {
  const banner = $("banner");
  const name = result.answer.split(" – ")[0];
  banner.className = grade(result.points_earned);
  banner.innerHTML =
    `+${result.points_earned} points — the judge was ${result.points_earned}% sure this is ${name}` +
    `<div class="detail">it thought: ${result.top3.map(([n, p]) => `${n.split(" – ")[0]} ${Math.round(p * 100)}%`).join(", ")}</div>`;
}

function showGameOver() {
  $("final-score").textContent = game.points;
  $("final-total").textContent = game.rounds * 100;
  const list = $("history");
  list.innerHTML = "";
  for (const h of game.history) {
    const li = document.createElement("li");
    li.className = grade(h.points);
    li.innerHTML = `<span></span><span class="pts">${h.points}</span>`;
    li.firstChild.textContent = h.target.split(" – ")[0];
    list.appendChild(li);
  }
  $("gameover").classList.remove("hidden");
}

async function api(path, body) {
  const res = await fetch(path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body || {}) });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

async function startGame() {
  $("start").classList.add("hidden");
  $("gameover").classList.add("hidden");
  $("banner").classList.add("hidden");
  game = await api("/api/new");
  showTarget();
}

async function submit() {
  if (locked || busy) return;
  busy = true;
  setLocked(true);
  try {
    const result = await api("/api/submit", { game_id: game.game_id, image: board.toDataURL("image/png") });
    game = result;
    renderHud();
    showBanner(result);
    setTimeout(() => {
      $("banner").classList.add("hidden");
      busy = false;
      if (game.game_over) showGameOver();
      else showTarget();
    }, NEXT_DELAY_MS);
  } catch (err) {
    busy = false;
    setLocked(false);
    const banner = $("banner");
    banner.className = "bad";
    banner.textContent = err.message;
    setTimeout(() => banner.classList.add("hidden"), 1500);
  }
}

$("draw-btn").onclick = () => setMode("draw");
$("erase-btn").onclick = () => setMode("erase");
$("clear-btn").onclick = clearBoard;
$("submit-btn").onclick = submit;
$("skip-preview").onclick = hidePreview;
$("start-btn").onclick = startGame;
$("again-btn").onclick = startGame;
window.addEventListener("resize", resize);
resize();
setLocked(true);
