import 'features/events/data/repositories/in_memory_events_repository.dart';
import 'features/events/domain/usecases/create_event.dart';
import 'features/events/domain/usecases/get_event_by_id.dart';
import 'features/events/domain/usecases/get_events.dart';
import 'features/events/domain/usecases/update_rsvp.dart';
import 'features/events/presentation/controllers/events_controller.dart';

class AppDependencies {
  AppDependencies({required this.eventsController});

  final EventsController eventsController;

  factory AppDependencies.create() {
    final repository = InMemoryEventsRepository();

    return AppDependencies(
      eventsController: EventsController(
        getEvents: GetEvents(repository),
        getEventById: GetEventById(repository),
        createEvent: CreateEvent(repository),
        updateRsvp: UpdateRsvp(repository),
      ),
    );
  }

  void dispose() {
    eventsController.dispose();
  }
}
