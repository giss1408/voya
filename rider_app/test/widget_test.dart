import 'package:flutter_test/flutter_test.dart';

import 'package:voya_rider/main.dart';

void main() {
  testWidgets('App boots to the search screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoyaApp());
    await tester.pump();

    expect(find.text('Find a trip'), findsOneWidget);
    expect(find.text('Search trips'), findsOneWidget);
  });
}
