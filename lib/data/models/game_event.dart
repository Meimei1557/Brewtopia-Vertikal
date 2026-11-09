import 'customer.dart';
import 'product.dart';
import 'upgrade.dart';

enum DayEvent { none, rush, vip, critic, rain }

class DaySummary {
  DaySummary({
    required this.day,
    required this.earned,
    required this.customers,
    required this.angry,
    required this.perfect,
    required this.hangout,
    required this.trashed,
    required this.reputation,
    required this.bestDay,
    required this.target,
    required this.stars,
    required this.bonus,
  });
  final int day, earned, customers, angry, perfect, hangout, trashed, target, stars, bonus;
  final double reputation;
  final bool bestDay;
}

/// Event satu arah ViewModel -> View (suara, toast, dialog).
sealed class GameEvent {
  const GameEvent();
}

class DoorOpened extends GameEvent {
  const DoorOpened();
}

class OrderTaken extends GameEvent {
  const OrderTaken();
}

class ItemDelivered extends GameEvent {
  const ItemDelivered(this.product, this.quality);
  final Product product;
  final double quality;
}

class OrderServed extends GameEvent {
  const OrderServed(this.earned, this.combo, this.quality);
  final int earned, combo;
  final double quality;
}

class Trashed extends GameEvent {
  const Trashed(this.product, this.reason);
  final Product product;
  final String reason;
}

class CustomerAngry extends GameEvent {
  const CustomerAngry();
}

class HangoutDone extends GameEvent {
  const HangoutDone(this.bonus);
  final int bonus;
}

class OvenReady extends GameEvent {
  const OvenReady();
}

class OvenBurnt extends GameEvent {
  const OvenBurnt();
}

class BakeStarted extends GameEvent {
  const BakeStarted();
}

class BakeCollected extends GameEvent {
  const BakeCollected(this.perfect);
  final bool perfect;
}

class LevelUp extends GameEvent {
  const LevelUp(this.level, this.bonus, this.unlocked);
  final int level, bonus;
  final String unlocked;
}

class UpgradeBought extends GameEvent {
  const UpgradeBought(this.type);
  final UpgradeType type;
}

class Purchased extends GameEvent {
  const Purchased(this.what);
  final String what;
}

class NotEnoughCoins extends GameEvent {
  const NotEnoughCoins();
}

class ToastEvent extends GameEvent {
  const ToastEvent(this.text);
  final String text;
}

class EventBanner extends GameEvent {
  const EventBanner(this.text);
  final String text;
}

class MissionDone extends GameEvent {
  const MissionDone(this.label);
  final String label;
}

class DayEnded extends GameEvent {
  const DayEnded(this.summary);
  final DaySummary summary;
}

class DailyReward extends GameEvent {
  const DailyReward(this.coins, this.streak);
  final int coins, streak;
}

/// Kalimat yang diucapkan (TTS) sesuai gender pembicara.
class Speak extends GameEvent {
  const Speak(this.text, this.gender, {this.priority = false});
  final String text;
  final Gender gender;
  final bool priority;
}
