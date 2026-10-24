# Oceru — Existing Project Redesign & Functional Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Overview
Transform the existing Oceru Dynamic Island Windows desktop application into a cohesive, premium desktop application following the **Ocean Azure Glass** design language. Connect all 28 major features across a compact floating Dynamic Island, a redesigned Quick Settings panel, and a comprehensive 15-destination Dashboard window, powered by unified shared state and real Windows hardware integration.

---

## 1. Design System: Ocean Azure Glass
- **Surfaces:**
  - Base Deep Navy: `#070A12` (OLED Obsidian base)
  - Glass Card Surface: `#0C1322` with 88% opacity (`#E00C1322`)
  - Elevated Glass Card: `#111A2E` with subtle linear gradient to `#0E1626`
- **Accents:**
  - Royal Azure: `#2563EB` to `#1D4ED8` (Primary brand gradient)
  - Electric Cyan: `#00D2FF` / `#38BDF8` (Active status, equalizer, focus highlights)
  - Emerald Green: `#10B981` (Charging, success, running status)
  - Amber Warning: `#F59E0B` (Low battery, pause states)
  - Rose/Red: `#EF4444` (Muted, critical battery, danger confirmation)
- **Borders & Shadows:**
  - Subtle Glass Border: 1px solid `#1E2D48` (unfocused), `#38BDF8` (hover/active)
  - Soft Multi-Layer Drop Shadow: `BlurRadius="28"`, `ShadowDepth="6"`, `Opacity="0.85"`
- **Typography & Icons:**
  - Font: Segoe UI, Consolas (monospace timers)
  - Vector Icons: Segoe MDL2 Assets glyphs (Lucide-inspired clean geometric symbols)
- **Language:** Bahasa Indonesia (primary), clear, concise, calm.

---

## 2. Architecture & File Structure

```text
dynamic-island/
├── run-island.ps1              # Core Native WPF Application (Dynamic Island + Quick Panel + Full Dashboard)
├── run-island.bat              # Launcher for Oceru
├── install.bat                 # Auto-start installer
├── stop-island.bat             # Clean graceful shutdown
├── uninstall.bat               # Startup uninstaller
├── .oceru-state.json           # Persistent application state (user settings, notes, tasks, clipboard)
├── README.md                   # Complete user documentation
├── docs/superpowers/           # Design specs and plans
└── legacy-web/                 # Web prototype and unit test suites
    ├── public/css/notch.css    # Ocean Azure Glass styling for web prototype
    ├── public/index.html       # Web prototype UI
    └── tests/                  # Automated verification test suites
```

---

## 3. Implementation Tasks

### Task 1: Audit & Persistent Shared Application State (`.oceru-state.json`)
- [ ] Define `$global:OceruState` schema:
  - Theme (`ocean-dark`, `ocean-light`, `windows-auto`)
  - Accent Color (`azure`, `cyan`, `emerald`, `magenta`)
  - Dynamic Island Mode (`compact`, `expanded`, `media`, `pomodoro`, `stopwatch`, `countdown`, `resting`, `charging`, `dnd`, `gaming`)
  - Quick Settings status: Wi-Fi, Bluetooth, Audio Volume, Mute, Brightness, DND, Gaming Mode
  - Active Timer state (Pomodoro, Stopwatch laps, Countdown seconds)
  - Notification queue with read/unread flags
  - Notes list with timestamps
  - To-Do tasks with completion states
  - Clipboard history items with pinned flag
  - User preferences (island position, opacity, animation speed, auto-collapse)
- [ ] Implement `Load-OceruState` and `Save-OceruState` functions with automatic fallback to defaults.
- [ ] Verify state persistence by writing and reading sample state.

### Task 2: Redesign the Floating Dynamic Island (All 12 Contextual States)
- [ ] Implement compact island container (`180×32 px`, corner radius `0,0,18,18` anchored at screen top `0`):
  - State 1: **Idle State** (Crisp weather `28°`, digital clock `HH:mm`, battery `%` with charging detection).
  - State 2: **Resting State** (Soft glowing eyes `( • • )` with idle timer transition after 5s and smooth blink).
  - State 3: **Media Playback State** (Animated 3-bar equalizer glyph + scrolling track name).
  - State 4: **Pomodoro Running State** (Live countdown `24:59` with emerald glowing dot).
  - State 5: **Stopwatch Running State** (Live elapsed time `01:23` with cyan lap dot).
  - State 6: **Countdown State** (Live countdown indicator).
  - State 7: **Charging State** (Emerald charging lightning glyph + battery percentage).
  - State 8: **Low Battery State** (Amber/red warning alert when battery < 20%).
  - State 9: **Do Not Disturb State** (Subtle moon glyph `🌙`).
  - State 10: **Gaming Mode State** (Gamepad shield glyph `🎮`).
  - State 11: **Notification / Toast State** (Smooth animated pill expansion with icon and message).
  - State 12: **Expanded Quick Panel State** (Spring-like expansion to `650×260 px`).

### Task 3: Redesign the Quick Panel (Grouped Controls, Sliders & Quick Actions)
- [ ] Design top navigation row:
  - 7 sleek segmented tab buttons: `🎛️ Kontrol`, `🎵 Media`, `💬 Lirik`, `⏱️ Fokus`, `📋 Klip`, `📝 Catatan`, `📁 Shelf`.
  - Header right controls: In-notch action feedback toast pill, full Dashboard toggle button `[ ⛶ Dashboard ]`, battery badge, time.
