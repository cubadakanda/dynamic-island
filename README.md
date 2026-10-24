# Oceru Dynamic Island Desktop

![Version](https://img.shields.io/badge/version-2.0.0-00D2FF.svg) ![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6.svg) ![Design](https://img.shields.io/badge/design-Ocean%20Azure%20Glass-0EA5E9.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg)

Aplikasi smart notch, status bar & control center modern untuk Windows 10 & 11 buatan **Oceru** yang mengapung elegan di tepi atas layar laptop dengan filosofi desain **Ocean Azure Glass**.

---

## 🌊 Filosofi Desain: Ocean Azure Glass
- **Midnight Navy Glass Surfaces (`#070A12`):** Permukaan gelap elegan dan tenang dengan efek translucent blur.
- **Ocean Azure & Cyan Accents (`#00D2FF`, `#38BDF8`):** Aksen cahaya biru laut lembut tanpa silau neon berlebih.
- **Natural Floating Bezel:** Mengapung presisi di tengah atas layar tanpa tombol silang (`✕`) dan tanpa scrollbar putih.
- **Hardware Integration & Shared State:** Sinkronisasi status terpusat melalui `.oceru-state.json` yang menghubungkan Dynamic Island dan Oceru Dashboard.

---

## ✨ Fitur Unggulan Oceru Dynamic Island

### 1. Multi-Contextual Dynamic Island
Notch adaptif dengan 12 status kontekstual pintar:
- **Idle Mode:** Jam digital, indikator cuaca & suhu, persentase baterai laptop, dan status Jangan Ganggu / Game.
- **Resting Eyes (Karakter Berkedip):** Saat idle, jam beristirahat dan sepasang mata kapsul putih `( • • )` berkedip lembut dari dalam notch.
- **Media Playback Mode:** Mini pill pemutar audio dengan visualizer gelombang suara aktif dan lirik lagu ringkas.
- **Timer Running Mode:** Hitung mundur Pomodoro, Stopwatch, atau Countdown timer langsung di dalam notch.
- **Interactive Action Feedback Toast:** Pop-up feedback halus saat mengubah volume, mengunci layar, menyalin teks, atau beralih mode.
- **Expanded Quick Panel:** Panel kontrol 7 tab yang meluncur mulus dari notch saat disentuh atau diklik.

### 2. Full Oceru Dashboard (15 Destinasi Mandiri)
Jendela dashboard khusus 980×650 px dengan navigasi sidebar lengkap:
1. **Ringkasan (Overview):** Metrik CPU, RAM (*GlobalMemoryStatusEx*), baterai, audio, dan pintasan status.
2. **Dynamic Island:** Konfigurasi ukuran notch, posisi, transparansi, dan durasi auto-collapse.
3. **Media & Lirik:** Pemutar musik lengkap, visualizer gelombang suara, dan lirik sinkron gaya karaoke.
4. **Fokus Pomodoro:** Timer fokus dengan preset durasi instan (5m, 10m, 15m, 25m, 45m).
5. **Stopwatch:** Stopwatch presisi dengan pencatatan putaran (Lap time).
6. **Countdown Timer:** Penghitung mundur fleksibel untuk presentasi, memasak, atau istirahat.
7. **Monitor Sistem:** Pemantauan sumber daya CPU, RAM, penyimpanan SSD, dan koneksi jaringan.
8. **Pusat Notifikasi:** Riwayat pemberitahuan dengan filter Belum Dibaca, Tandai Semua Dibaca, dan Hapus Riwayat.
9. **Catatan Cepat (Notes):** Simpan ide instan dengan penyimpanan otomatis ke state persisten.
10. **Daftar Tugas (To-Do):** Checklist tugas harian dengan efek coret dan pelacak persentase progres.
11. **Riwayat Papan Klip (Clipboard):** Riwayat teks dan tautan yang disalin dengan tombol salin cepat 1-klik.
12. **Pengaturan Cepat (Quick Settings):** Sakelar cepat Wi-Fi, Bluetooth, Night Light, dan Mode Game.
13. **Peluncur Cepat (Quick Launcher):** Pintasan peluncur aplikasi favorit (Browser, Explorer, Terminal, Task Manager, Settings).
14. **Pengaturan (Settings):** Pemilihan tema (*Ocean Dark*, *Aero Glass*, *Cyberpunk*), opsi Startup, dan privasi.
15. **Tentang Oceru (About):** Informasi versi, arsitektur Direct3D WPF, dan diagnostik sistem.

### 3. Kontrol Sistem & Hardware Windows
- **Wi-Fi Flyout:** Membuka flyout jaringan bawaan Windows secara mulus via `ms-availablenetworks:`.
- **Bluetooth Quick Link:** Akses instan ke pengaturan perangkat Bluetooth.
- **Audio Master Live Slider & Mute:** Kontrol volume presisi dengan Win32 `WM_APPCOMMAND` dan visualisasi persentase instan.
- **Kunci Layar (Lock):** Memanggil API native `LockWorkStation` di `user32.dll` tanpa lag.
- **Mode Tidur (Sleep):** Mengaktifkan suspensi hemat daya Windows via `powrprof.dll`.
- **Restart Aman (Safe 2-Step Confirmation):** Tombol restart dengan konfirmasi 2 langkah untuk mencegah restart laptop yang tidak sengaja.

---

## 🚀 Cara Menjalankan & Menginstall

### Menjalankan Langsung:
- Cukup **klik dua kali `run-island.bat`** atau jalankan perintah PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\run-island.ps1
  ```

### Memasang Otomatis Aktif Saat Laptop Dinyalakan:
- Klik dua kali **`install.bat`** satu kali saja:
  1. Otomatis mendaftarkan Oceru Dynamic Island ke **Windows Startup**.
  2. Setiap kali login ke laptop, Oceru akan langsung aktif di atas layar.
  3. Shortcut juga dibuat di Desktop Anda.

### Menutup / Mematikan Oceru:
- **Cara 1:** Klik kanan pada notch kapan saja -> pilih **Tutup Oceru Dynamic Island (Keluar)**.
- **Cara 2:** Klik dua kali **`stop-island.bat`**.

### Mencopot dari Startup (Uninstall):
- Klik dua kali **`uninstall.bat`** untuk menghapus dari Windows Startup.
