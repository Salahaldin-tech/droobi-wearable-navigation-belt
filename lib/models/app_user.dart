class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.createdAt,
    this.role = 'user',
  });

  final String uid;
  final String displayName;
  final DateTime createdAt;
  final String role;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final rawCreatedAt = data['createdAt'];

    final DateTime createdAt = switch (rawCreatedAt) {
      DateTime dt => dt,
      _ when rawCreatedAt != null &&
              rawCreatedAt.runtimeType.toString() == 'Timestamp' =>
        (rawCreatedAt as dynamic).toDate() as DateTime,
      _ => DateTime.now(),
    };

    return AppUser(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      createdAt: createdAt,
      role: (data['role'] as String?) ?? 'user',
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'displayName': displayName,
      'createdAt': createdAt,
      'role': role,
    };
  }
}