import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttlemeet_v2/src/core/identity/participant_id_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('missing ID creates a UUID v4', () async {
    final store = ParticipantIdStore();

    final participantId = await store.getOrCreateParticipantId();

    expect(
      participantId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('ID persists across store instances', () async {
    final firstStore = ParticipantIdStore();
    final firstParticipantId = await firstStore.getOrCreateParticipantId();
    final secondStore = ParticipantIdStore(
      generateParticipantId: () => fail('A persisted ID should be reused.'),
    );

    final secondParticipantId = await secondStore.getOrCreateParticipantId();

    expect(secondParticipantId, firstParticipantId);
  });

  test('subsequent calls return the same ID', () async {
    var generationCount = 0;
    final store = ParticipantIdStore(
      generateParticipantId: () {
        generationCount += 1;
        return '23a91ff4-a01d-4b79-82c2-cb7b67dd39da';
      },
    );

    final firstParticipantId = await store.getOrCreateParticipantId();
    final secondParticipantId = await store.getOrCreateParticipantId();

    expect(secondParticipantId, firstParticipantId);
    expect(generationCount, 1);
  });
}
