import '../entities/event.dart';
import '../repositories/events_repository.dart';

class GetEvents {
  const GetEvents(this._repository);

  final EventsRepository _repository;

  Future<List<Event>> call() {
    return _repository.getEvents();
  }
}