- [ ] Refactor `PaneControl` into organized, logical groups:
  - **Group 1: Connectivity (Konektivitas)**
    - Wi-Fi button: Opens native Windows Available Networks flyout (`ms-availablenetworks:`).
    - Bluetooth button: Opens Windows Bluetooth Settings (`ms-settings:bluetooth`).
  - **Group 2: Audio & Tampilan (Sound & Display)**
    - Master Audio Mute toggle button (real Win32 `WM_APPCOMMAND`).
    - Interactive Volume Slider (0-100%) with live Windows master volume adjustment.
    - Mini `[ - ]` and `[ + ]` volume step buttons.
    - Brightness shortcut button (`ms-settings:display`).
  - **Group 3: Mode & Produktivitas Cepat (Modes & Quick Actions)**
    - Do Not Disturb (DND) toggle button.
    - Gaming Mode toggle button (optimizes island overlay behavior).
    - Task Manager shortcut button (`taskmgr.exe`).
    - Windows Settings shortcut (`ms-settings:`).
  - **Group 4: Aksi Sistem & Daya (System Actions)**
    - Kunci Layar (real Win32 `LockWorkStation`).
    - Mode Tidur (Sleep via `rundll32 powrprof.dll`).
    - Restart with safe two-step confirmation dialog ("Yakin Restart?").
    - Ganti Tema (toggles Ocean Dark, Ocean Light, Cyberpunk).

### Task 4: Complete Media Player & Synced Lyrics Engine
- [ ] Connect `PaneMusic`:
  - Rich album art with gradient backdrop glow.
  - Track title, artist, seekable progress bar.
  - Controls: Prev, Play/Pause, Next, YouTube search input box.
  - Real audio streaming via embedded `AudioWebEngine` or browser fallback.
- [ ] Connect `PaneLyrics`:
  - Split synchronized karaoke view (Past line, Active singing line in electric cyan, Next line).
  - Interactive line selection.

### Task 5: Productivity Suite (Pomodoro, Stopwatch, Countdown, Notes, To-Do, Clipboard, Shelf)
- [ ] Refactor `PanePomo` with preset duration pills (`5m`, `10m`, `15m`, `25m`, `45m`) and countdown engine.
- [ ] Add Stopwatch and Countdown capability to productivity state.
- [ ] Connect `PaneClip` (Clipboard history):
  - Click to re-copy with visual feedback toast.
  - Persistent clipboard item storage.
- [ ] Connect `PaneTodo` (To-Do & Notes):
  - Enter key to add new task.
  - Checkbox toggle with strikethrough styling and live counter.
  - Persistent task storage.
- [ ] Connect `PaneShelf` (File Shelf):
  - Drag-and-drop file staging area with badge count.

### Task 6: Implement Full Oceru Dashboard Window (15 Dedicated Destinations)
- [ ] Build multi-page WPF Dashboard Window (`960×650 px`) using Ocean Azure Glass styling:
  - Left Sidebar navigation (15 destinations):
    1. `📊 Ringkasan` (Overview)
    2. `🏝️ Dynamic Island` (Notch Customization & Preview)
    3. `🎵 Media & Musik` (Media Player & Synced Lyrics)
    4. `⏱️ Fokus Pomodoro` (Pomodoro Timer & History)
    5. `⏱️ Stopwatch` (Stopwatch with Lap Counter)
    6. `⏳ Hitung Mundur` (Countdown Timer with Custom Hours/Mins/Secs)
    7. `📈 Monitor Sistem` (Live CPU %, RAM %, Battery %, Network Status)
    8. `🔔 Notifikasi` (Notification Center with Read/Unread Filters)
    9. `📝 Catatan` (Quick Notes & Scratchpad with Auto-Save)
    10. `✅ Daftar Tugas` (Categorized Task Manager)
    11. `📋 Papan Klip` (Clipboard Manager with Favorites)
    12. `🎛️ Pengaturan Cepat` (Quick Settings Matrix)
    13. `🚀 Peluncur Cepat` (Quick App Launcher with Customizable Slots)
    14. `⚙️ Pengaturan` (Appearance, Island Size, Startup, Hotkeys, Privacy)
    15. `ℹ️ Tentang Oceru` (Version, Diagnostics, System Information)
- [ ] Connect shared state between Dashboard and Dynamic Island window:
  - Starting timer in Dashboard immediately updates the compact island.
  - Playing music updates both interfaces.
  - Theme changes in Settings apply instantly to both windows.

### Task 7: Quality Verification, Test Suites & Git Synchronization
- [ ] Syntax check with PowerShell Language Parser: `[System.Management.Automation.Language.Parser]::ParseFile`.
- [ ] XAML validation for both Dynamic Island and Dashboard windows.
- [ ] Run `legacy-web` test suite via Node.js to verify all unit tests pass.
- [ ] Launch application live and verify responsiveness at 1366×768 and 1920×1080.
- [ ] Verify zero occurrences of legacy names across all files and git logs.
- [ ] Commit and push changes incrementally to GitHub repository `main`.
