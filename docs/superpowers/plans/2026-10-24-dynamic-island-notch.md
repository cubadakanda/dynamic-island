# Dynamic Island Desktop (Oceru Style Notch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a sleek, butter-smooth, ultra-lightweight Dynamic Island desktop notch application for Windows 10/11 featuring a temporary file staging shelf, a hybrid YouTube/system music player with lyrics, a Pomodoro focus timer, and dynamic Bluetooth/system event popups.

**Architecture:** A native desktop host running Microsoft Edge WebView2 creates a borderless, transparent, topmost window anchored at `y = 0` (top bezel of the primary screen). The frontend is built with modular modern HTML5/CSS3/ES6 running 60fps spring animations for collapse/expand states, communicating via an IPC bridge with native background services for Windows OLE drag-and-drop, SMTC media session monitoring, and Win32/WinRT Bluetooth and power status telemetry.

**Tech Stack:** Node.js v24.11 / Python 3.13 Host, Microsoft Edge WebView2, HTML5/CSS3 (Hardware-accelerated transitions & backdrop-filter), Windows Win32 API (`WS_EX_TOPMOST`, `WS_EX_LAYERED`), Windows SMTC, YouTube IFrame API.

**Spec:** `docs/superpowers/specs/2026-10-24-dynamic-island-notch-design.md`

## Global Constraints

- Target OS: Windows 10 and Windows 11 (64-bit).
- Anchoring: Pinned directly at `y = 0` (screen top-center), adaptive to Windows DPI scaling (100%, 125%, 150%).
- Idle Memory Target: Under 50–60 MB RAM; idle CPU usage < 0.5%.
- Non-blocking: Window outside the active notch area must remain click-through (`WS_EX_TRANSPARENT` or dynamic hit-test regions) so background windows and desktop icons remain fully usable.
- Local execution: Runs entirely local on the user's laptop without mandatory cloud accounts.

## Review Focus

1. **Mouse Jitter on Collapse/Expand Boundary:** Rapid mouse movements across the top screen edge causing frantic flickering between collapsed and expanded states -> Mitigated by debounced leave timer (300ms delay) and hysteresis padding.
2. **High DPI Display Misalignment:** On 125% or 150% Windows scaling, notch coordinates appearing off-center or clipped -> Explicitly scaled using Windows physical-to-logical pixel scaling factors.
3. **External Drag-and-Drop Staging Loss:** Dragging multiple large files into the shelf and dropping them into apps where source paths might be locked -> Staging references verify path existence and release locks immediately.
4. **YouTube Audio Playback in Background without Focus Stealing:** Playing YouTube audio inside the island must not steal keyboard focus from active code editors or browser windows.
5. **Bluetooth Disconnect / Reconnect Flood:** Rapid device toggles flooding notifications -> Debounced notification queue ensuring toast popups display sequentially with a 3.5s timeout.

---

### Task 1: Project Setup & Native Window Host

**Files:**
- Create: `dynamic-island/package.json`
- Create: `dynamic-island/src/main.js`
- Create: `dynamic-island/src/window-manager.js`
- Test: `dynamic-island/tests/window-manager.test.js`

**Interfaces:**
- Produces: `WindowManager.initWindow() -> WindowInstance`, `WindowManager.setHitTestRegion(width: number, height: number, isExpanded: boolean) -> void`
- Consumes: Windows Win32 API / WebView2 host configuration.

- [ ] **Step 1: Write unit test for WindowManager bounds and scaling calculations**
```javascript
// dynamic-island/tests/window-manager.test.js
const assert = require('assert');
const { calculateWindowBounds } = require('../src/window-manager');

const screen = { width: 1920, height: 1080, scaleFactor: 1.25 };
const collapsed = calculateWindowBounds(screen, false);
assert.strictEqual(collapsed.y, 0);
assert.strictEqual(collapsed.width, 140);
assert.strictEqual(collapsed.x, (1920 - 140) / 2);

const expanded = calculateWindowBounds(screen, true);
assert.strictEqual(expanded.y, 0);
assert.strictEqual(expanded.width, 560);
assert.strictEqual(expanded.height, 190);
console.log('calculateWindowBounds passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/window-manager.test.js`
Expected: FAIL with "Cannot find module '../src/window-manager'"

