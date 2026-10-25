# Implementation Plan: Dynamic Album Art Color-Sync, Interactive Cat Pet Play & Purr, and Indonesian Prayer HUD

This plan outlines the implementation of 3 interactive features for Oceru Dynamic Island on Windows (`run-island.ps1`):
1. **🎨 Dynamic Album Art Color-Sync:** Real-time color extraction from active media thumbnail (with dynamic genre/palette hashing fallback) so the sharp audio wave and glow change colors adaptively for every track.
2. **🐱 Interactive Cat Pet Engine:** Playful cursor-chasing reactions (pupil dilation & micro-pounce wiggles when mouse moves quickly), petting/scratch happiness response `(^ ^)` with purr breathing, and double-click greeting interactions.
3. **🕌 Indonesian Prayer Times & Adzan HUD:** Precise astronomical calculation for Indonesian prayer times (Subuh, Dzuhur, Ashar, Maghrib, Isya), next prayer countdown in the compact bar, and dynamic adzan notification toasts.

---

## 1. File Map & Subsystem Responsibilities

### Target File
- `D:\Project Orizzdev\dynamic-island\run-island.ps1`

### Components & Handlers
1. **Album Art Color Extraction (`Get-MediaAccentColor`):**
   - Extracts dominant vibrant color from `props.Thumbnail` stream if available.
   - Fallback palette generator derived from track title / artist hash (Neon Magenta, Ocean Cyan, Sunset Amber, Acid Lime, Royal Violet, Cyberpunk Coral).
   - Smoothly interpolates `NotchWaveStrokePath.Stroke` and `NotchWaveStrokePath.Effect.Color` to the detected accent.

2. **Interactive Cat Pet & Cursor Play Engine:**
   - Tracks cursor velocity ($\Delta x, \Delta y$ over time).
   - When cursor wiggles quickly near the notch, pupils dilate to hunting mode ($5.5\text{px}$) with playful head tilt (`CatEyesTransform.Y`).
   - Petting / Rub detector: when cursor moves back and forth over `EyesGrid` ($\ge 3$ strokes), eyes squint happily `(^ ^)` with soft purr pulse.
   - Double-click on `EyesGrid`: Playful double wink `(^ ^)` and friendly greeting toast.

3. **Indonesian Prayer Times Engine (`Get-IndonesianPrayerTimes`):**
   - Solar calculation engine based on Kemenag RI parameters (Subuh 20°, Isya 18°, local timezone auto-detection).
   - Default coordinate: Jakarta / WIB (`-6.2088, 106.8456`) or auto-adjusted to local UTC offset.
   - Real-time countdown tracking to next prayer.
   - Adzan trigger: when prayer time matches, activates dynamic toast with emerald green glow and mosque icon `🕌`.

---

## 2. Step-by-Step Task Breakdown

### Task 1: Implement Dynamic Album Art Color-Sync
- [ ] Add `Get-MediaAccentColor` function in `run-island.ps1`.
- [ ] In `mainTimer`, when track changes, call `Get-MediaAccentColor` and update `$global:waveStrokeColor`.
- [ ] Update `NotchWaveStrokePath.Stroke` and `DropShadowEffect.Color` with the new track color.

### Task 2: Implement Interactive Cat Pet & Cursor Play Engine
- [ ] Add cursor velocity and petting counters in `fastEyeTimer`.
- [ ] Implement hunting pupil dilation ($3.8\text{px} \rightarrow 5.5\text{px}$) when cursor moves quickly nearby.
- [ ] Implement petting / rubbing detection on `EyesGrid` triggering happy eyes `(^ ^)` and purr animation.
- [ ] Wire `MouseDoubleClick` on `EyesGrid` for playful double wink and greeting toast.

### Task 3: Implement Indonesian Prayer Times & Adzan Reminder
- [ ] Add `Get-IndonesianPrayerTimes` calculation function.
- [ ] In `mainTimer` (1-second tick), calculate remaining time to next prayer.
- [ ] Add prayer display to `StatusGrid` and Card 4.
- [ ] Trigger dynamic toast notification when adzan time arrives.

### Task 4: Verification, AST Parsing, and Visual Showcase
- [ ] Verify PowerShell AST with `verify-ast.ps1`.
- [ ] Verify WPF XAML with `verify-xaml.ps1`.
- [ ] Generate visual captures of:
  1. Album Art Color-Sync on sharp wave (Multiple track colors).
  2. Happy cat pet squinting `(^ ^)` and curious hunting eyes.
  3. Prayer time HUD and Adzan toast.
- [ ] Verify clean git working tree.
