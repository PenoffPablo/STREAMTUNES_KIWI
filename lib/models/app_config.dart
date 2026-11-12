class AppConfig {
  final int maxSongsPerBand;
  final int maxAlbumsPerBand;
  final double maxDonationArs;
  final int reportsToHide;
  final bool spendCapActive;

  const AppConfig({
    this.maxSongsPerBand = 20,
    this.maxAlbumsPerBand = 2,
    this.maxDonationArs = 5000.0,
    this.reportsToHide = 3,
    this.spendCapActive = false,
  });

  AppConfig copyWith({
    int? maxSongsPerBand,
    int? maxAlbumsPerBand,
    double? maxDonationArs,
    int? reportsToHide,
    bool? spendCapActive,
  }) {
    return AppConfig(
      maxSongsPerBand: maxSongsPerBand ?? this.maxSongsPerBand,
      maxAlbumsPerBand: maxAlbumsPerBand ?? this.maxAlbumsPerBand,
      maxDonationArs: maxDonationArs ?? this.maxDonationArs,
      reportsToHide: reportsToHide ?? this.reportsToHide,
      spendCapActive: spendCapActive ?? this.spendCapActive,
    );
  }

  factory AppConfig.fromMap(Map<String, String> map) {
    return AppConfig(
      maxSongsPerBand: int.tryParse(map['max_songs_per_band'] ?? '') ?? 20,
      maxAlbumsPerBand: int.tryParse(map['max_albums_per_band'] ?? '') ?? 2,
      maxDonationArs: double.tryParse(map['max_donation_ars'] ?? '') ?? 5000.0,
      reportsToHide: int.tryParse(map['reports_to_hide'] ?? '') ?? 3,
      spendCapActive: (map['spend_cap_active'] == '1' || map['spend_cap_active'] == 'true'),
    );
  }

  Map<String, String> toMap() {
    return {
      'max_songs_per_band': maxSongsPerBand.toString(),
      'max_albums_per_band': maxAlbumsPerBand.toString(),
      'max_donation_ars': maxDonationArs.toStringAsFixed(0),
      'reports_to_hide': reportsToHide.toString(),
      'spend_cap_active': spendCapActive ? '1' : '0',
    };
  }
}

