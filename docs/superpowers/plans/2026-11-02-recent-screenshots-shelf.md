# 5 Recent Screenshots Shelf Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambahkan fitur penyimpanan dan pratinjau 5 screenshot terakhir di kartu Shelf Dynamic Island dengan kemampuan seret-lepas (*native drag & drop*) instan ke aplikasi lain saat tombol PrtScn ditekan.

**Architecture:** Memanfaatkan Win32 `GetAsyncKeyState(0x2C)` dan WPF `System.Windows.Clipboard` pada DispatcherTimer untuk mendeteksi penekanan tombol `PrtScn`, mengodekan bitmap ke PNG dalam direktori cache `screenshots/` dengan rotasi FIFO 5 item, dan merender 5 thumbnail visual nyata di dalam sub-tab segmented kartu Shelf (Card 3) lengkap dengan OLE `DoDragDrop`.

**Tech Stack:** PowerShell 5.1/7+, WPF (XAML, PresentationFramework, PresentationCore, WindowsBase), Win32 API (`GetAsyncKeyState`), .NET IO & Imaging (`PngBitmapEncoder`).

**Spec:** [`docs/superpowers/specs/2026-11-02-recent-screenshots-shelf-design.md`](file:///D:/workspace/Project%20Orizzdev/dynamic-island/docs/superpowers/specs/2026-11-02-recent-screenshots-shelf-design.md)

## Global Constraints
- Seluruh perubahan kode pada `run-island.ps1` harus disimpan dengan encoding UTF-8 with BOM (`utf-8-sig`).
- Desain visual harus konsisten dengan Obsidian Glassmorphism dan tema warna Dynamic Island yang ada (latar gelap `#11141C`, aksen glowing cyan/sky blue `#38BDF8`).
- Kemampuan parkir file umum yang sudah ada di Card 3 tidak boleh hilang (keduanya hidup berdampingan via tab segmented).
- Batas maksimal tangkapan layar dalam cache dan memori tepat 5 item (FIFO).
- `DoDragDrop` harus menyediakan format data `[DataFormats]::FileDrop` untuk kompatibilitas seret ke aplikasi pihak ketiga (WhatsApp, Discord, dsb.).

## Review Focus
1. *Clipboard Lock Race Condition:* Tangani `COMException` atau `ExternalException` saat clipboard sedang diakses oleh aplikasi lain dengan `try-catch` dan fallback aman tanpa melempar runtime error.
2. *Debounce Duplikasi:* Cegah duplikasi tangkapan saat tombol PrtScn ditekan terus-menerus atau saat aplikasi Windows Snipping Tool memicu event ganda.
3. *File Lock saat Drag:* Pastikan `BitmapImage` yang dimuat sebagai thumbnail menggunakan `BitmapCacheOption.OnLoad` agar berkas PNG di disk tidak terkunci dan bebas dipindahkan/diseret.
4. *Persistensi Restart:* Direktori cache `screenshots/` harus dimuat secara otomatis saat startup sehingga 5 screenshot terakhir tetap ada meski aplikasi di-restart.
5. *Preservasi Fitur Parkir File Lama:* Perpindahan antara tab "📸 Screenshots" dan "📁 Parkir File" harus mempertahankan state file yang sedang diparkir tanpa merusak drop listener.

---

### Task 1: Screenshot Storage & FIFO Cache Engine

**Files:**
- Modify: `run-island.ps1` (Area fungsi helper ~line 8050)
- Create: `tests/test-screenshot-storage.ps1`

**Interfaces:**
- Produces:
  - `Initialize-ScreenshotStorage() -> string[]` (mengembalikan 5 path file screenshot yang ada di cache)
  - `Save-ClipboardScreenshot([System.Windows.Media.Imaging.BitmapSource]$bitmap) -> string` (menyimpan PNG baru, menjalankan FIFO rotasi <= 5)
  - `Clear-ScreenshotCache() -> void` (menghapus berkas cache dan me-reset state memori)

- [ ] **Step 1: Write test script `tests/test-screenshot-storage.ps1`**
Buat unit test mandiri untuk menguji logika rotasi FIFO 5 file, penyimpanan format PNG, dan pembersihan cache.

- [ ] **Step 2: Run test to verify it fails**
Jalankan test dan pastikan fungsi belum terdefinisi.
Run: `powershell -ExecutionPolicy Bypass -File tests/test-screenshot-storage.ps1`
Expected: FAIL ("CommandNotFoundException")

- [ ] **Step 3: Implement helper functions in `run-island.ps1`**
Tambahkan `Initialize-ScreenshotStorage`, `Save-ClipboardScreenshot`, dan `Clear-ScreenshotCache` dengan rotasi FIFO 5 item dan pemuatan non-locking `BitmapCacheOption.OnLoad`.

- [ ] **Step 4: Run test to verify it passes**
Run: `powershell -ExecutionPolicy Bypass -File tests/test-screenshot-storage.ps1`
Expected: PASS (5 item terkelola dengan rotasi rapi, berkas ke-6 menggusur berkas tertua)

- [ ] **Step 5: Commit**
`git commit -m "feat(shelf): implement screenshot storage and FIFO cache rotation"`

---

### Task 2: PrtScn Key Detection & Clipboard Capture Engine

**Files:**
- Modify: `run-island.ps1` (Area Win32 signature & mainTimer loop ~line 10570)
- Create: `tests/test-screenshot-detection.ps1`

**Interfaces:**
- Consumes: `Save-ClipboardScreenshot`, `ShowActionFeedback`
- Produces: `$global:lastPrtScnTick`, `Check-ScreenshotTrigger()`

- [ ] **Step 1: Write test script `tests/test-screenshot-detection.ps1`**
Buat skrip pengujian deteksi clipboard image dan debounce interval 1 detik.

- [ ] **Step 2: Run test to verify it fails**
Run: `powershell -ExecutionPolicy Bypass -File tests/test-screenshot-detection.ps1`
Expected: FAIL

- [ ] **Step 3: Implement Win32 `GetAsyncKeyState` & clipboard watcher in `run-island.ps1`**
Tambahkan deteksi `[Win32]::GetAsyncKeyState(0x2C)` (VK_SNAPSHOT) pada timer loop dengan debounce 1000ms. Saat terdeteksi, baca `[System.Windows.Clipboard]::GetImage()`, panggil `Save-ClipboardScreenshot`, beri notifikasi visual `ShowActionFeedback "📸 Screenshot Tersimpan di Shelf!"` dan kedipan mata kucing ceria.

- [ ] **Step 4: Run test to verify it passes**
Run: `powershell -ExecutionPolicy Bypass -File tests/test-screenshot-detection.ps1`
Expected: PASS

- [ ] **Step 5: Commit**
`git commit -m "feat(shelf): add PrtScn key detection and clipboard capture engine"`

---

### Task 3: Segmented Tab Shelf UI in XAML (`CardClipShelf`)

**Files:**
- Modify: `run-island.ps1` (XAML Card 3 `CardClipShelf` ~lines 2125-2200)

**Interfaces:**
- Produces:
  - `ShelfScreenshotsContainer` (Grid kontainer 5 thumbnail screenshot)
  - `ShelfScreenshotsList` (StackPanel horizontal untuk kartu screenshot)
  - `BtnTabScreenshots`, `BtnTabParkedFiles` (Tombol navigasi tab)
  - `Update-ScreenshotShelfUI()` (Render dinamis 5 slot kartu thumbnail)

- [ ] **Step 1: Update XAML for Card 3 in `run-island.ps1`**
Tambahkan tab switcher segmented di bagian atas `CardClipShelf` (`[📸 Screenshots (5)]` dan `[📁 Parkir File]`), kontainer `ShelfScreenshotsContainer` dengan 5 slot horizontal, serta empty placeholder state.

- [ ] **Step 2: Implement `Update-ScreenshotShelfUI` in `run-island.ps1`**
Buat fungsi perenderan visual 5 thumbnail nyata dengan resolusi proporsional, border cyan lembut, dan badge waktu ("Baru saja", "2m lalu", dsb.).

- [ ] **Step 3: Wire tab switcher event handlers**
Hubungkan event klik pada `BtnTabScreenshots` dan `BtnTabParkedFiles` untuk berganti tampilan secara instan dengan efek transisi lembut.

- [ ] **Step 4: Verify XAML parser syntax**
Run: `powershell -ExecutionPolicy Bypass -File scratch/verify-xaml.ps1`
Expected: PASS (0 errors)

- [ ] **Step 5: Commit**
`git commit -m "feat(ui): add segmented tabs and 5-screenshot shelf layout in CardClipShelf"`

---

### Task 4: Native Drag-and-Drop & Interaction Wiring

**Files:**
- Modify: `run-island.ps1` (Area event handler shelf ~line 8230)

**Interfaces:**
- Consumes: `Update-ScreenshotShelfUI`, `Clear-ScreenshotCache`

- [ ] **Step 1: Wire `DoDragDrop` for screenshot thumbnails**
Pasang event `PreviewMouseLeftButtonDown` dan `PreviewMouseMove` pada setiap border thumbnail screenshot untuk memicu `[System.Windows.DragDrop]::DoDragDrop` dengan format `[DataFormats]::FileDrop` dan `[DataFormats]::Bitmap`.

- [ ] **Step 2: Wire double-click action**
Pasang event klik ganda pada thumbnail untuk membuka file gambar langsung di penampil foto default Windows (`Start-Process $filePath`).

- [ ] **Step 3: Wire Contextual Clear Button**
Perbarui handler `BtnHeaderClearShelf` agar membersihkan `screenshots/` saat tab Screenshot aktif, atau membersihkan file parkir saat tab Parkir File aktif.

- [ ] **Step 4: Verify AST & script integrity**
Run: `powershell -ExecutionPolicy Bypass -File scratch/verify-ast.ps1`
Expected: PASS (0 errors)

- [ ] **Step 5: Commit**
`git commit -m "feat(shelf): wire native drag-and-drop and double-click handlers for screenshots"`

---

### Task 5: End-to-End Validation, Snapshot Test & Push to Remote

**Files:**
- Create: `scratch/test_live_screenshot_shelf.ps1`
- Push to GitHub: `origin/main`

- [ ] **Step 1: Execute live test script**
Simulasikan penambahan screenshot ke clipboard, picu fungsi watcher, dan verifikasi bahwa 5 thumbnail muncul di `CardClipShelf` dengan format data drag yang valid.

- [ ] **Step 2: Verify non-regression on Existing Modes**
Pastikan Eyes mode (104x36), Status mode (356x36), dan Expanded mode (576x205) tetap simetris tanpa cutoff dan tanpa lag.

- [ ] **Step 3: Commit & Push to GitHub**
Run: `git push origin main`
Expected: Selesai dengan status up-to-date di repository.
