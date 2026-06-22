import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:app_integrity/app_integrity_platform_interface.dart';
import 'package:app_integrity/src/models/integrity_config.dart';
import 'package:app_integrity/src/models/security_threat.dart';
import 'package:app_integrity/src/models/threat_type.dart';

/// Android 공식 스토어 패키지명 목록.
const List<String> officialAndroidStores = [
  'com.android.vending', // Google Play Store
  'com.huawei.appmarket', // Huawei AppGallery
  'com.samsung.android.vending', // Samsung Galaxy Store
];

/// 앱 무결성 검증을 수행하는 핵심 클래스.
///
/// [IntegrityConfig]를 통해 앱별 설정을 주입받고,
/// [verify]를 호출하여 무결성 검증을 수행한다.
class IntegrityChecker {
  /// 무결성 검증 설정.
  final IntegrityConfig config;

  /// 탐지된 보안 위협 내부 목록.
  final List<SecurityThreat> _detectedThreats = [];

  /// [config]를 주입받아 IntegrityChecker를 생성한다.
  IntegrityChecker({required this.config});

  /// 위협이 탐지되었는지 여부.
  bool get hasThreat => _detectedThreats.isNotEmpty;

  /// 탐지된 위협의 불변 목록.
  List<SecurityThreat> get detectedThreats =>
      List.unmodifiable(_detectedThreats);

  /// 무결성 검증을 수행하고 탐지된 위협 목록을 반환한다.
  Future<List<SecurityThreat>> verify() async {
    // 6.2: 디버그 모드 체크
    if (kDebugMode && config.skipInDebugMode) {
      debugPrint('디버그 모드: 무결성 검증 건너뜀');
      return [];
    }

    final List<SecurityThreat> threats = [];

    // 6.3: Android 서명 검증
    if (Platform.isAndroid) {
      if (config.validSigningHashes.isEmpty) {
        debugPrint('경고: validSigningHashes가 비어있어 Android 서명 검증을 건너뜁니다.');
      } else {
        try {
          final signingHash =
              await AppIntegrityPlatform.instance.getSigningHash();
          if (signingHash == null) {
            threats.add(const SecurityThreat(
              type: ThreatType.signatureUnavailable,
              message: '서명 정보를 가져올 수 없습니다.',
            ));
          } else if (!config.validSigningHashes.contains(signingHash)) {
            threats.add(SecurityThreat(
              type: ThreatType.signatureMismatch,
              message: '서명 해시 불일치: $signingHash',
            ));
          }
        } on PlatformException catch (e) {
          debugPrint('Android 서명 검증 중 오류 발생: ${e.message}');
        }
      }
    }

    // 6.4: iOS 코드서명 검증
    if (Platform.isIOS) {
      try {
        final codeSigningResult =
            await AppIntegrityPlatform.instance.checkCodeSigning();
        if (codeSigningResult == null) {
          debugPrint('iOS 코드서명 결과를 가져올 수 없습니다. 검증을 건너뜁니다.');
        } else {
          final codeSignatureExists =
              codeSigningResult['codeSignatureExists'] as bool? ?? false;
          final executableExists =
              codeSigningResult['executableExists'] as bool? ?? false;
          final bundleId = codeSigningResult['bundleId'] as String?;

          if (!codeSignatureExists) {
            threats.add(const SecurityThreat(
              type: ThreatType.codeSignatureDirectoryMissing,
              message: '_CodeSignature 디렉토리가 존재하지 않습니다.',
            ));
          }

          if (!executableExists) {
            threats.add(const SecurityThreat(
              type: ThreatType.executableCorrupted,
              message: '실행파일이 존재하지 않거나 손상되었습니다.',
            ));
          }

          if (config.validBundleIds.isEmpty) {
            debugPrint('경고: validBundleIds가 비어있어 번들 ID 검증을 건너뜁니다.');
          } else if (bundleId != null &&
              !config.validBundleIds.contains(bundleId)) {
            threats.add(SecurityThreat(
              type: ThreatType.bundleIdMismatch,
              message: '번들 ID 불일치: $bundleId',
            ));
          }
        }
      } on PlatformException catch (e) {
        debugPrint('iOS 코드서명 검증 중 오류 발생: ${e.message}');
      }
    }

    // 6.5: 설치 출처 검증
    if (config.enableInstallSourceCheck) {
      try {
        final installSource =
            await AppIntegrityPlatform.instance.getInstallSource();

        if (Platform.isAndroid) {
          if (installSource != null &&
              !officialAndroidStores.contains(installSource)) {
            threats.add(SecurityThreat(
              type: ThreatType.unofficialInstallSource,
              message: '비공식 설치 출처: $installSource',
            ));
          }
        } else if (Platform.isIOS) {
          if (installSource == 'sideloaded') {
            threats.add(const SecurityThreat(
              type: ThreatType.unofficialInstallSource,
              message: '비공식 설치 출처: sideloaded',
            ));
          }
        }
      } on PlatformException catch (e) {
        debugPrint('설치 출처 검증 중 오류 발생: ${e.message}');
      }
    }

    // 6.6: 콜백 및 결과 반환
    _detectedThreats
      ..clear()
      ..addAll(threats);

    if (threats.isNotEmpty) {
      if (config.onThreatDetected != null) {
        config.onThreatDetected!(threats);
      } else {
        for (final threat in threats) {
          debugPrint('보안 위협 탐지: ${threat.type.name} - ${threat.message}');
        }
      }
    }

    return threats;
  }
}
