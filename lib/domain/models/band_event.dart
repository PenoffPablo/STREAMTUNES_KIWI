class BandEvent {
  final String id;
  final String bandId;
  final String title;
  final String venue;
  final String city;
  final DateTime eventDate;
  final String? ticketUrl;
  final DateTime createdAt;

  const BandEvent({
    required this.id,
    required this.bandId,
    required this.title,
    required this.venue,
    required this.city,
    required this.eventDate,
    this.ticketUrl,
    required this.createdAt,
  });

  bool get isUpcoming => eventDate.isAfter(DateTime.now());

  BandEvent copyWith({
    String? id,
    String? bandId,
    String? title,
    String? venue,
    String? city,
    DateTime? eventDate,
    String? ticketUrl,
    DateTime? createdAt,
  }) {
    return BandEvent(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      city: city ?? this.city,
      eventDate: eventDate ?? this.eventDate,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BandEvent.fromJson(Map<String, dynamic> json) {
    return BandEvent(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      title: json['title'] as String,
      venue: json['venue'] as String,
      city: json['city'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      ticketUrl: json['ticket_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'band_id': bandId,
      'title': title,
      'venue': venue,
      'city': city,
      'event_date': eventDate.toIso8601String(),
      'ticket_url': ticketUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

