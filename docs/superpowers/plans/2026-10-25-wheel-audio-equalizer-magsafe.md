# Implementation Plan: Scroll HUD, Sound FX, Mini Equalizer & MagSafe Pulse

This plan implements 4 interactive features for Oceru Dynamic Island on Windows (`run-island.ps1`):
1. **🎚️ Scroll-Wheel Volume & Brightness HUD:** Mouse wheel scrolling over the notch adjusts system volume, and `Shift` + scroll adjusts screen brightness with a responsive dynamic toast HUD.
2. **🔊 Soft Audio Feedback Engine:** Procedural, zero-dependency cozy sound effects for virtual pet interactions (cute lo-fi meow/purr), water drinking (+250ml crisp droplet), and adzan chime.
3. **🎵 Mini Equalizer Visualizer in Status Bar:** Dancing 4-bar mini equalizer in the compact status bar during active music playback; clicking directly opens Music Card 0.
4. **⚡ MagSafe Charging Glow Pulse:** Dynamic emerald green charging wave contour pulse and lightning indicator whenever the AC power charger is connected.

---

## 1. File Map & Subsystem Responsibilities

### Target File
- `D:\Project Orizzdev\dynamic-island\run-island.ps1`

### Helper Test Scripts
- `scratch/test-sound-gen.ps1` (Test in-memory WAV sound synthesis)
- `scratch/test-scroll-wheel.ps1` (Test volume & brightness WMI hooks)

### Subsystem Changes
1. **Mouse Wheel Handler (`$window.Add_MouseWheel`):**
   - Intercepts vertical mouse scroll on notch bounds.
   - Normal scroll $\rightarrow$ adjust Windows Master Volume via `[OceruAudioManager]`.
   - `Shift` + scroll $\rightarrow$ adjust Display Brightness via WMI `WmiMonitorBrightnessMethods`.
2. **Cozy Audio Synthesizer (`Play-OceruSound`):**
   - Generates compact in-memory PCM WAV streams played asynchronously via `System.Media.SoundPlayer`.
   - Sounds: `meow` (petting & greeting), `water` (water intake +250ml), `chime` (adzan & charger connected).
   - Global mute flag `$global:soundFxMuted`.
3. **Status Bar Mini Equalizer (`BtnMiniEqualizer`):**
   - 4 animated vertical rounded borders in `StatusGrid`.
   - Visible only when `gsmtcPlaying -eq $true`.
   - Dynamically color-synced with active track album art.
   - Click event opens Card 0.
4. **MagSafe Charger Transition (`Start-MagSafeChargingPulse`):**
   - Detects `GetACLineStatus` transition $0 \rightarrow 1$.
   - Triggers 1.8s emerald green contour pulse with lightning glyph `0xE945` and battery percentage.

---

## 2. Step-by-Step Task Breakdown

### Task 1: Procedural Sound Feedback Engine (`Play-OceruSound`)
- [ ] Add `New-WavMemoryStream` and `Play-OceruSound` helper in `run-island.ps1`.
- [ ] Hook `Play-OceruSound "meow"` to Petting detection and Double-click greeting.
- [ ] Hook `Play-OceruSound "water"` to `BtnAddWater.Add_Click`.
- [ ] Hook `Play-OceruSound "chime"` to Adzan trigger and Charger plugged-in event.

### Task 2: Scroll-Wheel Volume & Brightness HUD
- [ ] Implement `Set-SystemBrightness` helper using WMI.
- [ ] Add `$window.Add_MouseWheel` event handler in `run-island.ps1`.
- [ ] Implement volume step (delta $\pm 4\%$) when normal scroll.
- [ ] Implement brightness step (delta $\pm 5\%$) when `Shift` key is held.
- [ ] Trigger non-intrusive dynamic toast HUD with responsive level display.

### Task 3: Mini Equalizer Visualizer in Compact Status Bar
- [ ] Add `BtnMiniEqualizer` XAML in `StatusGrid` right column next to battery.
- [ ] Bind `$btnMiniEqualizer`, `$miniEqBar1`..`$miniEqBar4` in `FindName`.
- [ ] In `fastEyeTimer`, animate equalizer heights and update visibility based on `$global:gsmtcPlaying`.
- [ ] In `mainTimer`, adapt bar fill color to `$global:currentMediaAccent`.
- [ ] Wire click on `BtnMiniEqualizer` to switch carousel to Card 0.

### Task 4: MagSafe Charging Glow Pulse
- [ ] Detect transition from AC status 0 to 1 in `fastEyeTimer`.
- [ ] Trigger 1.8s emerald wave contour pulse on `NotchWaveStrokePath`.
- [ ] Show dynamic charging capsule toast (`⚡ Mengisi Daya Terhubung`).
- [ ] Play soft connected chime.

### Task 5: Verification & Visual Showcase
- [ ] Verify PowerShell AST with `verify-ast.ps1`.
- [ ] Verify WPF XAML with `verify-xaml.ps1`.
- [ ] Generate visual renders and composite showcase artifact.
