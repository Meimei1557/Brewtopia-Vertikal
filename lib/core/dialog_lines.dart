import 'dart:math';
import '../data/models/customer.dart';
import '../data/models/game_event.dart';
import '../data/models/product.dart';

/// Kumpulan dialog Bahasa Indonesia untuk pelanggan & barista.
class Lines {
  static String _pick(Random r, List<String> l) => l[r.nextInt(l.length)];

  static String joinItems(List<Product> items) {
    final w = items.map((e) => e.spoken).toList();
    if (w.length == 1) return 'satu ${w[0]}';
    if (w.length == 2) return 'satu ${w[0]} dan satu ${w[1]}';
        return '${w.sublist(0, w.length - 1).map((e) => 'satu $e').join(', ')} dan satu ${w.last}'; 
  }

  static String order(Random r, Gender g, CustomerTrait t, List<Product> items) {
    final x = joinItems(items);
    switch (t) {
      case CustomerTrait.impatient:
        return _pick(r, ['Cepat ya kak, aku buru-buru! $x.', 'Aku mau $x, tolong secepatnya!']);
      case CustomerTrait.vip:
        return _pick(r, ['Selamat siang. Saya pesan $x, yang terbaik ya.', 'Seperti biasa, $x untuk saya.']);
      case CustomerTrait.critic:
        return 'Saya kritikus kuliner. Saya pesan $x. Saya akan menilai dengan teliti.';
      case CustomerTrait.generous:
        return _pick(r, ['Hai kak! Aku pesan $x, ya. Kalau enak aku kasih tip!', 'Halo! $x ya, kak. Santai aja bikinnya.']);
      case CustomerTrait.normal:
        return g == Gender.female
            ? _pick(r, ['Halo kak! Aku mau pesan $x, ya.', 'Hai kak, boleh pesan $x?', 'Pesan $x dong, kak.'])
            : _pick(r, ['Halo kak, saya pesan $x ya.', 'Boleh pesan $x, kak?', 'Satu paket $x ya, kak.']);
    }
  }

  static String baristaAck(Random r) => _pick(r, [
        'Siap, pesanan masuk! Ditunggu sebentar ya.',
        'Baik kak, segera dibuatkan!',
        'Oke, langsung kami racik!',
        'Pesanan diterima, mohon tunggu ya!',
      ]);

  static String thanks(Random r, Gender g, double q) {
    if (q >= 0.85) {
      return g == Gender.female
          ? _pick(r, ['Wah, wangi banget! Ini enak sekali, makasih kak!', 'Sempurna! Aku suka banget!'])
          : _pick(r, ['Mantap! Ini pas banget rasanya, makasih!', 'Luar biasa, terbaik!']);
    }
    if (q >= 0.5) return _pick(r, ['Makasih ya kak, enak kok!', 'Lumayan, terima kasih!', 'Oke, pas. Makasih!']);
    return _pick(r, ['Hmm... rasanya agak aneh, tapi ya sudah.', 'Kurang pas sih, tapi makasih.']);
  }

  static String complain(Random r, Gender g) => _pick(r, [
        'Kok lama banget sih... Aku pergi aja deh!',
        'Aku nggak bisa nunggu lagi. Permisi!',
        g == Gender.female ? 'Huh, pelayanannya lambat. Aku pulang!' : 'Lama sekali. Saya cari tempat lain!',
      ]);

  static String chat(Random r, Gender g) => _pick(r, [
        'Suasana kafenya nyaman banget ya.',
        'Musiknya enak, bikin betah.',
        'Spot yang pas buat nongkrong.',
        'Kopinya wangi banget di sini.',
        'Besok mampir lagi ah!',
        'Tempat ini estetik banget, foto dulu!',
        'Pas banget buat ngobrol santai.',
      ]);

  static String goodbyeCustomer(Random r) => _pick(r, [
        'Aku pulang dulu ya, besok balik lagi!',
        'Makasih ya kak, sampai jumpa!',
        'Dadah! Kafenya keren banget!',
      ]);

  static String goodbyeBarista(Random r) => _pick(r, [
        'Terima kasih, datang lagi ya!',
        'Hati-hati di jalan, kak!',
        'Sampai ketemu lagi!',
      ]);

  static String takeaway(Random r) => _pick(r, ['Aku bawa pulang aja ya, makasih!', 'Dibungkus aja, kak. Terima kasih!']);

  static String sit(Random r) => _pick(r, ['Aku duduk di sana ya kak!', 'Mau nongkrong dulu, ah.', 'Meja yang nyaman, aku duduk di sini.']);

  static String wrong(Random r) => _pick(r, ['Ups, salah! Kita buang dulu.', 'Waduh, nggak sesuai. Masuk tempat sampah!', 'Gagal! Ulang lagi ya.']);

  static String burnt(Random r) => _pick(r, ['Yah, rotinya gosong!', 'Aduh, kelamaan di oven!']);

  static String eventLine(DayEvent e) => switch (e) {
        DayEvent.rush => 'Jam sibuk! Pelanggan berdatangan!',
        DayEvent.vip => 'Tamu VIP datang. Tipnya besar!',
        DayEvent.critic => 'Kritikus kuliner datang. Beri yang terbaik!',
        DayEvent.rain => 'Hujan turun! Banyak yang mampir berteduh.',
        DayEvent.none => '',
      };
}

class Names {
  static const male = ['Andi', 'Budi', 'Rizky', 'Dimas', 'Fajar', 'Bayu', 'Raka', 'Joko'];
  static const female = ['Sari', 'Dewi', 'Putri', 'Nadia', 'Rina', 'Ayu', 'Lia', 'Maya'];
}
