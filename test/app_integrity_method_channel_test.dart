import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_integrity/app_integrity_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAppIntegrity platform = MethodChannelAppIntegrity();
  const MethodChannel channel = MethodChannel('app_integrity');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSigningHash', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getSigningHash') {
        return 'abc123hash';
      }
      return null;
    });

    expect(await platform.getSigningHash(), 'abc123hash');
  });

  test('checkCodeSigning', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkCodeSigning') {
        return <String, dynamic>{
          'bundleId': 'com.example.app',
          'codeSignatureExists': true,
          'executableExists': true,
          'isEncrypted': false,
          'isDebugBuild': true,
          'isSimulator': false,
        };
      }
      return null;
    });

    final result = await platform.checkCodeSigning();
    expect(result, isNotNull);
    expect(result!['bundleId'], 'com.example.app');
    expect(result['codeSignatureExists'], true);
    expect(result['executableExists'], true);
  });

  test('getInstallSource', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getInstallSource') {
        return 'com.android.vending';
      }
      return null;
    });

    expect(await platform.getInstallSource(), 'com.android.vending');
  });
}
