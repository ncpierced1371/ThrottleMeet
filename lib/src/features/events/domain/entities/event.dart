import 'rsvp_status.dart';

const _unsetViewerRsvpStatus = Object();
const _unsetCancelledAt = Object();

enum EventStatus { active, cancelled }

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

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? locationName,
    String? hostName,
    DateTime? startTime,
    DateTime? endTime,
    int? attendeeCount,
    Object? viewerRsvpStatus = _unsetViewerRsvpStatus,
    EventStatus? status,
    bool? isOwnedByViewer,
    Object? cancelledAt = _unsetCancelledAt,
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
      viewerRsvpStatus: identical(viewerRsvpStatus, _unsetViewerRsvpStatus)
          ? this.viewerRsvpStatus
          : viewerRsvpStatus as RsvpStatus?,
      status: status ?? this.status,
      isOwnedByViewer: isOwnedByViewer ?? this.isOwnedByViewer,
      cancelledAt: identical(cancelledAt, _unsetCancelledAt)
          ? this.cancelledAt
          : cancelledAt as DateTime?,
    );
  }
}
