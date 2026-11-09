# Brewtopia ☕ — Game Simulasi Kafe (Flutter)

Kelola kafe pseudo-3D: pelanggan masuk lewat pintu, memesan, kamu **meracik kopi lewat mini-game**,
**memanggang roti di oven**, menyajikannya, lalu pelanggan puas **nongkrong di meja**. Pesanan salah/gagal
otomatis dibuang ke tempat sampah. Percantik kafe, kerjakan misi harian, dan bersaing di papan peringkat.

## Versi 2.1 — perbaikan besar
- **Suara rapi**: tiap jenis efek punya jalur & prioritas sendiri (tidak bertumpuk), tanpa merebut audio focus
  (musik/dialog tidak saling mematikan), dialog diantre satu per satu, musik mengecil sebentar saat dialog.
- **Volume sinkron HP**: slider "Volume HP" di Pengaturan = volume media HP (dua arah dengan tombol volume).
  Musik, efek, dan dialog punya slider campuran masing-masing.
- Musik & suara berhenti saat app ke background, lanjut saat kembali. Tombol Keluar benar-benar menutup app.
- **Mudah dipahami**: tiket pesanan bergambar + nama menu, kotak petunjuk "langkah berikutnya", tutorial bergambar,
  target pendapatan harian dengan bintang, mode FEVER saat combo.
- **Kopi berbeda-beda**: ikon tiap menu, gelas terisi per lapisan (espresso, air, susu, busa) saat meracik.
- **Roti**: mini-game adonan, oven beberapa loyang sekaligus, alur sajikan yang jelas.
- Toko bergambar (stok biji/susu/tepung), HUD tanpa overflow, barista bisa diganti langsung, performa lebih lancar
  (gunakan `flutter run --release` untuk menilai kelancaran sebenarnya).

## Fitur utama
- **Meracik kopi (mini-game)**: Giling (ketuk cepat) → Seduh / Uap susu / Tuang (tahan, lepas di zona hijau). Kualitas
  *Sempurna/Bagus/Biasa/Gagal* menentukan bayaran & tip.
- **Roti & oven**: panggang donat/croissant/cheesecake (3 roti per loyang), angkat tepat waktu (terlambat = gosong),
  simpan di etalase, ketuk untuk menyajikan. Oven memanggang di latar sementara kamu melayani kopi.
- **Kafe hidup**: pintu membuka, langit di jendela mengikuti jam HP (siang/senja/malam + bintang), hujan, lampu
  gantung, uap mesin, partikel debu, parallax mengikuti kemiringan HP, bayangan & skala perspektif.
- **Pelanggan nyata**: 8 karakter (pria & wanita) berjalan dengan kaki bergantian, mengantre, duduk di meja
  (gaya nongkrong), mengobrol, lalu pulang. Tipe: normal, tidak sabar, dermawan, VIP, kritikus.
- **Dialog + suara**: dialog Bahasa Indonesia untuk pelanggan & barista, diucapkan via Text-to-Speech
  (nada pria/wanita sesuai gender karakter). Barista bisa dipilih pria/wanita.
- **Suara**: efek baru (pintu, lonceng, penggiling, mesin espresso, uap, koin, combo, sempurna, sampah, oven),
  musik lofi kafe buatan sendiri + lagu klasik (ganti lewat Pengaturan atau ketuk Jukebox).
- **Biar tidak bosan**: sistem hari (150 dtk) + ringkasan, event acak (jam sibuk, VIP, kritikus, hujan),
  reputasi bintang, combo, 3 misi harian, hadiah login harian (streak), stok bahan yang harus diisi,
  level membuka menu baru, upgrade, 14 dekor (estetika → pelanggan & tip naik), meja tambahan.
- **Lokasi Kafe (geolocation)**: simpan sampai 10 tempat nongkrong favorit, check-in harian per titik (radius 200 m)
  → koin + bonus pendapatan x1.5 selama 30 menit. Kota dipakai untuk peringkat kota.
- Firebase: login email/tamu, cloud save, papan peringkat dunia/kota, hapus akun.
- Background: pendapatan pasif + notifikasi (WorkManager), sinkron cloud saat offline.

> Catatan "3D": ini render **pseudo-3D** (perspektif lantai, kedalaman, bayangan, parallax, pencahayaan),
> bukan model 3D sungguhan. Model 3D penuh butuh engine terpisah dan membengkakkan risiko build.

## Peta materi kuliah → kode
| Materi | Penerapan | File utama |
|---|---|---|
| MVVM | Model `data/models`, View `views/`, ViewModel `viewmodels/` | `viewmodels/gameplay_view_model.dart` |
| Reactive state | `provider` + `ChangeNotifier`; animasi per frame lewat `FrameClock`; efek lewat `Stream<GameEvent>` | `views/game_screen.dart` |
| Dependency Injection | `get_it` (service, repository, ViewModel) | `app/di.dart` |
| Navigation | `go_router` + auth guard | `app/router.dart` |
| Firebase | Auth, Firestore (save + leaderboard) | `data/repositories/*` |
| Background operation | `workmanager` (idle income, sync cloud) | `core/background_service.dart` |
| Geolocation | `geolocator` + `geocoding`, banyak titik check-in | `viewmodels/locations_view_model.dart` |

## Menjalankan
```bash
flutter pub get      # butuh Flutter >= 3.38
flutter analyze
flutter test
flutter run
```
Tanpa Firebase, app jalan dalam mode offline. Publish ke Play Store: lihat **PANDUAN_PUBLISH.md**.

## Aset & lisensi
- `tools/` berisi skrip Python pembuat aset: `make_art_scene.py` (kafe, meja, dekor), `make_art_people.py`
  (varian karakter dari `tools/source/man.png`/`woman.png`), `make_audio.py` (SFX + musik lofi). Semua aset
  latar/suara buatan sendiri (tanpa watermark). Jalankan ulang bila ingin mengubah desain.
- Sprite karakter dasar `man.png`/`woman.png` & lagu `audio/bbg.ogg` berasal dari proyek awal kelompok:
  pastikan kamu punya hak pakai sebelum publish.

## Struktur
```
lib/
  app/ core/ (audio, voice/TTS, lokasi, notifikasi, background, dialog)
  data/models  (product, customer, decor, mission, upgrade, snapshot, event)
  data/repositories  (game lokal, auth, cloud)
  viewmodels/  gameplay, lobby, locations, leaderboard, settings, auth
  views/       game, lobby, locations, settings, ... + widgets/ (cafe_scene, craft_sheet, oven_sheet, shop_sheet)
assets/ scene (latar, meja, dekor)  people (karakter)  sfx  audio  images
```
