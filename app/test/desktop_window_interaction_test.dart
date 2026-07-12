import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('desktop title region drags and double-clicks to maximize', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isMaximized') return false;
          return null;
        });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DragToMoveArea(child: SizedBox(width: 400, height: 32)),
        ),
      ),
    );

    await tester.drag(find.byType(DragToMoveArea), const Offset(20, 0));
    await tester.pump();
    expect(calls, contains('startDragging'));

    await tester.tap(find.byType(DragToMoveArea));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(DragToMoveArea));
    await tester.pumpAndSettle();
    expect(calls, containsAllInOrder(['isMaximized', 'maximize']));
  });
}
