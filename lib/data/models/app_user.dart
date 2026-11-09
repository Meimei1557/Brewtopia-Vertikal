class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.isGuest = false,
  });

  final String uid;
  final String displayName;
  final String? email;
  final bool isGuest;

  bool get isLocalOnly => uid == 'local';
}
