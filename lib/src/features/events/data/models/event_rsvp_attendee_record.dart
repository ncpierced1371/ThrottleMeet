import '../../domain/entities/event_rsvp_attendee.dart';
import '../../domain/entities/rsvp_status.dart';

class EventRsvpAttendeeRecord {
  const EventRsvpAttendeeRecord({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.status,
    required this.updatedAt,
  });

  factory EventRsvpAttendeeRecord.fromMap(Map<String, dynamic> map) {
    final userId = map['user_id'];
    final displayName = map['display_name'];
    final avatarUrl = map['avatar_url'];
    final statusValue = map['status'];
    final updatedAtValue = map['updated_at'];

    if (userId is! String || userId.isEmpty) {
      throw const FormatException('RSVP attendee user_id is invalid.');
    }
    if (displayName != null && displayName is! String) {
      throw const FormatException('RSVP attendee display_name is invalid.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('RSVP attendee avatar_url is invalid.');
    }
    if (statusValue is! String) {
      throw const FormatException('RSVP attendee status is invalid.');
    }
    if (updatedAtValue is! String) {
      throw const FormatException('RSVP attendee updated_at is invalid.');
    }

    final status = switch (statusValue) {
      'going' => RsvpStatus.going,
      'interested' => RsvpStatus.interested,
      'notGoing' => RsvpStatus.notGoing,
      _ => throw FormatException('Unknown RSVP attendee status: $statusValue.'),
    };

    return EventRsvpAttendeeRecord(
      userId: userId,
      displayName: displayName as String?,
      avatarUrl: avatarUrl as String?,
      status: status,
      updatedAt: DateTime.parse(updatedAtValue),
    );
  }

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final RsvpStatus status;
  final DateTime updatedAt;

  EventRsvpAttendee toEntity() {
    return EventRsvpAttendee(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      status: status,
      updatedAt: updatedAt,
    );
  }
}
