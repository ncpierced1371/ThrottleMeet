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
        location: 'Cold Spring Ridge',
        hostName: 'ThrottleMeet Crew',
        scheduledAt: DateTime(2026, 5, 2, 9, 30),
        rsvpStatus: RsvpStatus.going,
      ),
      Event(
        id: 'sunset-downtown-meet',
        title: 'Sunset Downtown Meet',
        description:
            'Golden-hour meetup for builds, photos, and a short city cruise after everyone rolls in.',
        location: 'Foundry Square',
        hostName: 'Maya R.',
        scheduledAt: DateTime(2026, 5, 7, 18, 0),
        rsvpStatus: RsvpStatus.interested,
      ),
      Event(
        id: 'early-bird-cars-coffee',
        title: 'Early Bird Cars & Coffee',
        description:
            'Simple morning meetup focused on showing up, meeting people, and getting out before traffic.',
        location: 'Northline Market',
        hostName: 'Jordan K.',
        scheduledAt: DateTime(2026, 5, 16, 8, 0),
        rsvpStatus: RsvpStatus.notGoing,
      ),
    ];
  }
}
