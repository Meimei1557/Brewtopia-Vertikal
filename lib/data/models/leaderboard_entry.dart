class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.level,
    required this.totalEarned,
    this.city,
  });

  final String uid;
  final String name;
  final int level;
  final int totalEarned;
  final String? city;

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> m) =>
      LeaderboardEntry(
        uid: uid,
        name: (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : 'Barista',
        level: (m['level'] as num?)?.toInt() ?? 1,
        totalEarned: (m['totalEarned'] as num?)?.toInt() ?? 0,
        city: m['city'] as String?,
      );
}
