# Implementation Plan: 3 New Interactive Feature Packages for Oceru Dynamic Island

## Feature Package Scope
1. **⚡ Charging Connect Pulse:**
   - Detects AC power plug/unplug events in real time via `GetSystemPowerStatus`.
   - Triggers a dynamic 2.5s hardware toast with green lightning glyph, battery percentage, and charging state, then smoothly returns to Eye mode.
2. **📂 Universal File Drop Shelf (Drag to Notch):**
   - Configures `$window.AllowDrop = $true` for whole-window drag detection.
   - When files are dragged over the top notch, it automatically expands and flips to Card 3 (Shelf), highlighting the drop zone.
   - When dropped, stores parked files with 3 instant action triggers: *Salin Path*, *Kompres ke ZIP*, and *Buka Folder*.
3. **🐱 Rich Cat Eye Personalities:**
   - 😴 **Mata Mengantuk / Tidur:** After 23:00 or after 5 mins cursor idle, eyes narrow to sleepy slits `(- -)` with gentle breathing animation.
   - 😉 **Kedipan Apresiasi:** Triggers a playful wink `(^ -)` when To-Do tasks are checked or Pomodoro focus sessions finish.
   - 😮 **Ekspresi Baterai Lemah:** Pupils dilate in alarm when battery drops $\le 15\%$ and not charging.
   - 🎵 **Audio Bop:** Eyes bob rhythmically up and down when YouTube or Windows Media is actively playing.

---

## File Structure & Proposed Changes
- **Target File:** `D:\Project Orizzdev\dynamic-island\run-island.ps1`
  - In `islandXaml`:
    - Ensure `$window` has `AllowDrop="True"`.
    - Enhance Card 3 (`ShelfDropBorder`) with action buttons panel (`BtnShelfCopyPath`, `BtnShelfZip`, `BtnShelfOpenFolder`).
  - In PowerShell Script:
    - Wire `PowerStatus` AC Line listener to `Show-OceruDynamicToast`.
    - Wire window DragEnter, DragOver, DragLeave, and Drop events.
    - Implement `Handle-DroppedFiles` with Zip, Copy Path, and Open Folder logic.
    - Wire Cat Eye mood manager (`Trigger-CatWink`, Sleep state, Low battery dilate, and Audio Bop transform).
    - Connect To-Do checkboxes (`$cbTask1`, `$cbTask2`, `$cbTask3`) and Pomodoro completion to `Trigger-CatWink()`.

---

## Task Decomposition

### Task 1: ⚡ Charging Connect Pulse Implementation
- Add `$global:lastAcLineStatus = -1` in script initialization.
- In `powerCheckTick`, compare `$powerStatus.LineStatus` against `$global:lastAcLineStatus`.
- On state change from battery to charging (0 -> 1):
  Call `Show-OceruDynamicToast "Pengisi Daya Terhubung" "$batPct% • Mengisi Daya Cepat" ([char]0xEA94) "#10B981" 2500`.
- On state change from charging to battery (1 -> 0):
  Call `Show-OceruDynamicToast "Pengisi Daya Dicabut" "$batPct% • Menggunakan Baterai" ([char]0xEA93) "#F59E0B" 2200`.

### Task 2: 📂 Universal File Drop Shelf & Action Handlers
- Set `AllowDrop="True"` on `$window`.
- Wire `Add_DragEnter` to auto-expand the notch and navigate to Card 3 (Shelf).
- Implement `Handle-DroppedFiles($files)` to store in `$global:parkedShelfFiles`.
- Add quick actions:
  - Copy Path: `[System.Windows.Clipboard]::SetText(...)`
  - Compress to Zip: `Compress-Archive`
  - Open in Explorer: `explorer.exe /select`

### Task 3: 🐱 Cat Eye Personalities & Mood Engine
- Implement Sleepy mode:
  When hour $\ge 23$ or $< 5$, or idle $> 5$ mins, eyes narrow to 2.5px with soft breathing sine wave.
- Implement Appreciation Wink (`Trigger-CatWink`):
  Left eye winks shut for 350ms, then pops open with micro-bounce.
  Wire to `$cbTask1`, `$cbTask2`, `$cbTask3` checked events and Pomodoro session completion.
- Implement Low Battery Panic:
  When battery $\le 15\%$ and not charging, pupil widens to 7px.
- Implement Audio Bop:
  When `$global:gsmtcPlaying -eq $true`, apply rhythmic vertical bounce `Y_bob = Abs(Sin(t * 0.12)) * 2.8` on `$catEyesContainer`.

### Task 4: Verification & Screenshots
- Verify AST syntax with `verify-ast.ps1`.
- Verify XAML syntax with `verify-xaml.ps1`.
- Capture visual states of:
  1. Charging Toast (`option_b_charging_toast.png`)
  2. Cat Eye Sleepy & Audio Bop (`option_b_cat_expressions.png`)
  3. Drag Drop Shelf with action buttons (`option_b_drop_shelf.png`)
- Confirm repo cleanliness with 0 untracked `.bak*` files.
