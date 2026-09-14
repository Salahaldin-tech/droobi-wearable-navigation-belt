/// Minimal user model, matching the users/{uid} Firestore schema
/// agreed in Stage 2. Only fields required for system functionality
/// are included, per the project's privacy requirement (Stage 1 §8).
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final DateTime createdAt;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    final DateTime createdAt = switch (rawCreatedAt) {
      DateTime dt => dt,
      // Firestore Timestamps arrive as objects with a toDate() method.
      // Kept loosely typed here so this model file doesn't need to
      // import cloud_firestore directly.
      _ when rawCreatedAt != null && rawCreatedAt.runtimeType.toString() == 'Timestamp' =>
        (rawCreatedAt as dynamic).toDate() as DateTime,
      _ => DateTime.now(),
    };

    return AppUser(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'displayName': displayName,
      'createdAt': createdAt,
    };
  }
}
