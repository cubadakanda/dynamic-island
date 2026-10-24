# Dynamic Island Desktop (Oceru Style Notch) Design Document

**Date:** 2026-10-24  
**Status:** Ready for User Approval (Brainstorming Complete)  
**Target Platform:** Windows 10 & 11 (64-bit)  
**Reference Video:** `aset/video/Dinamic Island.mp4` (Oceru Notch)  
**Spec Location:** `docs/superpowers/specs/2026-10-24-dynamic-island-notch-design.md`

---

## 1. Intent and The Why

The user wants a lightweight, aesthetic, and functional "Dynamic Island" / "Smart Notch" docked at the top bezel of their Windows laptop screen.

Traditional Windows desktop environments lack a unified ambient space for quick productivity gestures like temporary file staging, background music control, focus timing, and peripheral status monitoring. Most existing third-party notch tools are bloated, consume excessive RAM/CPU, or have cluttered interfaces. 

This project delivers a sleek, butter-smooth, and ultra-lightweight desktop overlay that stays out of the way when working, but reveals essential productivity tools when hovered or when files are dragged toward the top of the screen.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Top Bezel Smart Notch:** A floating, frameless, always-on-top overlay anchored at the top-center of the primary monitor (`y = 0`).
- **Smooth 60fps Animations:** Fluid spring-like collapse/expand transitions between the minimal state (collapsed pill) and active state (expanded dashboard).
- **File Shelf (Temporary Drop Zone):** A temporary holding area where files can be dragged from Desktop or File Explorer, stored as staging references, and easily dragged back out into any Windows app (WhatsApp, Discord, browser, or folders).
- **Hybrid Music Player:**
  - *Mode 1 (System Sync):* Automatically detects and controls audio currently playing on the laptop (Chrome/Edge YouTube, Spotify, VLC) via Windows System Media Transport Controls (SMTC), complete with track title, artist, seek bar, play/pause, and lyrics display.
  - *Mode 2 (Standalone YouTube Audio):* An integrated search and direct YouTube audio player within the island for focused background listening without needing a dedicated browser tab.
- **Focus Timer (Pomodoro):** A circular countdown timer for productivity sessions (25-minute focus time, 5-minute break) with start/pause/reset controls.
- **Dynamic System Popups & Bluetooth Status:**
  - Instant animated banner when a Bluetooth device (e.g., headset, earbuds) connects or disconnects, showing device name and battery percentage.
  - Quick glance indicator inside the island showing active connected peripherals.
  - Dynamic visual popups for system volume changes and battery/charging state changes.
- **Resource Efficiency:** Target memory footprint ~40–60 MB RAM (utilizing the shared Windows WebView2 evergreen runtime) and near-zero idle CPU usage (< 0.5%).

### Non-Goals
- Full video streaming or heavy browser capabilities inside the notch (the notch is for ambient audio, quick tasks, and notifications).
- Cross-platform support (strictly Windows 10/11 native).
- Cloud synchronization or login accounts (all data and temporary shelf files stay 100% local on the laptop).

### Anti-Goals
- Bloated Electron architecture consuming 200MB+ RAM and lagging system response.
- Blocking window clicks or titlebars when the notch is collapsed (outside the pill, clicks pass straight through to background apps).
- Complex multi-step configuration menus that clutter the experience.

---

## 3. UI/UX Specifications

### 3.1 States & Dimensions
1. **Collapsed State (Idle):**
   - **Dimensions:** Width ~140px, Height ~32px, docked flush at `y = 0`.
   - **Visuals:** Jet-black pill with rounded bottom corners (`border-bottom-left-radius: 18px; border-bottom-right-radius: 18px`), subtle border (`#1f232e`), clock (`HH:mm`), and status dot/audio equalizer waveform.
   - **Click-through:** The area around the pill is completely transparent and passes all mouse events to underlying windows.
