import 'package:backpackhelp/Connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Raspberry Pi connection settings are shown', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ConnectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Raspberry Pi Connection'), findsOneWidget);
    expect(find.text('Save and test connection'), findsOneWidget);
    expect(find.text('Remote connection setup'), findsOneWidget);
  });
}
