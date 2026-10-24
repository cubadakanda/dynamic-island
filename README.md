# Oceru Dynamic Island Desktop

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg) ![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg)

Aplikasi smart notch, status bar & control center modern untuk Windows 10 & 11 buatan **Oceru** yang mengapung elegan di tepi atas layar laptop.

## Fitur Unggulan Oceru Dynamic Island (Berdasarkan Referensi Video & Gambar)

1. **Resting Eyes (Mata Karakter Berkedip):** Saat laptop tidak melakukan aktivitas apa pun (idle beberapa detik), jam beristirahat dan sepasang mata kapsul putih imut `( • • )` akan keluar dan berkedip lembut dari dalam notch!
2. **Indikator Cuaca & Suhu Real-time:** Menampilkan cuaca `☀️ 28°` di samping jam digital dan persentase baterai saat notch dalam kondisi minimal.
3. **Pusat Kontrol & Aksi Sistem Windows:** Akses cepat tombol Wi-Fi, Bluetooth headset (*Baseus Encok*), Audio Mute, serta tombol aksi sistem langsung: **Kunci Layar (Lock)**, **Mode Tidur (Sleep)**, **Restart**, dan **Ganti Tema Visual**.
4. **Music from Any Player:** Pemutar audio dengan animasi gelombang suara, kontrol skip/pause, dan kotak pencarian lagu YouTube.
5. **Split Karaoke Synced Lyrics:** Mode lirik sinkron gaya karaoke dengan baris aktif menyala cyan neon saat musik dimainkan.
6. **Timer Presets Instan:** Pengatur waktu fokus dengan tombol durasi instan `5m`, `10m`, `15m`, `25m`, dan `45m`.
7. **Papan Klip (Clipboard History):** Daftar teks dan tautan yang baru saja disalin agar Anda bisa menyalinnya kembali dengan 1-klik tanpa perlu berpindah jendela.
8. **Catatan Cepat & To-Do:** Catat tugas harian, checklist interaktif dengan efek coret teks selesai, dan penghitung progres.
9. **Water Reminder (Pengingat Minum Air):** Pelacak hidrasi harian dengan target botol (2.000 ml / 8 gelas) dan tombol instan `+ 250 ml (1 Gelas)`.
10. **File Shelf:** Tarik & lepas file apa saja ke notch untuk menyimpan dan membawanya ke email, chat WhatsApp, atau folder lain.

> **Desain Alami Tanpa Tombol Silang (✕):**
> Notch Oceru dirancang menyatu secara mulus dengan bezel atas layar Anda layaknya hardware bawaan tanpa tombol silang window yang mengganggu. Untuk menutup aplikasi, cukup **klik kanan pada notch -> "Tutup Oceru Dynamic Island"** atau klik file `stop-island.bat`.

## Cara Menginstall (Otomatis Aktif Saat Menyalakan Laptop)

Cukup **klik dua kali file `install.bat`** satu kali saja:
1. Otomatis mendaftarkan Oceru Dynamic Island ke **Windows Startup**.
2. Setiap kali kamu menyalakan atau login ke laptop, Oceru akan **langsung otomatis aktif di atas layar** tanpa perlu kamu buka lagi.
3. Shortcut juga otomatis dibuat di Desktop kamu.

## Cara Menutup / Mematikan Oceru

Ada 2 cara mudah:
1. **Lewat Klik Kanan pada Notch:**
   - Klik kanan pada notch kapan saja -> pilih **Tutup Oceru Dynamic Island (Keluar)**.
2. **Lewat File Stop:**
   - Klik dua kali **`stop-island.bat`** di folder ini untuk langsung mematikannya.

## Cara Mencopot dari Startup (Disable Auto-Start)

Jika sewaktu-waktu ingin agar **tidak otomatis jalan saat laptop dinyalakan**:
- Klik dua kali **`uninstall.bat`**.
- Aplikasi akan langsung dicopot dari daftar startup Windows dan ditutup. (Jika nanti ingin mengaktifkannya lagi, cukup klik `install.bat` kembali).

## Mode Pengembangan (Live Hot-Reload saat Coding)

Kamu bisa terus mengembangkan fitur Oceru Dynamic Island sambil aplikasinya tetap berjalan di layar:
1. **Cara Instant Reload:**
   - Kapan pun kamu atau AI mengedit file `run-island.ps1`, cukup **Klik Kanan pada Notch -> pilih "Muat Ulang / Reload (F5)"** (atau tekan tombol `F5`). Tampilan akan langsung ter-update dalam 0.2 detik!
2. **Cara Otomatis (Watcher Mode):**
   - Buka folder `tools/` lalu klik dua kali **`tools/dev-island.bat`**.
   - Setiap kali file di-save (`Ctrl + S`), Oceru akan otomatis me-reload perubahannya secara instan.

## Struktur Folder Proyek

```text
dynamic-island/
├── 📁 docs/                   # Spesifikasi desain & perancangan arsitektur
├── 📁 tools/                  # Alat pengembang (Live Dev Watcher, Git push)
├── 📁 scripts/                # Skrip helper instalasi
├── 📁 legacy-web/             # Arsip prototipe lama berbasis web
├── 📄 README.md               # Dokumentasi lengkap Oceru
├── ⚡ run-island.bat          # [1-Klik] Menjalankan Oceru di layar
├── ⚡ install.bat             # [1-Klik] Memasang otomatis aktif saat laptop dinyalakan
├── ⚡ stop-island.bat         # [1-Klik] Menghentikan / menutup Oceru
├── ⚡ uninstall.bat           # [1-Klik] Mencopot dari Windows Startup
└── 🧠 run-island.ps1          # Mesin utama antarmuka WPF Direct3D
```

## Menjalankan Manual (Kapan Saja)

- Klik dua kali **`run-island.bat`** atau klik shortcut **Dynamic Island** di Desktop kamu.

## Fitur Utama

- **Top Notch Bezel:** Mengapung di tengah atas layar, transparan, dan selalu di depan (*always on top*).
- **File Shelf:** Drag file dari Desktop / Explorer ke notch untuk menyimpannya sementara.
- **YouTube Music & Lirik:** Kontrol musik, pencarian video YouTube, dan lirik sinkron.
- **Pomodoro Timer:** 25 menit fokus & 5 menit istirahat dengan format waktu yang akurat.
- **Status Bluetooth:** Indikator headset/TWS terkoneksi dan persentase baterai.
