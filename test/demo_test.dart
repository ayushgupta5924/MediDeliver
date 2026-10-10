import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medideliver/features/demo/presentation/demo_screen.dart';

void main() {
  testWidgets(
    'fictional COD workflow reserves, delivers, collects and resets',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DemoScreen()));
      Future<void> role(String name) async {
        final target = find.widgetWithText(ChoiceChip, name);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> action(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await role('Pharmacy');
      await action('Verified prescription / eligible medicine: quote');
      expect(
        find.text('On hand: 100 • Reserved: 2 • Available: 98'),
        findsOneWidget,
      );
      await role('Customer');
      await action('Accept total • Cash on delivery');
      await role('Pharmacy');
      await action('Start preparing');
      await action('Ready for pickup');
      await role('Rider');
      expect(
        find.text('Sample item A (fictional), pack of 10 × 2'),
        findsNothing,
      );
      expect(
        find.text('Delivery: 12 Fictional Garden, Demo District'),
        findsNothing,
      );
      await action('Accept delivery');
      expect(
        find.text('Delivery: 12 Fictional Garden, Demo District'),
        findsOneWidget,
      );
      await action('Confirm pickup');
      await action('Cash collected • Confirm delivery');
      expect(find.text('Cash collected: ₹209.50'), findsOneWidget);
      expect(
        find.text('Delivery: 12 Fictional Garden, Demo District'),
        findsNothing,
      );
      await role('Operations');
      expect(
        find.text('On hand: 98 • Reserved: 0 • Available: 98'),
        findsOneWidget,
      );
      await action('Reset demo');
      expect(find.text('Status: submitted'), findsOneWidget);
    },
  );
}
