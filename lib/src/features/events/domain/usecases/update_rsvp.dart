import '../entities/rsvp_status.dart';
import '../repositories/events_repository.dart';

class UpdateRsvp {
  const UpdateRsvp(this._repository);

  final EventsRepository _repository;

  Future<void> call({required String eventId, required RsvpStatus status}) {
    return _repository.updateRsvp(eventId: eventId, status: status);
  }
}
