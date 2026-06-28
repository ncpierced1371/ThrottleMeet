import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';

class EventRecord {
  const EventRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.hostName,
    required this.startTime,
    required this.endTime,
    required this.attendeeCount,
    required this.viewerRsvpStatus,
  });

  final String id;
  final String title;
  final String description;
  final String locationName;
  final String hostName;
  final DateTime startTime;
  final DateTime endTime;
  final int attendeeCount;
  final RsvpStatus? viewerRsvpStatus;

  factory EventRecord.fromMap(Map<String, dynamic> map) {
    return EventRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      locationName: map['location_name'] as String,
      hostName: map['host_name'] as String,
      startTime: DateTime.parse(map['start_time'].toString()),
      endTime: DateTime.parse(map['end_time'].toString()),
      attendeeCount: (map['attendee_count'] as num?)?.toInt() ?? 0,
      viewerRsvpStatus: _rsvpStatusFromValue(map['rsvp_status']),
    );
  }

  factory EventRecord.fromEntity(Event event) {
    return EventRecord(
      id: event.id,
      title: event.title,
      description: event.description,
      locationName: event.locationName,
      hostName: event.hostName,
      startTime: event.startTime,
      endTime: event.endTime,
      attendeeCount: event.attendeeCount,
      viewerRsvpStatus: event.viewerRsvpStatus,
    );
  }

  Event toEntity() {
    return Event(
      id: id,
      title: title,
      description: description,
      locationName: locationName,
      hostName: hostName,
      startTime: startTime,
      endTime: endTime,
      attendeeCount: attendeeCount,
      viewerRsvpStatus: viewerRsvpStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location_name': locationName,
      'host_name': hostName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'attendee_count': attendeeCount,
      'rsvp_status': viewerRsvpStatus?.name,
    };
  }

  static RsvpStatus? _rsvpStatusFromValue(Object? value) {
    if (value == null) {
      return null;
    }

    return _rsvpStatusFromString(value as String);
  }

  static RsvpStatus _rsvpStatusFromString(String value) {
    return RsvpStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => RsvpStatus.interested,
    );
  }
}