- [ ] **Step 3: Implement `calculateWindowBounds` and `WindowManager` in `dynamic-island/src/window-manager.js`**
Implement the bounds calculation and the topmost, borderless, transparent window initialization using WebView2 with hit-test region management.

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/window-manager.test.js`
Expected: PASS ("calculateWindowBounds passed")

- [ ] **Step 5: Verify window launch with manual smoke check**
Run: `node dynamic-island/src/main.js --smoke-test`
Expected: Window initializes seamlessly at screen top-center with transparent background and exits cleanly.

---

### Task 2: Notch UI Core, Spring Transitions & Tab Switcher

**Files:**
- Create: `dynamic-island/public/index.html`
- Create: `dynamic-island/public/css/notch.css`
- Create: `dynamic-island/public/js/notch-controller.js`
- Test: `dynamic-island/tests/notch-controller.test.js`

**Interfaces:**
- Produces: `NotchController.setExpanded(expanded: boolean) -> void`, `NotchController.switchTab(tabName: 'shelf' | 'music' | 'pomodoro') -> void`, `NotchController.updateClock() -> void`
- Consumes: WindowManager IPC messages for mouse hover and leave.

- [ ] **Step 1: Write test for tab switching and clock formatting**
```javascript
// dynamic-island/tests/notch-controller.test.js
const assert = require('assert');
const { formatClock, isValidTab } = require('../public/js/notch-controller');

assert.strictEqual(isValidTab('shelf'), true);
assert.strictEqual(isValidTab('music'), true);
assert.strictEqual(isValidTab('pomodoro'), true);
assert.strictEqual(isValidTab('invalid'), false);

