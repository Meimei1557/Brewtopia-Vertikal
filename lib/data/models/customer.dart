import 'product.dart';

enum Gender { male, female }

enum CustomerTrait { normal, impatient, generous, vip, critic }

enum CustState { arriving, ordering, waiting, toTable, seated, leaving }

class OrderItem {
  OrderItem(this.product);
  final Product product;
  bool done = false;
  double quality = 0;
}

/// Entitas pelanggan. Posisi (x,y) = titik kaki di koordinat scene (600 x 1300).
class Customer {
  Customer({
    required this.id,
    required this.variant,
    required this.name,
    required this.trait,
    required this.items,
    required this.slot,
    required this.maxPatience,
    required this.x,
    required this.y,
  })  : patience = maxPatience,
        targetX = x,
        targetY = y;

  final int id;
  final int variant; // 0..3 pria, 4..7 wanita (indeks sprite c{variant})
  final String name;
  final CustomerTrait trait;
  final List<OrderItem> items;
  int slot;

  double x;
  double y;
  double targetX;
  double targetY;
  double walkPhase = 0;
  double stateTime = 0;
  double patience;
  final double maxPatience;
  double sitTimer = 0;
  double chatTimer = 4;
  double hop = 0; // 0..1 lompat senang
  double lean = 0;
  int tableIndex = -1;
  bool angry = false;
  bool doorTriggered = false;
  bool askedBarista = false;
  bool gone = false;
  CustState state = CustState.arriving;

  String? bubble;
  double bubbleTime = 0;

  Gender get gender => variant < 4 ? Gender.male : Gender.female;
  bool get isWalking =>
      state == CustState.arriving || state == CustState.toTable || state == CustState.leaving;
  double get patienceFraction => (patience / maxPatience).clamp(0.0, 1.0).toDouble();
  bool get allDone => items.every((i) => i.done);
  String get orderText => items.map((i) => i.product.label).join(' + ');
  bool get inQueue =>
      state == CustState.arriving || state == CustState.ordering || state == CustState.waiting;

  void say(String text, [double seconds = 3.2]) {
    bubble = text;
    bubbleTime = seconds;
  }
}
