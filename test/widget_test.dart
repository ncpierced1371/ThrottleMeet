import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/app.dart';

void main() {
  testWidgets('shows seeded events on launch', (tester) async {
    await tester.pumpWidget(const ThrottleMeetApp());
    await tester.pumpAndSettle();

    expect(find.text('ThrottleMeet'), findsOneWidget);
    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
  });
}
