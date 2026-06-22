/// 앱 무결성 검증 설정을 담는 모델 클래스.
///
/// 호스트 앱에서 앱별 고유 값(서명 해시, 번들 ID)과
/// 검증 동작 옵션을 주입하여 IntegrityChecker를 초기화할 때 사용한다.
class IntegrityConfig {
  /// Android APK 서명에 사용된 유효한 SHA-256 해시 목록 (Base64 인코딩).
  final List<String> validSigningHashes;

  /// iOS 유효 번들 ID 목록.
  final List<String> validBundleIds;

  /// 설치 출처 검증 활성화 여부 (기본값: false).
  final bool enableInstallSourceCheck;

  /// 디버그 모드에서 검증 건너뛰기 (기본값: true).
  final bool skipInDebugMode;

  const IntegrityConfig({
    this.validSigningHashes = const [],
    this.validBundleIds = const [],
    this.enableInstallSourceCheck = false,
    this.skipInDebugMode = true,
  });
}
