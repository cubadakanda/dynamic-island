# Oceru Dynamic Island — Functional Integration & Seamless UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Oceru Dynamic Island from visual prototypes and mock states to genuine Windows system integrations (Core Audio, Radio/Network adapters, Windows Media Sessions with local audio engine fallback, brightness detection, and seamless bezel-flush obsidian window composition) with strict bi-directional synchronization between the Island and the 15-page Dashboard.

**Architecture:** 
1. C# COM Interop (`IAudioEndpointVolume`, `IMMDeviceEnumerator`) for bit-accurate system master volume and mute control.
2. WinRT & .NET Network integration (`Windows.Devices.Radios.Radio`, `System.Net.NetworkInformation.NetworkInterface`) for real hardware Wi-Fi/Bluetooth state detection with resilient fallback to Windows Flyout/Settings.
3. Windows Media Transport Controls (GSMTC) session discovery with automatic fallback to native WPF `MediaPlayer` for local audio files and global media key dispatching.
4. Window composition hardening (`ResizeMode="NoResize"`, `SnapsToDevicePixels="True"`, `UseLayoutRounding="True"`, Top=0 flush alignment) eliminating all gaps and visual detachment.
5. Bi-directional state binding engine synchronizing `.oceru-state.json`, Island controls, and Dashboard controls.

**Tech Stack:** PowerShell 5.1 / 7, WPF / XAML, C# COM Interop (Core Audio), WinRT (`Windows.Devices.Radios`, `Windows.Media.Control`), .NET `System.Windows.Media.MediaPlayer`.

**Spec:** User prompt requirements (Phases 1 through 8).

## Global Constraints

- Preserve all existing 6 carousel cards, 15 dashboard pages, timers, and animations.
- Backward compatibility with `.oceru-state.json`.
- Zero raw UTF-8 emoji characters (use Segoe MDL2 character glyphs `&#x...;` or `[char]0x...`).
- Do not simulate an API: report actual status (Available, Enabled, Disabled, Unavailable, Error) with clear user feedback.
- Do not push to remote git until all automated and manual tests are verified.

## Review Focus

1. **Audio COM failure or unavailable endpoint:** If no audio endpoint is connected (e.g. headless or disabled audio), `AudioManager` must return -1 / safe fallbacks without throwing unhandled COM exceptions.
2. **Wi-Fi / Bluetooth permission restriction:** In restricted environments (non-admin / UWP capability absent), adapter state must accurately display "Akses Terbatas" or "Buka Pengaturan" without claiming a toggle succeeded when only a settings URL was launched.
3. **No Active Media Session:** When no Windows media is playing, display "Tidak ada media aktif" and allow local file selection or global media keys rather than fabricating fake songs.
4. **Brightness on non-DDC/CI or non-WMI displays:** Internal laptop displays or virtual monitors that do not expose DDC/CI or WMI must display a clear "Pengaturan Tampilan" fallback rather than freezing or crashing.
5. **Window Positioning & Scaling:** Multi-monitor and high-DPI scaling must maintain exact Top=0 alignment and horizontal centering without subpixel gaps or detachment.

---

### Task 1: Comprehensive Control Audit & Inventory

**Files:**
- Create: `docs/audit/control-inventory.md`
- Inspect: `D:/Project Orizzdev/dynamic-island/run-island.ps1`

- [ ] Inspect all event handlers, click events, value-changed events, and timer updates in `run-island.ps1`.
- [ ] Catalog each control's UI element name, label, current implementation, expected system behavior, and required fix.
- [ ] Write the audit findings to `docs/audit/control-inventory.md`.

---

### Task 2: Windows Core Audio Integration (`IAudioEndpointVolume`)

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`
- Test: `scratch/test-audio-set.ps1`

- [ ] Implement C# COM Interop class `OceruAudioManager` in `run-island.ps1` wrapping `IMMDeviceEnumerator` and `IAudioEndpointVolume`:
  - `GetMasterVolume()`: returns integer 0-100 (or -1 if unavailable).
  - `SetMasterVolume(int percent)`: sets scalar volume level directly.
  - `GetMute()`: returns current mute boolean.
  - `SetMute(bool isMuted)`: sets mute state.
  - `ToggleMute()`: toggles mute and returns new state.
- [ ] Wire Island `QuickSliderVol` and Dashboard `DashQuickVolSlider` to `OceruAudioManager::SetMasterVolume`.
- [ ] Wire Island `BtnQuickMute` and Dashboard `BtnDashQuickMute` to `OceruAudioManager::ToggleMute`.
- [ ] Add real-time polling/sync in `mainTimer` tick to read external volume key changes and update slider/text seamlessly.
- [ ] Test with real volume changes and verify 100% roundtrip accuracy.

---

### Task 3: Real Wi-Fi and Bluetooth Adapter & Radio Integration

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`
- Test: `scratch/test-radios3.ps1`

