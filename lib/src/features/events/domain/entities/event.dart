import 'rsvp_status.dart';

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.hostName,
    required this.scheduledAt,
    required this.rsvpStatus,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final String hostName;
  final DateTime scheduledAt;
  final RsvpStatus rsvpStatus;

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? hostName,
    DateTime? scheduledAt,
    RsvpStatus? rsvpStatus,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      hostName: hostName ?? this.hostName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
    );
  }
}
