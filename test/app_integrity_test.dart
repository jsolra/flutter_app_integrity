import 'package:flutter_test/flutter_test.dart';
import 'package:app_integrity/app_integrity.dart';
import 'package:app_integrity/app_integrity_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppIntegrityPlatform
    with MockPlatformInterfaceMixin
    implements AppIntegrityPlatform {
  @override
  Future<String?> getSigningHash() => Future.value('mockHash123');

  @override
  Future<Map<String, dynamic>?> checkCodeSigning() => Future.value({
        'bundleId': 'com.example.test',
        'codeSignatureExists': true,
        'executableExists': true,
        'isEncrypted': false,
        'isDebugBuild': true,
        'isSimulator': true,
      });

  @override
  Future<String?> getInstallSource() => Future.value('com.android.vending');
}

void main() {
  final AppIntegrityPlatform initialPlatform = AppIntegrityPlatform.instance;

  test('$MethodChannelAppIntegrity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppIntegrity>());
  });

  test('getSigningHash via platform interface', () async {
    MockAppIntegrityPlatform fakePlatform = MockAppIntegrityPlatform();
    AppIntegrityPlatform.instance = fakePlatform;

    expect(await AppIntegrityPlatform.instance.getSigningHash(), 'mockHash123');
  });

  test('checkCodeSigning via platform interface', () async {
    MockAppIntegrityPlatform fakePlatform = MockAppIntegrityPlatform();
    AppIntegrityPlatform.instance = fakePlatform;

    final result = await AppIntegrityPlatform.instance.checkCodeSigning();
    expect(result, isNotNull);
    expect(result!['bundleId'], 'com.example.test');
    expect(result['codeSignatureExists'], true);
  });

  test('getInstallSource via platform interface', () async {
    MockAppIntegrityPlatform fakePlatform = MockAppIntegrityPlatform();
    AppIntegrityPlatform.instance = fakePlatform;

    expect(
        await AppIntegrityPlatform.instance.getInstallSource(), 'com.android.vending');
  });

  group('Public API exports', () {
    test('ThreatType enum is accessible', () {
      expect(ThreatType.signatureMismatch, isNotNull);
      expect(ThreatType.signatureUnavailable, isNotNull);
      expect(ThreatType.bundleIdMismatch, isNotNull);
      expect(ThreatType.codeSignatureDirectoryMissing, isNotNull);
      expect(ThreatType.executableCorrupted, isNotNull);
      expect(ThreatType.unofficialInstallSource, isNotNull);
    });

    test('SecurityThreat is accessible', () {
      const threat = SecurityThreat(
        type: ThreatType.signatureMismatch,
        message: 'test',
      );
      expect(threat.type, ThreatType.signatureMismatch);
      expect(threat.message, 'test');
    });

    test('IntegrityConfig is accessible with defaults', () {
      const config = IntegrityConfig();
      expect(config.validSigningHashes, isEmpty);
      expect(config.validBundleIds, isEmpty);
      expect(config.enableInstallSourceCheck, false);
      expect(config.skipInDebugMode, true);
    });

    test('IntegrityChecker is accessible', () {
      final checker = IntegrityChecker(config: const IntegrityConfig());
      expect(checker.hasThreat, false);
      expect(checker.detectedThreats, isEmpty);
    });
  });
}
