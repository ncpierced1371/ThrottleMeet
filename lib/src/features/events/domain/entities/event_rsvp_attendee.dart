import 'rsvp_status.dart';

class EventRsvpAttendee {
  const EventRsvpAttendee({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.status,
    required this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final RsvpStatus status;
  final DateTime updatedAt;
}
