import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/core/platform/window_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WindowChannel correctly invokes toggleFullScreen', () async {
    final List<MethodCall> log = [];
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.openfilmly.window'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      },
    );

    await WindowChannel.toggleFullScreen();

    expect(log.length, 1);
    expect(log.first.method, 'toggleFullScreen');
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.openfilmly.window'), null);
  });

  test('WindowChannel correctly invokes maximize', () async {
    final List<MethodCall> log = [];
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.openfilmly.window'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      },
    );

    await WindowChannel.maximize();

    expect(log.length, 1);
    expect(log.first.method, 'maximize');
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.openfilmly.window'), null);
  });
}
