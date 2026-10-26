# Neon Apex Equalizer 3-Sided Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan visualizer audio **Neon Apex Spark & Dynamic Beat Bursts** 3-sisi penuh (Kiri, Bawah, Kanan) di Dynamic Island saat musik diputar, dengan efek tabung neon berlapis (white-hot core + chromatic bloom), titik pendaran LED mikro di setiap puncak gerigi (apex), dan lonjakan dinamis saat dentuman beat bass.

**Architecture:**
- Mengembangkan fungsi kalkulasi kurva vektor 3-sisi `Get-Notch3SidedWavePathData` dan `Get-NotchPathData3Sided` di `run-island.ps1` yang menghitung kurva kuadratik Gothic-Arch V-dip di sisi kiri (3 sirip), dasar bawah (15 gerigi), dan sisi kanan (3 sirip), serta menghasilkan koordinat titik ujung lancip (apex points).
- Menambahkan lapisan XAML tabung neon berlapis: `NotchWaveStrokePath` (outer neon glow), `NotchWaveCorePath` (white-hot core center line), dan `NotchApexCanvas` (koleksi titik pendaran LED neon mikro).
- Mengintegrasikan loop animasi 30Hz untuk menganimasikan perpindahan fase, modulasi amplitudo, deteksi beat burst acak terkoordinasi, dan sinkronisasi warna neon adaptif dengan warna cover art album.

**Tech Stack:** PowerShell 5.1, WPF (Windows Presentation Foundation), XAML Vector Geometries (`PathGeometry`, `QuadraticBezierSegment`, `DropShadowEffect`), Win32 Media API.

**Spec:** Visual Mockup Opsi 2 di `wave_concepts_report.md` & `scratch/generate_neon_apex_showcase.py`.

---

## Global Constraints

- Platform: Windows 10/11, PowerShell 5.1, .NET Framework 4.8 / WPF.
- Encoding: Seluruh file script harus disimpan dengan UTF-8 with BOM (`utf-8-sig`).
- Code Hygiene: DILARANG KERAS memuat nama atau referensi ke pihak ketiga eksternal / kompetitor di kode, komentar, maupun commit message.
- Performance: Loop animasi harus tetap ringan (di bawah 1% CPU) dan tidak mengganggu rendering UI lainnya.

---

## Review Focus

1. **Top Bezel Alignment:** Titik awal (`X=0, Y=0`) dan titik akhir (`X=totalW, Y=0`) harus tetap rata sempurna menempel pada bezel atas monitor tanpa celah atau distorsi.
2. **Smooth Fade In / Fade Out:** Saat musik dipause atau berganti ke card non-musik, gelombang dan titik LED harus meluruh (*decay*) secara mulus hingga opacity 0.
3. **Corner Radius Transition:** Lekukan bahu (`$s`) dan sudut bawah (`$r`) harus menyatu mulus (*tangential continuity*) dengan lekukan gerigi samping dan bawah.
4. **Adaptive Palette Sync:** Saat warna aksen cover album berganti, baik stroke luar neon, drop shadow, maupun titik apex LED harus ikut berganti warna secara sinkron.
5. **No Memory Leak:** Objek geometries yang dibuat berulang dalam loop harus di-parse secara efisien tanpa penumpukan handle GDI/WPF.

---

## Tasks

