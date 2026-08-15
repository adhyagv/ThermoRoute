import 'package:flutter_test/flutter_test.dart';
import 'package:thermoroute_app/main.dart';

void main() {
  testWidgets('ThermoRoute app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThermoRouteApp());

    expect(find.text('ThermoRoute'), findsWidgets);
    expect(find.text('Plan a safer journey'), findsOneWidget);
    expect(find.text('FIND BEST ROUTE'), findsOneWidget);
  });
}