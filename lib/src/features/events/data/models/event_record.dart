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
    this.status = EventStatus.active,
    this.isOwnedByViewer = false,
    this.cancelledAt,
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
  final EventStatus status;
  final bool isOwnedByViewer;
  final DateTime? cancelledAt;

  factory EventRecord.fromMap(Map<String, dynamic> map) {
    return EventRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      locationName: map['location_name'] as String,
      hostName: map['host_name'] as String,
      startTime: _parseTimestamp(map, 'start_time'),
      endTime: _parseTimestamp(map, 'end_time'),
      attendeeCount: (map['attendee_count'] as num?)?.toInt() ?? 0,
      viewerRsvpStatus: _rsvpStatusFromValue(map['rsvp_status']),
      status: _eventStatusFromValue(map['status']),
      isOwnedByViewer: map['is_owner'] as bool? ?? false,
      cancelledAt: _parseNullableTimestamp(map, 'cancelled_at'),
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
      status: event.status,
      isOwnedByViewer: event.isOwnedByViewer,
      cancelledAt: event.cancelledAt,
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
      status: status,
      isOwnedByViewer: isOwnedByViewer,
      cancelledAt: cancelledAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location_name': locationName,
      'host_name': hostName,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toSnapshotMap() {
    return {
      ...toCreateMap(),
      'attendee_count': attendeeCount,
      'rsvp_status': viewerRsvpStatus?.name,
      'status': status.name,
      'is_owner': isOwnedByViewer,
      'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(Map<String, dynamic> map, String fieldName) {
    final value = map[fieldName];

    if (value is DateTime) {
      return value.toUtc();
    }

    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Expected a timestamp string for "$fieldName", got: $value',
      );
    }

    final timestamp = DateTime.tryParse(value);
    if (timestamp == null) {
      throw FormatException('Invalid timestamp for "$fieldName": $value');
    }

    return timestamp.toUtc();
  }

  static DateTime? _parseNullableTimestamp(
    Map<String, dynamic> map,
    String fieldName,
  ) {
    if (map[fieldName] == null) {
      return null;
    }
    return _parseTimestamp(map, fieldName);
  }

  static EventStatus _eventStatusFromValue(Object? value) {
    if (value == null) {
      return EventStatus.active;
    }
    if (value is! String) {
      throw FormatException('Expected event status string, got: $value');
    }
    return EventStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Invalid event status: $value'),
    );
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
