import 'package:flutter_test/flutter_test.dart';

import 'package:voya_fleet/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoyaFleetApp());
    await tester.pump();

    expect(find.text('Voya'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
