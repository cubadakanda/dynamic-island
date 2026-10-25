# Implementation Plan: Network Speedometer & Ping HUD, Audio-Reactive Ambilight, and 20-20-20 Eye-Care Break

This implementation plan details the addition of three interactive features for the Oceru Dynamic Island on Windows (`run-island.ps1`):
1. **📊 Live Network Speedometer & Ping HUD:** Real-time download/upload speed metrics and ping/latency indicator across the compact status bar and Card 4 (System Hardware).
2. **🌈 Audio-Reactive Ambilight:** Soft, ambient pulsing cyan/ocean azure halo along the bottom curved perimeter of the notch when music is actively playing.
3. **🌿 20-20-20 Eye-Care Break:** Ergonomic health timer tracking 20 minutes of continuous activity, relaxing cat eyes into resting slits `(- -)`, and presenting an interactive 20-second countdown break toast with appreciative wink completion.

---

## 1. Architectural Changes & File Map

### Target File
- `D:\Project Orizzdev\dynamic-island\run-island.ps1`

### Component Enhancements
1. **Ambilight Vector Layer (`NotchAmbilightPath`):**
   - Placed in `MasterGrid` behind `NotchSinglePath`.
   - Uses identical geometry via `Get-NotchPathData`.
   - Cyan `#00D2FF` stroke with `DropShadowEffect BlurRadius="16"`.
   - Driven by 60 FPS animation loop with sine-wave breathing pulse when `$global:gsmtcPlaying -eq $true`.

2. **Network Speedometer & Ping HUD:**
   - Network delta polling via `System.Net.NetworkInformation.NetworkInterface.GetIPv4Statistics()`.
   - Async ping task via `System.Net.NetworkInformation.Ping.SendPingAsync("1.1.1.1", 1200)` without UI thread blocking.
   - Integration into `StatusGrid` (Compact Status Bar) with adjusted body width ($290\text{px}$) to comfortably accommodate Weather, Speedometer & Ping HUD, Clock, and Battery.
   - Integration into Card 4 (`CardSysWater`) next to RAM and Battery with real-time download and upload counters.

3. **20-20-20 Eye-Care Engine:**
   - Continuous user interaction tracking (cursor delta & keyboard activity).
   - Activity accumulator with auto-reset on 2-minute idle.
   - When reaching 20 minutes (or manual test trigger), activates 20s countdown toast and sets cat eyes to peaceful relaxation mode `(- -)`.
   - Completes with celebration toast and cat appreciation wink `(^ -)`.

---

## 2. Step-by-Step Task Decomposition

### Task 1: Add XAML Elements to `islandXaml`
- [ ] Add `NotchAmbilightPath` with `DropShadowEffect` in `MasterGrid`.
- [ ] Update `$statusBodyWidth = 290`, `$statusTotalWidth = 306`, `$statusLeftPos`.
- [ ] Add `CompactNetSpeedText` and `CompactPingText` inside `StatusGrid`.
- [ ] Add `SysNetDownloadText`, `SysNetUploadText`, and `SysPingText` inside Card 4 (`CardSysWater`).
- [ ] Verify XAML structure parses with 0 errors via `verify-xaml.ps1`.

### Task 2: Implement Real-Time Network & Ping Engine in PowerShell
- [ ] Define `$global:lastNetRxBytes`, `$global:lastNetTxBytes`, `$global:lastNetCheckTime`.
- [ ] Implement `Update-NetworkStats` function calculating download/upload rate in KB/s or MB/s.
- [ ] Implement non-blocking async ping dispatch every 3 seconds to `1.1.1.1` with colored dot status (`🟢 <60ms`, `🟡 60-150ms`, `🔴 >150ms`).
- [ ] Connect updates to `CompactNetSpeedText`, `CompactPingText`, and Card 4 elements in the 1-second timer tick.

### Task 3: Implement Audio-Reactive Ambilight Engine
- [ ] In `animTimer.Tick` (60 FPS):
  - When notch size changes, synchronize `NotchAmbilightPath.Data` with `NotchSinglePath.Data`.
  - When `$global:gsmtcPlaying -eq $true`:
    Compute dynamic breathing glow:
    $$\alpha(t) = 0.35 + 0.50 \cdot |\sin(t \cdot 0.0055)|$$
    Apply to `$notchAmbilightPath.Opacity`.
  - When music pauses/stops: smoothly decay opacity to 0.0.

### Task 4: Implement 20-20-20 Ergonomic Eye-Care Break System
- [ ] Define `$global:continuousWorkSeconds = 0`, `$global:eyeCareRemaining = 0`, `$global:eyeCareActive = $false`.
- [ ] In `mouseCheckTimer` (or `fastEyeTimer`):
  - Detect cursor movement; increment `$global:continuousWorkSeconds`.
  - If cursor idle $> 120\text{s}$, reset `$global:continuousWorkSeconds = 0`.
- [ ] When `$global:continuousWorkSeconds -ge 1200` (or `Trigger-OceruEyeCareBreak` is called):
  - Set `$global:eyeCareActive = $true`, `$global:eyeCareRemaining = 20`.
  - Set cat eyes to relaxed sleepy slits `(- -)`.
  - Show dynamic toast: `"🌿 20-20-20 Eye-Care (20s)"` with message `"Pandang objek berjarak 6 meter 🍃"`.
- [ ] In 1-second timer: decrement `$global:eyeCareRemaining`.
  - Update countdown display every second.
  - When reaching 0: call `Trigger-CatWink`, restore eyes, and fade toast.

### Task 5: Testing, AST Verification, and Visual Showcase
- [ ] Run AST verification script `verify-ast.ps1` to ensure syntax is clean.
- [ ] Run XAML verification script `verify-xaml.ps1`.
- [ ] Generate visual test rendering of:
  - 1. Ambilight glowing notch with playing music.
  - 2. Compact Status Bar with live Network Speed & Ping HUD.
  - 3. 20-20-20 Eye-Care 20s countdown toast.
  - 4. Card 4 System Monitor with full network statistics.
- [ ] Verify clean workspace with 0 stray `.bak*` files.
