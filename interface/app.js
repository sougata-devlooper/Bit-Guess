/**
 * app.js — BitGuess Web App
 *
 * 3-Page Architecture mirrors Flutter screens:
 *   Page 1 (HOME)   ↔  Home screen + difficulty picker
 *   Page 2 (GAME)   ↔  GameScreen widget
 *   Page 3 (RESULT) ↔  Win/Lose result screen
 *
 * Theme ripple  ↔  Flutter animated theme transition
 * PixelBgPainter ↔  Canvas pixel background
 * ConfettiWidget ↔  Canvas confetti
 */
"use strict";

// ════════════════════════════════════════════════════
// 1. DIFFICULTY CONFIG  (mirrors GameConfig map)
// ════════════════════════════════════════════════════
const DIFFICULTIES = {
  easy:   { max: 50,  attempts: 12, hints: 3, label: "Easy (1–50) · 12 tries · 3 hints" },
  medium: { max: 100, attempts: 8,  hints: 2, label: "Medium (1–100) · 8 tries · 2 hints" },
  hard:   { max: 200, attempts: 6,  hints: 1, label: "Hard (1–200) · 6 tries · 1 hint" },
};

// ════════════════════════════════════════════════════
// 2. GAME STATE  (mirrors GameState class)
// ════════════════════════════════════════════════════
const state = {
  difficulty:    "medium",
  rangeMax:      100,
  maxAttempts:   8,
  hintsLeft:     2,
  attempts:      0,
  history:       [],
  won:           false,
  over:          false,
  startTime:     null,
  currentScore:  0,
  bestScores:    {},
  message:       "Guess between 1-100!",
  messageStatus: "normal",
  targetNumber:  null,
  elapsed:       0,
};

// ════════════════════════════════════════════════════
// 3. DOM REFS
// ════════════════════════════════════════════════════
const $ = id => document.getElementById(id);
const html = document.documentElement;

// Pages
const pageHome   = $("page-home");
const pageGame   = $("page-game");
const pageResult = $("page-result");

// Theme toggles (one per page)
const themeToggles = [
  $("theme-toggle-home"),
  $("theme-toggle-game"),
  $("theme-toggle-result"),
];

// Home page
const homeDiffBtns   = document.querySelectorAll("#home-difficulty-bar .diff-btn");
const diffLabel      = $("diff-label");
const startBtn       = $("start-btn");

// Game page
const gameContainer  = $("game-container");
const statAttempts   = $("stat-attempts");
const statRemaining  = $("stat-remaining");
const statHints      = $("stat-hints");
const messageBox     = $("message-box");
const messageText    = $("message-text");
const guessInput     = $("guess-input");
const guessBtn       = $("guess-btn");
const hintBtn        = $("hint-btn");
const resetBtn       = $("reset-btn");
const historySection = $("history-section");
const historyTrack   = $("history-track");

// Result page
const resultContainer = $("result-container");
const resultStatus    = $("result-status");
const resultNumber    = $("result-number");
const resultNumVal    = $("result-num-val");
const resultScoreBox  = $("result-score-box");
const resultScore     = $("result-score");
const resultDetail    = $("result-detail");
const resultTries     = $("result-tries");
const resultTime      = $("result-time");
const resultBest      = $("result-best");
const playAgainBtn    = $("play-again-btn");
const homeBtn         = $("home-btn");

// Hint toast
const hintToast = $("hint-toast");

// Ripple
const ripple = $("theme-ripple");

// Canvases
const bgCanvas      = $("bg-canvas");
const confettiCanvas = $("confetti-canvas");

// ════════════════════════════════════════════════════
// 4. PAGE NAVIGATION  (mirrors Flutter Navigator)
// ════════════════════════════════════════════════════
let currentPage = pageHome;

function goToPage(targetPage) {
  if (targetPage === currentPage) return;

  const prev = currentPage;
  currentPage = targetPage;

  // Fade out current page
  prev.style.opacity   = "0";
  prev.style.transform = "translateX(-50px)";

  setTimeout(() => {
    prev.style.display = "none";
    prev.style.opacity   = "";
    prev.style.transform = "";

    // Fade in target
    targetPage.style.display   = "flex";
    targetPage.style.opacity   = "0";
    targetPage.style.transform = "translateX(50px)";

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        targetPage.style.transition = "opacity 0.3s ease, transform 0.3s ease";
        targetPage.style.opacity   = "1";
        targetPage.style.transform = "translateX(0)";
        setTimeout(() => {
          targetPage.style.transition = "";
        }, 320);
      });
    });
  }, 280);
}

