class AppUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPublicProfile;
  final bool isAnonymous;
  final bool isAdmin;
  final Map<String, String> bandRoles; // bandId -> 'owner' | 'member'

  const AppUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isPublicProfile = false,
    this.isAnonymous = false,
    this.isAdmin = false,
    this.bandRoles = const {},
  });

  bool isMemberOf(String bandId) => bandRoles.containsKey(bandId);
  bool isOwnerOf(String bandId) => bandRoles[bandId] == 'owner';
  bool get hasAnyBand => bandRoles.isNotEmpty;

  AppUser copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
    bool? isAnonymous,
    bool? isAdmin,
    Map<String, String>? bandRoles,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isAdmin: isAdmin ?? this.isAdmin,
      bandRoles: bandRoles ?? this.bandRoles,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json, {bool isAdmin = false, Map<String, String>? bandRoles}) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Fan anónimo',
      avatarUrl: json['avatar_url'] as String?,
      isPublicProfile: json['is_public_profile'] as bool? ?? false,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      isAdmin: isAdmin,
      bandRoles: bandRoles ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_public_profile': isPublicProfile,
      'is_anonymous': isAnonymous,
    };
  }
}

