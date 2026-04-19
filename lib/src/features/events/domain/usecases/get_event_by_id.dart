import '../entities/event.dart';
import '../repositories/events_repository.dart';

class GetEventById {
  const GetEventById(this._repository);

  final EventsRepository _repository;

  Future<Event?> call(String id) {
    return _repository.getEventById(id);
  }
}
