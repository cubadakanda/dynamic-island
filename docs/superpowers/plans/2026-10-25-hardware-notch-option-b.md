# Implementation Plan: Option B — Hardware Notch Terpadu (Single Path Bezier Shoulder)

## Overview
Implement Option B (Hardware Notch Terpadu) for Oceru Dynamic Island in `run-island.ps1`. This replaces any composite borders or separate ear paths with a single, continuous, mathematically exact SVG/WPF vector path (`NotchSinglePath`). The top edge flairs out smoothly into the screen bezel using tangential concave shoulder arcs, while the bottom corners curve with convex pill radii.

---

## File Structure & Proposed Changes
- **Target File:** `D:\Project Orizzdev\dynamic-island\run-island.ps1`
  - In `islandXaml`:
    - Remove `NotchBody` `<Border>` and any auxiliary borders.
    - Add a single master vector path: `<Path x:Name="NotchSinglePath" Fill="#000000" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>`.
    - Adjust internal grids (`EyesGrid`, `StatusGrid`, `ExpandedGrid`, `DynamicToastGrid`) with proper margins to center content cleanly inside the notch body.
  - In PowerShell Script:
    - Add `Get-NotchPathString($totalW, $h, $s, $r)` function.
    - Update `Set-IslandMode($mode)` to target `$global:toBodyW`, `$global:toH`, `$global:toL`, `$global:toS`, `$global:toR`.
    - Update `$global:animTimer.Add_Tick` to interpolate dimensions and update `$notchSinglePath.Data = [System.Windows.Media.Geometry]::Parse(...)`.
- **Validation Scripts (kept in brain scratch directory):**
  - `verify-ast.ps1`
  - `verify-xaml.ps1`
  - Visual verification script to render and save live screenshots of all 4 modes.

---

## Task Decomposition

### Task 1: Single Path Geometry Helper & XAML Definition
- Define the single path string builder:
  `M 0,0 A s,s 0 0,1 s,s L s,h-r A r,r 0 0,0 s+r,h L w-s-r,h A r,r 0 0,0 w-s,h-r L w-s,s A s,s 0 0,1 w,0 Z`
- In `islandXaml`, replace `NotchBody` with `<Path x:Name="NotchSinglePath" Fill="#000000" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>`.
- Set initial Window dimensions: Width = 104 (88 + 16), Height = 36.

### Task 2: Animation & Mode Switching Wireup
- Configure mode targets with shoulder radius $s = 8$:
  - `eyes`: bodyW = 88, totalW = 104, h = 36, r = 18
  - `status`: bodyW = 230, totalW = 246, h = 36, r = 18
  - `expanded`: bodyW = 560, totalW = 576, h = 205, r = 24
  - `toast`: bodyW = 360, totalW = 376, h = 36, r = 18
- In `animTimer.Add_Tick`, dynamically calculate `$curTotalW`, `$curH`, `$curL`, and update `$notchSinglePath.Data`.
- In completion block, guarantee clean final geometry.

### Task 3: Content Alignment & Clipping
- Ensure `ExpandedGrid` has its solid black backing clipped or contained within the single path geometry.
- Ensure cursor hover detection uses the dynamic window bounds so hover-to-expand remains responsive and natural.

### Task 4: Verification & Screenshots
- Run `verify-ast.ps1` (expect 0 errors).
- Run `verify-xaml.ps1` (expect 0 errors).
- Render and capture all 4 modes to `island_option_b_showcase.png`.
- Confirm zero untracked `.bak*` files in repository root.