const testDate = new Date('2026-10-24T19:21:00');
assert.strictEqual(formatClock(testDate), '19:21');
console.log('notch-controller logic tests passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/notch-controller.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `notch.css` and `notch-controller.js`**
- Create `notch.css` with jet-black `#000` styling, rounded bottom borders, cubic-bezier spring curves (`cubic-bezier(0.16, 1, 0.3, 1)`), tab transitions, and clock formatter.
- Implement `index.html` containing the collapsed pill (clock, status dot) and expanded container (Header with tabs + Bluetooth badge + active tab body).

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/notch-controller.test.js`
Expected: PASS ("notch-controller logic tests passed")

---

### Task 3: File Shelf (Drag & Drop Staging Engine)

**Files:**
- Create: `dynamic-island/src/shelf-engine.js`
- Create: `dynamic-island/public/js/shelf-ui.js`
- Test: `dynamic-island/tests/shelf-engine.test.js`

**Interfaces:**
- Produces: `ShelfEngine.addFiles(paths: string[]) -> FileItem[]`, `ShelfEngine.removeFile(id: string) -> void`, `ShelfEngine.clear() -> void`, `ShelfEngine.getItems() -> FileItem[]`
- Consumes: Windows OLE Drag-and-Drop drop events and file path resolution.

- [ ] **Step 1: Write unit tests for staging files and duplicate prevention**
```javascript
// dynamic-island/tests/shelf-engine.test.js
const assert = require('assert');
const { ShelfEngine } = require('../src/shelf-engine');

const shelf = new ShelfEngine();
const items = shelf.addFiles(['C:\\test\\document.pdf', 'C:\\test\\image.png']);
assert.strictEqual(items.length, 2);
assert.strictEqual(items[0].name, 'document.pdf');
assert.strictEqual(items[1].name, 'image.png');

shelf.removeFile(items[0].id);
assert.strictEqual(shelf.getItems().length, 1);
assert.strictEqual(shelf.getItems()[0].name, 'image.png');

shelf.clear();
assert.strictEqual(shelf.getItems().length, 0);
console.log('shelf-engine tests passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/shelf-engine.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `shelf-engine.js` and `shelf-ui.js`**
- Implement `ShelfEngine` to record file metadata (name, extension, size, formatted size, path) and manage staging references in temporary cache.
- Implement `shelf-ui.js` to render the dashed drop zone when empty, and horizontal scrollable cards with file icons and drag-out handles when files are present.

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/shelf-engine.test.js`
Expected: PASS ("shelf-engine tests passed")

---

### Task 4: Hybrid Music Player (YouTube Audio & Windows SMTC Sync)

**Files:**
- Create: `dynamic-island/src/smtc-monitor.js`
- Create: `dynamic-island/public/js/music-player.js`
- Test: `dynamic-island/tests/music-player.test.js`

**Interfaces:**
- Produces: `MusicPlayer.loadTrack(trackInfo: Track) -> void`, `MusicPlayer.play()`, `MusicPlayer.pause()`, `MusicPlayer.seek(seconds: number)`, `MusicPlayer.parseYouTubeUrl(url: string) -> string | null`
- Consumes: YouTube IFrame Player API and Windows SMTC playback session events.

- [ ] **Step 1: Write test for YouTube URL parsing and track metadata state**
```javascript
// dynamic-island/tests/music-player.test.js
const assert = require('assert');
const { parseYouTubeId, formatDuration } = require('../public/js/music-player');

assert.strictEqual(parseYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
assert.strictEqual(parseYouTubeId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
assert.strictEqual(formatDuration(66), '01:06');
assert.strictEqual(formatDuration(125), '02:05');
console.log('music-player tests passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/music-player.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `smtc-monitor.js` and `music-player.js`**
- Implement YouTube audio player widget with search input, album art, play/pause, seek progress bar, and synced lyrics viewer.
- Implement SMTC monitor to capture title, artist, and playback state from Chrome/Spotify via Windows Media APIs, falling back to YouTube audio mode.

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/music-player.test.js`
Expected: PASS ("music-player tests passed")

---

### Task 5: Pomodoro Focus Timer

**Files:**
- Create: `dynamic-island/src/pomodoro-engine.js`
- Create: `dynamic-island/public/js/pomodoro-ui.js`
- Test: `dynamic-island/tests/pomodoro-engine.test.js`

**Interfaces:**
- Produces: `PomodoroEngine.start()`, `PomodoroEngine.pause()`, `PomodoroEngine.reset()`, `PomodoroEngine.setMode('focus' | 'break')`, `PomodoroEngine.getState() -> PomodoroState`
- Consumes: Background interval ticker.

- [ ] **Step 1: Write test for Pomodoro countdown and mode transition**
```javascript
// dynamic-island/tests/pomodoro-engine.test.js
const assert = require('assert');
const { PomodoroEngine } = require('../src/pomodoro-engine');

const pomo = new PomodoroEngine({ focusDuration: 25 * 60, breakDuration: 5 * 60 });
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '25:00');

pomo.tick();
assert.strictEqual(pomo.remainingSeconds, 25 * 60 - 1);
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '24:59');

pomo.setMode('break');
assert.strictEqual(pomo.remainingSeconds, 5 * 60);
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '05:00');
console.log('pomodoro-engine tests passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/pomodoro-engine.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `pomodoro-engine.js` and `pomodoro-ui.js`**
- Implement `PomodoroEngine` managing state machine (`running`, `paused`, `completed`), sound trigger, and interval ticking.
- Implement `pomodoro-ui.js` with circular SVG progress ring, big countdown timer, mode toggle (Focus 25m / Break 5m), and ambient glow indicator on the notch.

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/pomodoro-engine.test.js`
Expected: PASS ("pomodoro-engine tests passed")

---

### Task 6: Dynamic System Popups & Bluetooth Status Monitor

**Files:**
- Create: `dynamic-island/src/system-monitor.js`
- Create: `dynamic-island/public/js/toast-manager.js`
- Test: `dynamic-island/tests/system-monitor.test.js`

**Interfaces:**
- Produces: `SystemMonitor.on('bluetooth-connect', callback)`, `SystemMonitor.on('battery-change', callback)`, `ToastManager.showToast(data: ToastData) -> void`
- Consumes: Windows Core Audio and WinRT Bluetooth enumeration / Battery APIs.

- [ ] **Step 1: Write test for ToastManager queue and auto-dismiss timing**
```javascript
// dynamic-island/tests/system-monitor.test.js
const assert = require('assert');
const { ToastQueue } = require('../public/js/toast-manager');

const queue = new ToastQueue();
queue.push({ id: 'bt-1', type: 'bluetooth', title: 'Baseus Encok WM01', subtitle: 'Connected • 80%' });
assert.strictEqual(queue.getCurrent().title, 'Baseus Encok WM01');
assert.strictEqual(queue.isEmpty(), false);

queue.dismiss();
assert.strictEqual(queue.isEmpty(), true);
console.log('system-monitor toast tests passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/system-monitor.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `system-monitor.js` and `toast-manager.js`**
- Implement `system-monitor.js` listening for Bluetooth audio device changes via PowerShell/WinRT bridge and battery status via Windows Power API.
- Implement `toast-manager.js` animating the collapsed notch into the dynamic toast pill for 3.5 seconds and displaying the connected peripheral icon in the expanded header bar.

- [ ] **Step 4: Run test to verify it passes**
Run: `node dynamic-island/tests/system-monitor.test.js`
Expected: PASS ("system-monitor toast tests passed")

---

### Task 7: End-to-End Integration, System Tray & Launch Scripts

**Files:**
- Create: `dynamic-island/src/app.js`
- Create: `dynamic-island/run-island.bat`
- Create: `dynamic-island/README.md`
- Test: `dynamic-island/tests/e2e-smoke.test.js`

**Interfaces:**
- Produces: Complete running Dynamic Island application on Windows 10/11.
- Consumes: All components from Tasks 1-6.

- [ ] **Step 1: Write end-to-end component wiring smoke test**
```javascript
// dynamic-island/tests/e2e-smoke.test.js
const assert = require('assert');
const { createAppState } = require('../src/app');

const app = createAppState();
assert.strictEqual(typeof app.init, 'function');
assert.strictEqual(typeof app.shutdown, 'function');
console.log('e2e component wiring test passed');
```

- [ ] **Step 2: Run test to verify it fails**
Run: `node dynamic-island/tests/e2e-smoke.test.js`
Expected: FAIL with "Cannot find module"

- [ ] **Step 3: Implement `app.js`, `run-island.bat`, and `README.md`**
- Wire all components together in `app.js`.
- Add system tray icon support (with "Open Island", "Toggle Launch on Startup", and "Exit").
- Create a 1-click launcher batch file `run-island.bat` for the user to start the island anytime on their laptop.

- [ ] **Step 4: Run all test suites across tasks**
Run: `node dynamic-island/tests/window-manager.test.js && node dynamic-island/tests/notch-controller.test.js && node dynamic-island/tests/shelf-engine.test.js && node dynamic-island/tests/music-player.test.js && node dynamic-island/tests/pomodoro-engine.test.js && node dynamic-island/tests/system-monitor.test.js && node dynamic-island/tests/e2e-smoke.test.js`
Expected: All test suites PASS.

- [ ] **Step 5: Run live test of the Dynamic Island on user's laptop**
Launch the application and verify:
1. Top pill docks cleanly at `y=0`.
2. Hover expands smoothly to dashboard with Shelf, Music, Pomodoro, and Bluetooth status.
3. Dragging a test file onto the notch opens the shelf and stages the file.
4. Memory footprint verified < 60MB RAM.
