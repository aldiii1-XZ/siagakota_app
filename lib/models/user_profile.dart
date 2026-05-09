/// Representasi user yang disimpan di Supabase.
class UserProfile {
  final String id;
  final String nama;
  final String role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.nama,
    required this.role,
    required this.createdAt,
  });
}
