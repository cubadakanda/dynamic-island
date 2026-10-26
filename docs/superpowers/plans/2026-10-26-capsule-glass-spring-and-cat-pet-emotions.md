# Capsule Glass, Spring Physics & Cat Pet Emotions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyulap Dynamic Island menjadi peliharaan virtual yang hidup dan ekspresif (partikel Zzz saat tidur, ekspresi emosional reaktif: cemas saat baterai lemah, senyum bahagia `^.^` saat dicharge, dengkuran manja saat dielus, dan kedipan playful wink saat musik), serta menyempurnakan bodi kapsul dengan refleksi kaca specular 2.5D, bayangan mengambang ambient, dan fisika pegas elastis (squash & stretch spring).

**Architecture:**
- **Lapisan Material Kapsul (XAML):**
  - Menambahkan bayangan melayang ambient (*elevation drop shadow*) pada bodi kapsul `NotchSinglePath`.
  - Menambahkan `NotchGlassHighlight` (path stroke kilau kaca 1.2px) dan `NotchTopGloss` (pantulan cahaya ruangan di bibir atas).
- **Fisika Animasi Pegas (Squash & Stretch Spring):**
  - Mengintegrasikan easing pegas (*spring curve*) pada interpolasi morphing di `$morphTimer` dan event klik pulau (`EyesGrid_MouseLeftButtonDown` & `BtnExpand_Click`).
- **Sistem Ekspresi Mata Kucing Peliharaan (Cat Pet System):**
  - **Partikel Zzz (`CatZzzCanvas`):** Tiga huruf z neon mengambang melayang naik saat idle > 5 menit.
  - **Ekspresi Baterai Lemah:** Mata sayu cemas dan pupil melebar saat baterai <= 20%.
  - **Senyum Bahagia Charging `^.^`:** Mata menyipit bulan sabit ceria saat charger dicolokkan.
  - **Interaksi Elus (*Head Petting*):** Sentuhan bolak-balik mouse memicu senyum manja `^.^`, getaran dengkur, dan suara purr sintetis.
  - **Musical Playful Wink:** Kedipan sebelah mata periodik saat mendengarkan musik.

**Tech Stack:** PowerShell 5.1, WPF/XAML, Win32 `GetLastInputInfo`, Procedural WAV Sound Synthesis.

---

## Tasks

### Task 1: Capsule Specular Glass Highlight & Ambient Elevation Shadow
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:1190-1230`

- [x] **Step 1:** Tambahkan `DropShadowEffect` pada `NotchSinglePath` untuk bayangan melayang ambient (*ambient elevation shadow*).
- [x] **Step 2:** Tambahkan elemen XAML `NotchGlassHighlight` untuk garis pantulan tepi kaca (specular rim).
- [x] **Step 3:** Sinkronisasikan geometri `NotchGlassHighlight.Data` pada setiap perubahan ukuran pulau agar garis kilau kaca selalu menempel sempurna pada bodi pulau.

### Task 2: Floating 'Zzz' Sleep Particles Overlay
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:1340-1420` & `10310-10350`

- [x] **Step 1:** Tambahkan `Canvas x:Name="CatZzzCanvas"` di dalam `EyesGrid` dengan 3 TextBlock partikel `z`, `z`, `Z` berwarna cyan/putih neon.
- [x] **Step 2:** Pada loop `$fastEyeTimer`, saat `$idleMs >= 300000` (tidur pulas), animasikan posisi Y partikel naik ke atas dan opasitasnya memudar secara berulang.
- [x] **Step 3:** Begitu pengguna aktif kembali (`$idleMs < 300000`), sembunyikan partikel seketika.

### Task 3: Cat Pet Emotional Reactions & Sound
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:5100-5300` & `10180-10400`

- [x] **Step 1:** Tambahkan generator audio sintetis dengkuran kucing (*purr vibration WAV*) di `New-OceruWavBytes`.
- [x] **Step 2:** Implementasikan ekspresi senyum bulan sabit bahagia `^.^` (dengan mengubah `CornerRadius` dan `Height`) saat kabel charger dicolokkan (`$global:catChargingHappyTicks = 60`).
- [x] **Step 3:** Implementasikan ekspresi cemas saat baterai lemah (`$batPct <= 20` dan tidak di-charge).
- [x] **Step 4:** Sempurnakan interaksi elus kepala (*head petting*) dengan suara purr dan mata senyum manja `^.^`.
- [x] **Step 5:** Implementasikan kedipan sebelah mata (*playful wink*) periodik setiap 6–8 detik saat musik sedang diputar di Card 0.

### Task 4: Squash & Stretch Spring Physics on Island Click
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:6650-6780`

- [x] **Step 1:** Tambahkan fase elastis *squash* (memampat kenyal 4px lebih pendek dan 8px lebih lebar selama 2 tick) sesaat sebelum memuai (*stretch*) saat pulau diklik.
- [x] **Step 2:** Terapkan transisi mendarat tenang (*settle*) tanpa getaran kaku.

### Task 5: Testing, Visual Capture & Verification
**Files:**
- Test: `scratch/test_live_pet_and_capsule.ps1`

- [x] **Step 1:** Jalankan script verifikasi untuk memotret antarmuka langsung:
  - Specular Glass Highlight & Ambient Shadow.
  - Partikel Zzz saat tidur.
  - Senyum `^.^` saat di-charge / dielus.
- [x] **Step 2:** Verifikasi PowerShell AST syntax (0 errors) dan XAML parsing.