// ════════════════════════════════════════════════════
// 5. THEME RIPPLE ANIMATION  (mirrors Flutter theme anim)
// ════════════════════════════════════════════════════
function isDark() {
  return html.getAttribute("data-theme") === "dark";
}

function toggleTheme(fromButton) {
  // Compute ripple start position
  const rect   = fromButton ? fromButton.getBoundingClientRect() : { left: window.innerWidth - 60, top: 30, width: 44, height: 44 };
  const cx     = rect.left + rect.width / 2;
  const cy     = rect.top  + rect.height / 2;
  const maxR   = Math.hypot(Math.max(cx, window.innerWidth - cx), Math.max(cy, window.innerHeight - cy)) * 2;

  // Set ripple colour = the NEW theme's bg
  const newDark    = !isDark();
  const rippleColor = newDark ? "#2e0249" : "#4ade80";

  ripple.style.cssText = `
    width: ${maxR}px;
    height: ${maxR}px;
    left: ${cx - maxR / 2}px;
    top:  ${cy - maxR / 2}px;
    background: ${rippleColor};
    transform: scale(0);
    opacity: 1;
    transition: transform 0.55s cubic-bezier(0.4,0,0.2,1), opacity 0.1s;
  `;

  // Expand ripple
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      ripple.style.transform = "scale(1)";
    });
  });

  // Switch theme halfway through
  setTimeout(() => {
    html.setAttribute("data-theme", newDark ? "dark" : "light");
    const icon = newDark ? "☀️" : "🌙";
    themeToggles.forEach(btn => { btn.textContent = icon; });
  }, 280);

  // Fade ripple out
  setTimeout(() => {
    ripple.style.opacity = "0";
    setTimeout(() => {
      ripple.style.transform = "scale(0)";
      ripple.style.opacity   = "1";
    }, 180);
  }, 520);
}

themeToggles.forEach(btn => {
  btn.addEventListener("click", () => toggleTheme(btn));
});

// ════════════════════════════════════════════════════
// 6. PIXEL BACKGROUND  (mirrors PixelBgPainter)
// ════════════════════════════════════════════════════
(function initPixelBg() {
  const ctx = bgCanvas.getContext("2d");
  let offset = 0;

  function resize() {
    bgCanvas.width  = window.innerWidth;
    bgCanvas.height = window.innerHeight;
  }
  window.addEventListener("resize", resize);
  resize();

  function draw() {
    const dark = isDark();
    ctx.clearRect(0, 0, bgCanvas.width, bgCanvas.height);
    ctx.fillStyle = dark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)";
    const tile = 60;
    const cur  = (offset % 1) * tile;
    for (let y = -tile; y < bgCanvas.height + tile; y += tile) {
      for (let x = -tile; x < bgCanvas.width + tile; x += tile) {
        ctx.fillRect(x + cur,            y + cur,            tile / 2, tile / 2);
        ctx.fillRect(x + tile / 2 + cur, y + tile / 2 + cur, tile / 2, tile / 2);
      }
    }
    offset += 1 / (60 * 8);
    requestAnimationFrame(draw);
  }
  draw();
})();

// ════════════════════════════════════════════════════
// 7. CONFETTI  (mirrors ConfettiWidget — square pixels)
// ════════════════════════════════════════════════════
(function initConfetti() {
  const ctx    = confettiCanvas.getContext("2d");
  const colors = ["#facc15","#f472b6","#38bdf8","#4ade80","#e94560","#ff2e63"];
  let particles = [];
  let running   = false;

  function resize() {
    confettiCanvas.width  = window.innerWidth;
    confettiCanvas.height = window.innerHeight;
  }
  window.addEventListener("resize", resize);
  resize();

  window.launchConfetti = function() {
    particles = Array.from({ length: 140 }, () => ({
      x:    Math.random() * confettiCanvas.width,
      y:    -10 - Math.random() * 200,
      w:    8 + Math.random() * 8,
      h:    8 + Math.random() * 8,
      color: colors[Math.floor(Math.random() * colors.length)],
      vx:   (Math.random() - 0.5) * 5,
      vy:   1.5 + Math.random() * 4,
      rot:  Math.random() * 360,
      rotV: (Math.random() - 0.5) * 10,
    }));
    if (!running) { running = true; animLoop(); }
  };

  function animLoop() {
    ctx.clearRect(0, 0, confettiCanvas.width, confettiCanvas.height);
    particles.forEach(p => {
      p.x += p.vx; p.y += p.vy; p.rot += p.rotV;
      ctx.save();
      ctx.translate(p.x + p.w / 2, p.y + p.h / 2);
      ctx.rotate((p.rot * Math.PI) / 180);
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      ctx.restore();
    });
    particles = particles.filter(p => p.y < confettiCanvas.height + 60);
    if (particles.length > 0) {
      requestAnimationFrame(animLoop);
    } else {
      running = false;
      ctx.clearRect(0, 0, confettiCanvas.width, confettiCanvas.height);
    }
  }
})();

