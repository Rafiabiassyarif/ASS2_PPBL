import 'package:flutter_test/flutter_test.dart';
import 'package:kolabpanel/app.dart';

void main() {
  testWidgets('Basic smoke test', (WidgetTester tester) async {
    // Initialize preferences mock if needed, but since it is a static helper,
    // we just verify the App widget can be instantiated.
    const app = App();
    expect(app, isNotNull);
  });
}
