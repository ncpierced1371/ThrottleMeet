import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';

class SeedEvents {
  static List<Event> build() {
    return [
      Event(
        id: 'spring-canyon-run',
        title: 'Spring Canyon Run',
        description:
            'An easy Saturday drive with a coffee meetup, scenic pull-offs, and a relaxed social pace.',
        locationName: 'Cold Spring Ridge',
        hostName: 'Throttle Meet Crew',
        startTime: DateTime(2026, 5, 2, 9, 30),
        endTime: DateTime(2026, 5, 2, 11, 30),
        attendeeCount: 18,
        viewerRsvpStatus: RsvpStatus.going,
      ),
      Event(
        id: 'sunset-downtown-meet',
        title: 'Sunset Downtown Meet',
        description:
            'Golden-hour meetup for builds, photos, and a short city cruise after everyone rolls in.',
        locationName: 'Foundry Square',
        hostName: 'Maya R.',
        startTime: DateTime(2026, 5, 7, 18, 0),
        endTime: DateTime(2026, 5, 7, 20, 0),
        attendeeCount: 26,
        viewerRsvpStatus: RsvpStatus.interested,
      ),
      Event(
        id: 'early-bird-cars-coffee',
        title: 'Early Bird Cars & Coffee',
        description:
            'Simple morning meetup focused on showing up, meeting people, and getting out before traffic.',
        locationName: 'Northline Market',
        hostName: 'Jordan K.',
        startTime: DateTime(2026, 5, 16, 8, 0),
        endTime: DateTime(2026, 5, 16, 10, 0),
        attendeeCount: 12,
        viewerRsvpStatus: RsvpStatus.notGoing,
      ),
    ];
  }
}
