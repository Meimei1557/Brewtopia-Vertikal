# Panduan Publish Brewtopia ke Google Play

> Catatan jujur: proyek ini ditulis & dicek sintaksnya, tetapi **belum dikompilasi** di lingkungan pembuatnya
> (Flutter SDK tidak bisa diunduh di sana). Jalankan langkah 1 dulu; bila ada error kompilasi kecil
> (misal beda versi paket), perbaiki sesuai pesan `flutter analyze`.

## 1. Siapkan & uji
```bash
flutter --version          # pakai Flutter stabil terbaru (Dart >= 3.9)
flutter pub get
flutter analyze
flutter test
flutter run                # coba di HP/emulator (mode offline bila Firebase belum diset)
```
Bila `flutter pub get` mengeluhkan versi paket, jalankan `flutter pub upgrade --major-versions`.
Jika folder `android/` bermasalah: `flutter create . --platforms=android` lalu pulihkan `android/app/build.gradle.kts`, `AndroidManifest.xml`, dan `MainActivity.kt` dari proyek ini.

## 2. Firebase
1. https://console.firebase.google.com → **Add project**.
2. **Add app → Android**, package name: `com.kel4.brewtopia` (ubah ke milikmu sendiri bila mau; `com.example.*` ditolak Play).
   Ganti di: `android/app/build.gradle.kts` (namespace & applicationId), folder `android/app/src/main/kotlin/...`, `MainActivity.kt`.
3. Unduh **google-services.json** → taruh di `android/app/`.
4. Tambahkan sidik jari **SHA-1 & SHA-256** (debug dan release/Play App Signing) di Project settings.
5. **Authentication → Sign-in method**: aktifkan *Email/Password* dan *Anonymous*.
6. **Firestore Database → Create** (mode production), lalu terapkan `firebase/firestore.rules`.
7. Index untuk leaderboard kota: buat dari `firebase/firestore.indexes.json` (atau klik tautan error di log saat pertama memuat peringkat kota).
8. (Opsional) `npm i -g firebase-tools && firebase deploy --only firestore`.

## 3. Keystore & build rilis
```bash
keytool -genkey -v -keystore ~/brewtopia-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Buat `android/key.properties`:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/path/ke/brewtopia-upload.jks
```
Build:
```bash
flutter build appbundle --release        # hasil: build/app/outputs/bundle/release/app-release.aab
```
**Simpan keystore & passwordnya baik-baik** (jangan di-commit; sudah ada di .gitignore).
Naikkan `version: 1.0.0+1` di `pubspec.yaml` (angka setelah `+`) setiap upload baru.

## 4. Play Console
1. Daftar akun developer (biaya sekali bayar US$25).
2. **Create app** → upload `.aab` ke track *Internal testing* dulu.
3. **Store listing**: ikon `store_assets/icon_512.png`, feature graphic `store_assets/feature_graphic_1024x500.png`, minimal 2 screenshot HP (ambil dari aplikasi).
   - Judul: *Brewtopia – Simulasi Kafe*
   - Deskripsi singkat: *Layani pelanggan, racik kopi, dan kembangkan kafemu!*
4. **App content** (wajib diisi):
   - **Privacy policy**: unggah `PRIVACY_POLICY.md` sebagai halaman web (GitHub Pages/Google Sites) dan tempel URL-nya.
   - **Data safety**: data dikumpulkan → email & nama (akun), lokasi perkiraan/akurat (hanya saat app dipakai, untuk fitur kota & check-in), ID pengguna, progres game. Data dikirim ke Firebase; enkripsi saat transit: ya; pengguna bisa meminta penghapusan: ya.
   - **Account deletion**: jelaskan jalur di app (*Pengaturan → Hapus akun & data*) dan beri URL halaman web berisi instruksi yang sama.
   - **Permissions (lokasi)**: tujuan = fitur inti check-in kafe & peringkat kota, hanya foreground.
   - **Content rating** (kuesioner IARC), **Target audience** (13+ / semua umur sesuai jawabanmu), **Ads**: tidak ada iklan.
5. Syarat tester: akun personal baru biasanya wajib *closed testing* dengan sejumlah tester selama beberapa minggu sebelum bisa ke produksi. **Cek persyaratan terbaru di Play Console** karena kebijakan ini bisa berubah.
6. Setelah lolos, promosikan ke **Production**.

## 5. Checklist sebelum submit
- [ ] `google-services.json` terpasang, Auth & Firestore aktif, rules diterapkan
- [ ] Package name bukan `com.example.*`
- [ ] Build release ditandatangani keystore sendiri (bukan debug)
- [ ] Privacy policy online + URL penghapusan akun
- [ ] Uji di HP asli: login, main, leaderboard, izin lokasi, notifikasi, tutup app lalu tunggu background task
- [ ] Screenshot & deskripsi terisi

## Catatan teknis
- WorkManager periodik minimum 15 menit dan dijalankan Android sesuai kondisi baterai/Doze — tidak persis tepat waktu. Itu normal.
- Font memakai `google_fonts` (unduh saat pertama kali online). Agar 100% offline, unduh font ke `assets/fonts/` dan daftarkan di `pubspec.yaml`.
- Latar kafe, meja, dekor, efek suara, dan musik lofi dibuat sendiri (lihat `tools/`), jadi aman dari watermark. Yang masih perlu kamu pastikan haknya: sprite dasar `man.png`/`woman.png` dan lagu `bbg.ogg` dari proyek awal (hapus `bbg.ogg` + pilihan 'Klasik' bila ragu).
- Suara dialog memakai Text-to-Speech Android. Di HP tanpa mesin TTS Bahasa Indonesia, dialog tetap tampil sebagai teks. Cantumkan di deskripsi Play Store bahwa suara dialog butuh TTS.
- Data Safety: tidak ada data suara dikirim keluar perangkat.