2. **Expanded State (Hover / Active):**
   - **Dimensions:** Width ~560px, Height ~190px, `border-bottom-left-radius: 26px; border-bottom-right-radius: 26px`.
   - **Header Bar:** Tab switcher (`📁 Shelf`, `🎵 Music`, `⏱️ Pomodoro`), connected Bluetooth indicator pill, and current date & time.
   - **Body:** Active panel with fluid tab switching.
3. **Drag-Over State (Shelf Auto-Trigger):**
   - **Trigger:** Dragging any file to the top edge or onto the notch.
   - **Behavior:** The notch immediately expands into the **File Shelf** with a dashed drop area. Dropped files appear as horizontal cards with file icons, filenames, file sizes, and a "Clear All" button. Files can be dragged out into any external app.
4. **Dynamic Toast Pop-up State:**
   - **Trigger:** System event (Bluetooth connect, charger plugged/unplugged, volume adjustment).
   - **Visuals:** Expands temporarily into a compact pill showing the event (e.g. `🎧 Baseus Encok WM01 Connected • 80%`) for 3.5 seconds, then smoothly animates back into the collapsed state.

---

## 4. Technical Architecture & Decisions

### 4.1 Technology Stack
- **Desktop Host & System Bridge:** C# .NET or lightweight Node.js Win32 Host with Microsoft Edge WebView2.
  - Provides native access to Windows APIs:
    - `WS_EX_TOPMOST`, `WS_EX_LAYERED`, `WS_EX_TOOLWINDOW` (prevents showing in Alt+Tab and taskbar if desired).
    - `GlobalSystemMediaTransportControlsSessionManager` (SMTC) for universal media playback detection.
    - Windows Runtime `Windows.Devices.Enumeration` and `Windows.Devices.Bluetooth` for real-time Bluetooth connection detection and battery telemetry.
    - Windows Power API (`GetSystemPowerStatus`) for battery charging state.
- **Frontend Presentation Layer:** HTML5, modern CSS3 (custom CSS variables, spring transition curves, backdrop filters), and Vanilla JavaScript for zero-overhead, 60fps rendering.

### 4.2 Module Breakdown
1. **Window Overlay Engine:**
   - Manages top-screen anchoring and DPI scaling awareness (100%, 125%, 150%).
   - Implements mouse-tracking to handle smooth hover expand and mouse-leave collapse without flickering.
2. **File Shelf Staging Engine:**
   - Standard Windows OLE drag-and-drop listener.
   - Manages local file staging in `%TEMP%/dynamic-island-shelf/`.
   - Implements `DoDragDrop` so files can be dragged out of the shelf into File Explorer, browsers, and messengers.
3. **Hybrid Audio & Media Controller:**
   - SMTC listener: captures currently playing song title, artist, thumbnail, and playback state from external apps.
   - Headless YouTube audio player: embedded YouTube IFrame API instance with audio-only mode and search capabilities.
4. **Pomodoro Engine:**
   - Accurate background timer with pause/resume and notification sound on session completion.
5. **System Event & Bluetooth Monitor:**
   - Event listener for Bluetooth device connections, volume changes, and power status.

---

## 5. Builder Calls (Decisions Settled During Review)

1. **OLE Drag Detection:** The collapsed pill and a 4px trigger strip along the top bezel serve as the OLE drop target. When a drag enters, the window instantly expands to full shelf size to accept drops without needing invasive global system hooks.
2. **Memory Footprint:** 50MB is targeted via Windows shared WebView2 runtime, isolating web components from heavy browser chrome.
3. **Local Staging Storage:** File shelf retains shortcuts or temporary references; original files are preserved. A single click on a file in the shelf opens it directly, or user can drag it out.

---

## 6. What's Left to the Implementation Plan

- Exact UI styling tokens (color palettes matching dark mode Windows 11).
- Setting up the project workspace structure (`src/`, `assets/`, `backend/`).
- Step-by-step build order (Window Host -> UI Frame -> File Shelf -> Media Engine -> Pomodoro -> Bluetooth/System Monitor).
