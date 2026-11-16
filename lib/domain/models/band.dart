enum BandStatus {
  pending,
  approved,
  suspended;

  static BandStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'approved':
        return BandStatus.approved;
      case 'suspended':
        return BandStatus.suspended;
      case 'pending':
      default:
        return BandStatus.pending;
    }
  }

  String toDbString() => name;
}

class Band {
  final String id;
  final String slug;
  final String name;
  final String? bio;
  final String genre;
  final String? location;
  final String? coverUrl;
  final String? merchUrl;
  final Map<String, dynamic> socialLinks;
  final double donationGoal;
  final double donationsCollected;
  final BandStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final int followerCount;

  const Band({
    required this.id,
    required this.slug,
    required this.name,
    this.bio,
    this.genre = 'Indie',
    this.location,
    this.coverUrl,
    this.merchUrl,
    this.socialLinks = const {},
    this.donationGoal = 50000.0,
    this.donationsCollected = 0.0,
    this.status = BandStatus.pending,
    this.createdBy,
    required this.createdAt,
    this.followerCount = 0,
  });

  bool get isApproved => status == BandStatus.approved;
  bool get isPending => status == BandStatus.pending;
  bool get isSuspended => status == BandStatus.suspended;

  double get donationProgress {
    if (donationGoal <= 0) return 0.0;
    final progress = donationsCollected / donationGoal;
    return progress > 1.0 ? 1.0 : progress;
  }

  Band copyWith({
    String? id,
    String? slug,
    String? name,
    String? bio,
    String? genre,
    String? location,
    String? coverUrl,
    String? merchUrl,
    Map<String, dynamic>? socialLinks,
    double? donationGoal,
    double? donationsCollected,
    BandStatus? status,
    String? createdBy,
    DateTime? createdAt,
    int? followerCount,
  }) {
    return Band(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      genre: genre ?? this.genre,
      location: location ?? this.location,
      coverUrl: coverUrl ?? this.coverUrl,
      merchUrl: merchUrl ?? this.merchUrl,
      socialLinks: socialLinks ?? this.socialLinks,
      donationGoal: donationGoal ?? this.donationGoal,
      donationsCollected: donationsCollected ?? this.donationsCollected,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      followerCount: followerCount ?? this.followerCount,
    );
  }

  factory Band.fromJson(Map<String, dynamic> json, {int followerCount = 0}) {
    final rawCover = json['cover_url'] as String?;
    final fullCoverUrl = (rawCover != null &&
            rawCover.isNotEmpty &&
            !rawCover.startsWith('http') &&
            !rawCover.startsWith('file:'))
        ? 'https://fajwcwabcdxetuffoiuh.supabase.co/storage/v1/object/public/covers/$rawCover'
        : rawCover;

    return Band(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      genre: json['genre'] as String? ?? 'Indie',
      location: json['location'] as String?,
      coverUrl: fullCoverUrl,
      merchUrl: json['merch_url'] as String?,
      socialLinks: json['social_links'] is Map
          ? Map<String, dynamic>.from(json['social_links'] as Map)
          : {},
      donationGoal: (json['donation_goal'] as num?)?.toDouble() ?? 50000.0,
      donationsCollected: (json['donations_collected'] as num?)?.toDouble() ?? 0.0,
      status: BandStatus.fromString(json['status'] as String? ?? 'pending'),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      followerCount: followerCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'bio': bio,
      'genre': genre,
      'location': location,
      'cover_url': coverUrl,
      'merch_url': merchUrl,
      'social_links': socialLinks,
      'donation_goal': donationGoal,
      'donations_collected': donationsCollected,
      'status': status.toDbString(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