// ════════════════════════════════════════════════════
// 8. HOME PAGE LOGIC
// ════════════════════════════════════════════════════
let selectedDiff = "medium";

homeDiffBtns.forEach(btn => {
  btn.addEventListener("click", () => {
    selectedDiff = btn.dataset.diff;
    homeDiffBtns.forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    diffLabel.textContent = DIFFICULTIES[selectedDiff].label;
  });
});

startBtn.addEventListener("click", () => {
  startGame(selectedDiff);
  goToPage(pageGame);
});

// ════════════════════════════════════════════════════
// 9. GAME PAGE RENDER  (mirrors GameScreen build)
// ════════════════════════════════════════════════════
function renderGame() {
  // Stats
  statAttempts.textContent = state.attempts;
  if (state.over && !state.won)  statRemaining.textContent = "DEAD";
  else if (state.won)            statRemaining.textContent = "WIN";
  else                           statRemaining.textContent = state.maxAttempts - state.attempts;
  statHints.textContent = state.hintsLeft;

  // Message
  messageText.textContent = state.message;
  messageBox.className    = "message-box";
  if (state.messageStatus === "win")  messageBox.classList.add("win");
  if (state.messageStatus === "lose") messageBox.classList.add("lose");

  // Input / buttons
  guessInput.disabled   = state.over;
  guessBtn.disabled     = state.over;
  guessBtn.classList.toggle("disabled", state.over);

  const hintDisabled = state.over || state.hintsLeft <= 0;
  hintBtn.textContent = `HINT(${state.hintsLeft})`;
  hintBtn.disabled = hintDisabled;
  hintBtn.classList.toggle("disabled", hintDisabled);

  guessInput.placeholder = `1-${state.rangeMax}`;
  guessInput.max         = state.rangeMax;

  // History
  if (state.history.length > 0) {
    historySection.style.display = "";
    historyTrack.innerHTML = "";
    state.history.forEach(pip => {
      const el = document.createElement("div");
      el.className   = "history-pip " + pip.direction;
      el.textContent = pip.guess;
      historyTrack.appendChild(el);
    });
    historyTrack.scrollTop = historyTrack.scrollHeight;
  } else {
    historySection.style.display = "none";
  }
}

// ════════════════════════════════════════════════════
// 10. RESULT PAGE RENDER
// ════════════════════════════════════════════════════
function showResultPage() {
  if (state.won) {
    // Win state
    resultStatus.textContent = "🎉 YOU WIN!";
    resultStatus.className   = "result-status";
    resultScoreBox.className = "result-score-box";
    resultScore.textContent  = "SCORE: " + state.currentScore;
    const best = state.bestScores[state.difficulty] || 0;
    const bestLabel = (state.currentScore >= best) ? "🏆 NEW BEST!" : `BEST: ${best}`;
    resultDetail.textContent = bestLabel;
    resultScore.style.color  = "var(--success-text)";
    resultDetail.style.color = "var(--success-text)";
  } else {
    // Lose state
    resultStatus.textContent = "💀 GAME OVER!";
    resultStatus.className   = "result-status lose-status";
    resultScoreBox.className = "result-score-box lose-box";
    resultScore.textContent  = "BETTER LUCK!";
    resultDetail.textContent = "Try again!";
  }

  resultNumVal.textContent = state.targetNumber ?? "?";
  resultTries.textContent  = state.attempts;
  resultTime.textContent   = state.elapsed.toFixed(1) + "S";
  const best = state.bestScores[state.difficulty] || 0;
  resultBest.textContent   = best;

  goToPage(pageResult);

  if (state.won) {
    window.launchConfetti();
    // Pulse the result container
    resultContainer.classList.remove("win-pulse");
    void resultContainer.offsetWidth;
    resultContainer.classList.add("win-pulse");
  }
}

