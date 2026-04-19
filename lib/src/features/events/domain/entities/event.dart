import 'rsvp_status.dart';

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.hostName,
    required this.startTime,
    required this.endTime,
    required this.attendeeCount,
    required this.rsvpStatus,
  });

  final String id;
  final String title;
  final String description;
  final String locationName;
  final String hostName;
  final DateTime startTime;
  final DateTime endTime;
  final int attendeeCount;
  final RsvpStatus rsvpStatus;

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? locationName,
    String? hostName,
    DateTime? startTime,
    DateTime? endTime,
    int? attendeeCount,
    RsvpStatus? rsvpStatus,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      hostName: hostName ?? this.hostName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
    );
  }
}