- [ ] Implement `OceruConnectivityHelper`:
  - Query real Wi-Fi adapter state using `.NET NetworkInterface` and `Windows.Devices.Radios.Radio`.
  - Query real Bluetooth radio state using `Windows.Devices.Radios.Radio`.
  - Provide safe toggle functions that attempt `Radio.SetStateAsync()`.
  - If direct toggle is restricted or unsupported, provide transparent feedback and launch native Windows network flyout (`ms-availablenetworks:`) or Bluetooth settings (`ms-settings:bluetooth`).
- [ ] Update Island `BtnQuickWifi`, Dashboard `BtnDashQuickWifi`, Island `BtnQuickBt`, Dashboard `BtnDashQuickBt` with active state indicators (Aktif / Mati / Buka Pengaturan).
- [ ] Verify runtime behavior on target system.

---

### Task 4: Display Brightness Detection & Settings Fallback

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`

- [ ] Implement `OceruBrightnessHelper` attempting WMI (`WmiMonitorBrightness`) and DXVA2 (`GetMonitorBrightness`/`SetMonitorBrightness`).
- [ ] If hardware brightness is unavailable or restricted by Windows permissions, report "Kecerahan: Buka Pengaturan Tampilan" and launch `ms-settings:display` upon click.
- [ ] Add Brightness Control tile to Dashboard Quick Settings (Page 11).
- [ ] Verify that no exceptions are thrown when hardware brightness is unavailable.

---

### Task 5: Real Windows Media Transport Controls & Native Audio Player

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`

- [ ] Replace hardcoded mock playlist in Card 0 and Dashboard Media Page:
  - Add Windows Media Session listener via GSMTC with safe exception isolation.
  - If an active Windows media session exists (Spotify, YouTube/Edge/Chrome, Media Player), display real track title, artist, source application, and route Play/Pause/Prev/Next to the session.
  - If no active session is detected, show "Tidak ada media aktif" and allow sending global media keys (`VK_MEDIA_PLAY_PAUSE`, `VK_MEDIA_NEXT_TRACK`, `VK_MEDIA_PREV_TRACK`).
  - Add native local audio file picker and player using `System.Windows.Media.MediaPlayer` for real `.mp3`/`.wav` playback with genuine progress and elapsed time.
- [ ] Synchronize playback status between Island Card 0 and Dashboard Page 2 (Media & Lyrics).
- [ ] Test media playback controls and fallback states.

---

### Task 6: Seamless Obsidian Silhouette & Window Composition Refinement

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`

- [ ] Refine `islandXaml` Window properties:
  - Set `ResizeMode="NoResize"`.
  - Set `SnapsToDevicePixels="True"`.
  - Set `UseLayoutRounding="True"`.
  - Ensure `Top="0"`, `WindowStartupLocation="Manual"`.
- [ ] Eliminate visual gap/detachment from top edge:
  - Set `VerticalAlignment="Top"` on `NotchBody`.
  - Keep `CornerRadius="0,0,18,18"` for resting/status and `CornerRadius="0,0,24,24"` for expanded.
  - Add restrained dark shadow below the bottom curve (`DropShadowEffect` with `Direction="270"`, `ShadowDepth="2"`, `BlurRadius="6"`, `Color="#000000"`, `Opacity="0.4"`) without clipping or border fringe.
- [ ] Refine design tokens across all views: `#000000` surface, `#060A14` app surface, `#0B101B` card surface, `#202A3A` subtle border, `#F3F6FC` primary text, `#9BAAC0` secondary text, `#00D2FF` cyan accents.

---

### Task 7: Shared State Model & Bi-Directional Event Synchronization

**Files:**
- Modify: `D:/Project Orizzdev/dynamic-island/run-island.ps1`

- [ ] Unify state bindings so that changes in the Dashboard immediately update the Dynamic Island, and vice-versa:
  - Volume level and mute status.
  - Media track, playback state, and lyrics view.
  - Pomodoro timer, countdown, stopwatch.
  - Notes and To-Do list.
  - Quick launcher and settings preferences.
- [ ] Preserve `.oceru-state.json` structure with graceful schema migration.

---

### Task 8: Automated & Manual Testing, Verification & Deliverables

**Files:**
- Test: `scratch/verify.ps1`
- Screenshots: `live_resting_island.png`, `live_compact_status.png`, `live_expanded_carousel.png`

- [ ] Run PowerShell AST parse check on `run-island.ps1` (0 syntax errors).
- [ ] Run XAML parse check on both windows (`islandXaml` and `dashXaml`).
- [ ] Test live runtime launch and verify CPU/RAM performance.
- [ ] Capture screenshots of all three island modes: Resting Cat Eyes, Compact Status Bar, Expanded Carousel.
- [ ] Prepare comprehensive test report with PASS / FAIL / NOT TESTED status table and documentation of all changes.
