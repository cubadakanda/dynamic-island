# Oceru Dynamic Island — Control Audit & Inventory

Generated: 2026-10-25
Application: `run-island.ps1`

| UI Element Name | Location | Displayed Label | Current Implementation | Expected System Behavior | Actual Test Result | Required Fix |
|---|---|---|---|---|---|---|
| `QuickSliderVol` | Island Card 5 | Volume Slider | Sets `$quickVolPctText.Text` & updates local state variable | Sets exact Windows Master Volume level (0–100%) | FAILS: Only updates internal JSON state, no actual volume change | Integrate `OceruAudioManager::SetMasterVolume` via `IAudioEndpointVolume` COM Interop |
| `BtnQuickMute` | Island Card 5 | Mute Button (Icon) | Broadcasts `APPCOMMAND_VOLUME_MUTE` via `SendMessageW` | Toggles mute on default audio endpoint and syncs UI icon | PARTIAL: `SendMessageW` broadcast is slow and does not report state | Integrate `OceruAudioManager::ToggleMute` & read real mute state |
| `DashQuickVolSlider` | Dashboard Page 11 | Volume Slider | Sets text & local state variable | Sets exact Windows Master Volume level (0–100%) | FAILS: No system volume change | Wire to `OceruAudioManager::SetMasterVolume` and sync with Island |
| `BtnDashQuickMute` | Dashboard Page 11 | "Mute Audio" / "Unmute Audio" | Inverts local state boolean | Toggles mute on default audio endpoint | FAILS: Inverts state variable without hardware change | Wire to `OceruAudioManager::ToggleMute` |
| `BtnDashOpenSoundSettings` | Dashboard Page 11 | "Buka Pengaturan Suara Windows" | `Start-Process "ms-settings:sound"` | Opens Windows Sound Settings | PASS: Opens Windows Sound Settings correctly | Retain as valid fallback |
| `BtnQuickWifi` | Island Card 5 | "Wi-Fi" | `Start-Process "ms-availablenetworks:"` | Toggle Wi-Fi or show flyout with real state | PARTIAL: Opens network flyout but doesn't show real Wi-Fi state | Query real Wi-Fi status via WinRT `Radio` & .NET `NetworkInterface`; keep flyout on click |
| `BtnDashQuickWifi` | Dashboard Page 11 | "Wi-Fi (Buka Flyout Jaringan)" | `Start-Process "ms-availablenetworks:"` | Shows real status & opens network flyout | PASS: Clearly labeled as flyout shortcut | Update label with live connection status (e.g., Terhubung / Mati) |
| `BtnQuickBt` | Island Card 5 | "Bluetooth" | `Start-Process "ms-settings:bluetooth"` | Toggle Bluetooth or show settings with real state | PARTIAL: Opens settings, no state indication | Query real Bluetooth status via WinRT `Radio`; keep settings on click |
| `BtnDashQuickBt` | Dashboard Page 11 | "Bluetooth Settings" | `Start-Process "ms-settings:bluetooth"` | Shows real status & opens settings | PASS: Labeled as settings shortcut | Update label with live radio status |
| `BtnQuickDnd` | Island Card 5 | "DND" | Inverts local boolean `$global:OceruState.dndEnabled` | Controls Windows Do Not Disturb or Oceru Focus | PARTIAL: Controls Oceru internal DND mode only | Accurately label as "Fokus Oceru" / "DND Oceru" to prevent confusion with Windows Focus |
| `BtnDashQuickDnd` | Dashboard Page 11 | "Mode Jangan Ganggu" | Inverts local boolean | Controls Oceru Focus mode | PARTIAL: Internal mode only | Clarify label as "Mode Fokus Oceru" |
| `BtnQuickGame` | Island Card 5 | "Game" | Inverts local boolean `$global:OceruState.gamingMode` | Controls Oceru Gaming Mode | PARTIAL: Internal mode only | Accurately describe as Oceru Gaming Optimization preference |
| `BtnDashQuickGame` | Dashboard Page 11 | "Mode Game" | Inverts local boolean | Controls Oceru Gaming Mode | PARTIAL: Internal mode only | Accurately describe as Oceru Gaming Optimization preference |
| `BtnQuickLock` | Island Card 5 | "Kunci" | `[Win32Helper]::LockWorkStation()` | Locks Windows desktop station | PASS: Successfully locks workstation | Retain existing Win32 API |
| `BtnQuickSleep` | Island Card 5 | "Tidur" | `powrprof.dll,SetSuspendState 0,1,0` | Suspends/sleeps computer | PASS: Initiates system suspend | Retain existing API |
| `BtnQuickRestart` | Island Card 5 | "Restart" | 2-stage armed confirmation, then `shutdown.exe /r /t 2` | Reboots system with accidental click protection | PASS: Accidental protection works reliably | Retain safeguards |
| `BtnMusicPlayPause` | Island Card 0 | Play/Pause | Toggles local mock state & updates mock lyrics | Controls real Windows media session or native local player | FAILS: Hardcoded to fake "Paper Sky" demo track | Implement GSMTC listener + global media key fallback + native WPF `MediaPlayer` for local files |
| `BtnMusicNext` | Island Card 0 | Next Track | Increments index in mock array | Skips to next track in active media session | FAILS: Only loops 3 mock items | Route to GSMTC `TrySkipNextAsync` / `VK_MEDIA_NEXT_TRACK` / local player |
| `BtnMusicPrev` | Island Card 0 | Prev Track | Decrements index in mock array | Skips to previous track in active media session | FAILS: Only loops 3 mock items | Route to GSMTC `TrySkipPreviousAsync` / `VK_MEDIA_PREV_TRACK` / local player |
| Brightness Control | Dashboard Page 11 | Brightness Slider | Not present in UI | Controls display brightness | MISSING: No brightness control exists | Add Brightness tile with WMI/DXVA2 detection and `ms-settings:display` fallback |
| `BtnSysTaskMgr` | Island Card 4 | "Buka Task Manager" | `Start-Process taskmgr.exe` | Launches Windows Task Manager | PASS: Launches Task Manager | Retain |
| `BtnSysLaunchDash` | Island Card 5 | "Dashboard" | `Show-OceruDashboard` | Opens and activates Oceru Dashboard | PASS: Opens Dashboard | Retain |