### Task 1: 3-Sided Vector Geometry Calculation Function
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:780-920`
- Test: `scratch/test_3sided_geometry.ps1`

- [ ] **Step 1:** Buat fungsi `Get-Notch3SidedWaveGeometry` yang menerima parameter `$totalW`, `$h`, `$s`, `$r`, `$waveAmp`, `$wavePhase`, `$beatMask`.
- [ ] **Step 2:** Implementasikan perhitungan kurva kuadratik untuk 3 sirip di sisi kiri, 15 gerigi di dasar bawah, dan 3 sirip di sisi kanan.
- [ ] **Step 3:** Kembalikan struktur objek yang memuat:
  - `BodyPath`: SVG Path data untuk bodi hitam pulau (`NotchSinglePath`).
  - `StrokePath`: SVG Path data untuk garis kontur luar tabung neon (`NotchWaveStrokePath` dan `NotchWaveCorePath`).
  - `ApexPoints`: Array koordinat `[PSCustomObject]@{ X = $px; Y = $py; IsBeat = $bool }` untuk posisi titik kilau LED.
- [ ] **Step 4:** Uji fungsi secara independen dengan `scratch/test_3sided_geometry.ps1` dan pastikan SVG path valid di WPF `[System.Windows.Media.Geometry]::Parse()`.

---

### Task 2: XAML Layers for Multi-Stage Neon & Apex Spark Canvas
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:1195-1210`

- [ ] **Step 1:** Di dalam `MasterGrid` XAML `run-island.ps1`, tambahkan:
  - `NotchWaveStrokePath`: Stroke tebal (2.8px) dengan `DropShadowEffect BlurRadius="12"`.
  - `NotchWaveCorePath`: Stroke tipis (1.2px) warna putih (`#FFFFFF`) / pastel neon dengan `DropShadowEffect BlurRadius="4"` untuk efek inti tabung neon panas (*white-hot core*).
  - `NotchApexCanvas`: Elemen `Canvas` transparan berukuran penuh dengan `IsHitTestVisible="False"` untuk menampung elemen-elemen titik LED mikro.
- [ ] **Step 2:** Daftarkan referensi objek WPF `$notchWaveCorePath` dan `$notchApexCanvas` di script PowerShell.
- [ ] **Step 3:** Buat helper inisialisasi pool titik LED mikro (21 elemen `Border` bulat dengan warna neon dan drop shadow glow) di dalam `$notchApexCanvas`.

---

### Task 3: 30Hz Animation Loop Integration & Beat Burst Mechanics
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:9740-9830`

- [ ] **Step 1:** Di dalam loop animasi 30Hz saat status musik `Playing` dan Card 0 aktif:
  - Naikkan `$global:wavePhase += 0.22`.
  - Hitung `$beatPulse`: deteksi ritme berkala untuk memicu lonjakan amplitudo 1.5x pada gerigi tertentu.
  - Panggil `Get-Notch3SidedWaveGeometry`.
- [ ] **Step 2:** Perbarui geometri `NotchSinglePath.Data`, `NotchWaveStrokePath.Data`, dan `NotchWaveCorePath.Data`.
- [ ] **Step 3:** Perbarui posisi dan ukuran titik pendaran LED di `$notchApexCanvas` sesuai koordinat `ApexPoints`.
- [ ] **Step 4:** Saat beat burst aktif, besarkan titik apex yang terkena beat dan ubah warnanya menjadi putih menyala dengan halo pendaran ganda.
- [ ] **Step 5:** Saat musik dipause atau card ditutup, luruhkan opacity dan amplitudo secara halus (`Lerp / Decay`) hingga 0.

---

### Task 4: Adaptive Palette Synchronization & Visual Verification
**Files:**
- Modify: `d:\Project Orizzdev\dynamic-island\run-island.ps1:10600-10630`
- Test: Live interactive test script `scratch/test_live_neon_apex.ps1`

- [ ] **Step 1:** Pastikan sinkronisasi warna neon (`NotchWaveStrokePath.Stroke`, `DropShadowEffect.Color`, dan LED Apex Glow) otomatis mengambil warna dominan cover album dari `$colorBrush` dan `$accentColor`.
- [ ] **Step 2:** Jalankan live test script WPF untuk memotret antarmuka langsung saat memutar lagu.
- [ ] **Step 3:** Verifikasi ketajaman neon, posisi titik apex di 3 sisi (kiri, bawah, kanan), serta transisi saat musik dimainkan dan dihentikan.
- [ ] **Step 4:** Lakukan pengecekan AST syntax PowerShell untuk memastikan 0 error.
