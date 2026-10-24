# Oceru Dynamic Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Dynamic Island desktop app into the complete **Oceru** flagship product featuring Quick Toggles (Wi-Fi, Bluetooth, Mute), Real-time Battery Monitor, Live Bluetooth Toast Popups, YouTube Audio & Lyrics Player, Theme Switcher, and full rebranding.

**Architecture:** Native WPF Direct3D window in PowerShell with modular event handlers, background timers for system state monitoring, spring animations, and instant hot-reload capabilities.

**Tech Stack:** PowerShell 5.1 / 7+, Windows Presentation Foundation (WPF/XAML), Windows Netsh & PowerStatus APIs, Direct3D hardware-accelerated transparency.

**Spec:** [docs/superpowers/specs/2026-10-24-oceru-island-design.md](file:///D:/Project%20Orizzdev/dynamic-island/docs/superpowers/specs/2026-10-24-oceru-island-design.md)

## Global Constraints
- Complete rebranding to Oceru across all files, code comments, UI text, and documentation.
- Zero dependencies on Node.js/Electron at runtime (100% native Windows lightweight process).
- Memory footprint must remain under 30 MB RAM.
- Startup auto-start and uninstall scripts must work without administrator prompts.

---

### Task 1: Complete Rebranding to Oceru
- [ ] Rename window titles, registry keys, shortcut targets, PID files (`.oceru.pid`).
- [ ] Update `README.md`, `install.bat`, `uninstall.bat`, `stop-island.bat`, `run-island.bat`, `tools/`.
- [ ] Verify zero occurrences of legacy names remain in the codebase.

### Task 2: Real-time Battery & Power Monitor Engine
- [ ] Read `[System.Windows.Forms.SystemInformation]::PowerStatus` (BatteryLifePercent, PowerLineStatus).
- [ ] Create battery badge in the collapsed notch and expanded Control Center with percentage and charging icon (`&#xEBAA;`, `&#xEBAB;`, `&#xE7E8;`).
- [ ] Add smooth green/cyan charging pulse animation when AC power is connected.

### Task 3: Mobile-Style Control Center & Quick Toggles
- [ ] Design Control Center tab grid in XAML with modern rounded pill buttons.
- [ ] Implement Wi-Fi Toggle (`netsh wlan show interfaces` and `netsh interface set interface`).
- [ ] Implement Bluetooth Toggle and status indicator.
- [ ] Implement Sound/Mute Toggle and volume state.
- [ ] Implement Focus Mode (Do Not Disturb) toggle.

### Task 4: Live Bluetooth Device Detection & Dynamic Pill Toast
- [ ] Background polling timer for active connected Bluetooth devices.
- [ ] Trigger dynamic pop-up spring notification on the top notch when a device connects/disconnects.
- [ ] Auto-collapse notification pill after 3.5 seconds.

### Task 5: YouTube Audio Player & Synced Lyrics Interface
- [ ] Audio player tab with song cover gradient, track metadata, and seek bar.
- [ ] YouTube URL parser / search input with playback state toggle.
- [ ] Synced lyrics line visualizer with animated equalizer bars.

### Task 6: Visual Theme Switcher (OLED, Aero Glass, Cyberpunk)
- [ ] Implement Theme definitions in WPF dynamic resource brushes.
- [ ] Add theme switcher buttons / right-click menu items.
- [ ] Verify instant live theme transitions without app restart.

### Task 7: Verification & Push to GitHub
- [ ] Test all controls, toggles, battery readings, and animations.
- [ ] Commit all changes with clear descriptive commits under brand **Oceru**.
- [ ] Push to GitHub repository `cubadakanda/dynamic-island`.
