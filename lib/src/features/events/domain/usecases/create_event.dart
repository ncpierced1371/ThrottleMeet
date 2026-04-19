import '../entities/event.dart';
import '../repositories/events_repository.dart';

class CreateEvent {
  const CreateEvent(this._repository);

  final EventsRepository _repository;

  Future<void> call(Event event) {
    return _repository.createEvent(event);
  }
}
