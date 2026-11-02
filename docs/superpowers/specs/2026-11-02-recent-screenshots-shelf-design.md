# Desain Fitur: 5 Screenshot Terakhir di Dynamic Island Shelf (Opsi B)

## 1. Ringkasan & Tujuan (Intent & The Why)
Fitur ini mempermudah pengguna setelah mengambil screenshot (terutama dengan tombol shortcut `PrtScn`) untuk langsung mengambil dan menyeret (*drag & drop*) hasil tangkapan layar tersebut dari Dynamic Island ke aplikasi lain (seperti WhatsApp, Discord, email, browser, atau dokumen), tanpa harus membuka File Explorer atau folder penyimpanan manual.

Dynamic Island akan secara otomatis mencatat dan menyimpan **5 screenshot terakhir** ke dalam kartu **Shelf** (Card 3 di mode Expanded), lengkap dengan thumbnail gambar nyata dan dukungan seret (*drag-and-drop*) instan.

---

## 2. Sasaran & Batasan (Goals, Non-Goals, Anti-Goals)

### Goals
- **Pendeteksian Otomatis:** Memantau pengambilan screenshot secara otomatis saat tombol `PrtScn` ditekan menggunakan deteksi key state Win32 `GetAsyncKeyState(0x2C)` dikombinasikan dengan pemantauan gambar `System.Windows.Clipboard` dan folder tangkapan layar Windows.
- **Buffer 5 Screenshot Terakhir:** Menyimpan tepat 5 tangkapan layar terbaru dalam format PNG di folder cache lokal (`screenshots/`). Menggunakan mekanisme FIFO (item terbaru menjadi slot #1, item ke-6 otomatis tergeser keluar).
- **Integrasi Kartu Shelf (Opsi B - Tab Segmented):** Mengintegrasikan 5 slot thumbnail screenshot di Card 3 (`CardClipShelf`) di samping tab Parkir File yang sudah ada melalui kontrol tab segmented `[📸 Screenshots (5)]` dan `[📁 Parkir File]`.
- **Thumbnail Gambar Nyata:** Menampilkan preview gambar visual nyata beresolusi proporsional di dalam setiap slot, border aksen sky blue, dan penanda waktu ("Baru saja", "2m lalu", dsb.).
- **Native OLE Drag & Drop:** Pengguna dapat menahan klik kiri pada thumbnail dan langsung menyeretnya (*drag & drop*) ke WhatsApp, Telegram, Discord, Word, Figma, browser, atau folder lokal menggunakan `[System.Windows.DragDrop]::DoDragDrop` dengan format `FileDrop`.
- **Indikasi Visual Tangkapan:** Saat screenshot berhasil dideteksi, Dynamic Island menampilkan notifikasi kilau / aksi singkat (*ShowActionFeedback*) dan kedipan mata kucing ceria sebagai penanda.
- **Persistensi Antar Sesi:** Saat Dynamic Island dijalankan ulang atau laptop di-restart, 5 screenshot terakhir tetap tersedia di kartu Shelf.

### Non-Goals
- Tidak menggantikan alat screenshot sistem operasi Windows (Snipping Tool / Windows Clipboard History).
- Tidak memantau atau mengganggu konten clipboard berupa teks, file link, atau HTML.
- Tidak menyimpan riwayat tanpa batas; kapasitas dibatasi tepat 5 item terakhir sesuai permintaan pengguna.

### Anti-Goals
- Jangan menyebabkan DWM freeze atau UI lag saat menyimpan gambar ke disk (encoding PNG dijalankan secara efisien).
- Jangan menyebabkan crash akibat *Clipboard Locked* (harus ditangani dengan aman via `try-catch`).
- Jangan menghilangkan kemampuan parkir file biasa yang sudah ada di Shelf (kedua fitur hidup berdampingan via sub-tab).

---

## 3. Keputusan Desain & Perilaku Detail (Decided Architecture)

### 3.1 Koeksistensi di Card 3 (`CardClipShelf`)
- Card 3 dilengkapi dengan header switcher:
  - Tab 1: **📸 Screenshots (5)** (Default aktif jika ada screenshot baru).
  - Tab 2: **📁 Parkir File** (Fitur drop zone universal yang sudah ada tetap utuh 100%).
- Tombol **Clear** di header bekerja secara kontekstual:
  - Saat di tab Screenshot: Mengosongkan 5 screenshot dan membersihkan cache gambar yang sudah dihapus.
  - Saat di tab Parkir File: Mengosongkan file yang sedang diparkir.

### 3.2 Kriteria Deteksi & Rekonsiliasi Sumber Ganda
- Deteksi primer: `GetAsyncKeyState(0x2C)` (Tombol `PrtScn` / Print Screen).
- Saat tombol ditekan, timer mendeteksi sinyal, menunggu 200ms hingga OS/Snipping Tool menyelesaikan pembuatan gambar, lalu membaca `[System.Windows.Clipboard]::GetImage()`.
- Debounce window: Menggunakan timestamp dan hash ukuran gambar untuk mencegah duplikasi (jika `Win+PrtScn` memicu clipboard sekaligus file di `Pictures\Screenshots`, hanya 1 entri yang dicatat).
- Menyimpan berkas gambar baru ke `screenshots/screenshot_YYYYMMDD_HHmmss.png`.

### 3.3 Siklus Hidup Cache & Persistensi
- Folder cache: `D:\workspace\Project Orizzdev\dynamic-island\screenshots\`.
- Saat startup (`run-island.ps1` dibuka): Membaca direktori `screenshots/`, mengurutkan berdasarkan waktu pembuatan terbaru, dan memuat hingga 5 gambar terakhir ke dalam memory state `$global:screenshotHistory`.
- Saat item ke-6 masuk (FIFO eviction): Gambar tertua dikeluarkan dari daftar dan berkas cache lamanya dihapus agar ukuran disk tetap kecil (~2-5 MB).
- Saat tombol Clear diklik: Seluruh berkas di folder `screenshots/` dibersihkan dan UI diperbarui menjadi 5 slot kosong (*empty placeholders*).

### 3.4 Interaksi & Drag-and-Drop
- **Klik & Seret (Drag):** Menginisiasi `[System.Windows.DragDrop]::DoDragDrop` dengan parameter `DataObject([DataFormats]::FileDrop, @($filePath))` dan `DataObject([DataFormats]::Bitmap, $bitmapSource)`.
- **Klik 2x (Double Click):** Membuka gambar di photo viewer bawaan Windows (`Start-Process $filePath`).
- **Hover:** Efek glowing border cyan/sky blue (`#38BDF8`) dengan efek transisi lembut.
