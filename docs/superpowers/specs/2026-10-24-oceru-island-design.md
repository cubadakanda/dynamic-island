# Oceru Dynamic Island — Product & Feature Specification

## 1. Brand Identity & Project Overview
- **Brand Name:** **Oceru** (`Oceru Desktop`, `Oceru Dynamic Island`)
- **Origin & Purpose:** An original, sleek Windows 10/11 desktop smart notch and control center conceived and built by Orizzdev under the **Oceru** brand.
- **Strict Brand Rule:** Complete rebranding to Oceru across code, comments, window titles, scripts, registry keys, and documentation.

## 2. Core Feature Architecture

### 2.1 Rebranding & Windows Integration
- **Window Title & Taskbar Identity:** `Oceru Dynamic Island`
- **Registry & Startup Key:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\OceruDynamicIsland`
- **Shortcuts & Directories:** `Oceru.lnk`, `.oceru.pid`
- **Process & Instance Manager:** Single-instance mutex with PID management for instant hot-reload and clean shutdown.

### 2.2 Control Center & Quick Toggles (Tab 1: "Control Center")
- **Mobile-style Quick Toggle Grid:**
  - **Wi-Fi Toggle:** Detects current Wi-Fi interface state (via `netsh wlan show interfaces`) and allows 1-click enable/disable (`netsh interface set interface "Wi-Fi" admin=enabled/disabled`).
  - **Bluetooth Toggle:** Shows current connection state and toggle action.
  - **Volume & Audio Mute Toggle:** 1-click sound mute/unmute and volume level feedback.
  - **Focus Mode / Do Not Disturb:** Toggles distraction-free work mode.
- **Battery & Power Monitor Widget:**
  - Real-time Battery Percentage (`[System.Windows.Forms.SystemInformation]::PowerStatus`).
  - Charging status indicator with pulse animation (`Charging`, `Discharging`, `Full`).
  - Power line status badge (AC Connected vs. On Battery).

### 2.3 Real-time Bluetooth Device Status & Dynamic Pill Notification
- **Live Bluetooth Detection:** Periodically checks paired and active audio/peripheral devices (via Windows PnP / WMI / Bluetooth device registry).
- **Dynamic Island Toast Animation:** When a new Bluetooth headset, mouse, or device connects or disconnects, the collapsed notch dynamically expands with a spring animation showing:
  - Vector Bluetooth icon (`&#xE7F6;`)
  - Device name (e.g. `Baseus Encok D02 Pro Connected`)
  - Battery / status pill, then auto-collapses smoothly after 3.5 seconds.

### 2.4 YouTube Audio Player & Synchronized Lyrics (Tab 2: "Music")
- **Player Interface:**
  - Track Title, Artist, Timeline scrub bar, Play/Pause, Next/Previous controls.
  - YouTube search / link input with automatic video ID extraction.
  - Embedded audio playback engine with synced lyrics view (LRC line-by-line highlighter).
- **Visualizer Effect:** Animated sound wave / equalizer bars when playing.

### 2.5 File Shelf & Pomodoro Focus Timer (Tabs 3 & 4)
- **File Shelf:** Staging drop-zone for quick drag-and-drop file parking.
- **Pomodoro Timer:** 25m work / 5m break cycles with audio chime and status visualizer.

### 2.6 Visual Theme Switcher
- **OLED True Black (Default):** `#08090D` deep obsidian backdrop with subtle borders.
- **Aero Glass / Glassmorphism:** Semi-transparent frosted backdrop (`#101524` with 82% opacity and subtle white border highlights).
- **Neon Cyberpunk:** High-contrast neon cyan and magenta accents (`#050811`, `#06B6D4`, `#EC4899`).
- **1-Click Theme Switcher:** Available in the Notch settings / right-click context menu.