// ════════════════════════════════════════════════════
// 11. GAME ACTIONS  (Flask API calls)
// ════════════════════════════════════════════════════
async function startGame(difficulty) {
  const res  = await fetch("/start", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ difficulty }),
  });
  const data = await res.json();

  state.difficulty   = difficulty;
  state.rangeMax     = data.range_max;
  state.maxAttempts  = data.max_attempts;
  state.hintsLeft    = data.hints;
  state.attempts     = 0;
  state.history      = [];
  state.won          = false;
  state.over         = false;
  state.startTime    = Date.now();
  state.currentScore = 0;
  state.elapsed      = 0;
  state.targetNumber = null;
  state.message      = `Guess between 1-${data.range_max}!`;
  state.messageStatus= "normal";

  guessInput.value = "";
  renderGame();
  setTimeout(() => guessInput.focus(), 400);
}

async function makeGuess() {
  if (state.over) return;
  const raw   = guessInput.value.trim();
  if (!raw)     return;
  const guess = parseInt(raw, 10);
  if (isNaN(guess)) return;

  const res  = await fetch("/guess", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ guess }),
  });
  const data = await res.json();

  guessInput.value   = "";
  state.message      = data.message;

  if (data.status === "win") {
    state.won          = true;
    state.over         = true;
    state.attempts     = data.attempts;
    state.currentScore = data.score;
    state.elapsed      = data.time;
    state.messageStatus= "win";
    state.targetNumber = guess; // it was correct
    if (data.best_score !== undefined) {
      state.bestScores[state.difficulty] = data.best_score;
    }
    await syncHistory();
    renderGame();
    // Brief delay then go to result page
    setTimeout(() => showResultPage(), 900);
    return;

  } else if (data.status === "lose") {
    state.over         = true;
    state.attempts     = data.attempts;
    state.elapsed      = (Date.now() - state.startTime) / 1000;
    state.messageStatus= "lose";
    triggerShake();
    await syncHistory();
    renderGame();
    // Brief delay then go to result page
    setTimeout(() => showResultPage(), 900);
    return;

  } else if (data.status === "error") {
    state.messageStatus = "error";
    triggerShake();
  } else {
    state.attempts      = data.attempts;
    state.messageStatus = "wrong";
  }

  await syncHistory();
  renderGame();
  guessInput.focus();
}

async function requestHint() {
  if (state.over || state.hintsLeft <= 0) return;

  const res  = await fetch("/hint", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  const data = await res.json();

  state.hintsLeft = data.hints_left;
  showHintToast(data.hint);
  renderGame();
}

async function syncHistory() {
  try {
    const res  = await fetch("/stats");
    const data = await res.json();
    state.history = data.history || [];
    // Grab target from history if game over
    if (data.target) state.targetNumber = data.target;
  } catch (_) {}
}

// ════════════════════════════════════════════════════
// 12. ANIMATIONS
// ════════════════════════════════════════════════════
function triggerShake() {
  gameContainer.classList.remove("shake");
  void gameContainer.offsetWidth;
  gameContainer.classList.add("shake");
  gameContainer.addEventListener("animationend", () => {
    gameContainer.classList.remove("shake");
  }, { once: true });
}

let toastTimer = null;
function showHintToast(text) {
  hintToast.textContent = text;
  hintToast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => hintToast.classList.remove("show"), 3500);
}

// ════════════════════════════════════════════════════
// 13. EVENT LISTENERS
// ════════════════════════════════════════════════════
guessBtn.addEventListener("click", makeGuess);
guessInput.addEventListener("keydown", e => { if (e.key === "Enter") makeGuess(); });
hintBtn.addEventListener("click", requestHint);
resetBtn.addEventListener("click", () => { startGame(state.difficulty).then(() => goToPage(pageGame)); });

// Result page buttons
playAgainBtn.addEventListener("click", () => {
  startGame(state.difficulty).then(() => goToPage(pageGame));
});
homeBtn.addEventListener("click", () => {
  goToPage(pageHome);
});

// ════════════════════════════════════════════════════
// 14. HOME DIFF BUTTONS + START
// ════════════════════════════════════════════════════
homeDiffBtns.forEach(btn => {
  btn.addEventListener("click", () => {
    selectedDiff = btn.dataset.diff;
    homeDiffBtns.forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    diffLabel.textContent = DIFFICULTIES[selectedDiff].label;
  });
});

startBtn.addEventListener("click", async () => {
  startBtn.disabled = true;
  startBtn.textContent = "LOADING...";
  await startGame(selectedDiff);
  startBtn.disabled = false;
  startBtn.textContent = "▶ START GAME";
  goToPage(pageGame);
});

// ════════════════════════════════════════════════════
// 15. BOOT
// ════════════════════════════════════════════════════
diffLabel.textContent = DIFFICULTIES["medium"].label;
pageHome.style.display   = "flex";
pageGame.style.display   = "none";
pageResult.style.display = "none";
