import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_integrity_method_channel.dart';

abstract class AppIntegrityPlatform extends PlatformInterface {
  /// Constructs a AppIntegrityPlatform.
  AppIntegrityPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppIntegrityPlatform _instance = MethodChannelAppIntegrity();

  /// The default instance of [AppIntegrityPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppIntegrity].
  static AppIntegrityPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppIntegrityPlatform] when
  /// they register themselves.
  static set instance(AppIntegrityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Android에서 현재 앱의 서명 인증서 SHA-256 해시(Base64 인코딩)를 반환한다.
  Future<String?> getSigningHash() {
    throw UnimplementedError('getSigningHash() has not been implemented.');
  }

  /// iOS에서 코드서명 검증 결과를 딕셔너리로 반환한다.
  Future<Map<String, dynamic>?> checkCodeSigning() {
    throw UnimplementedError('checkCodeSigning() has not been implemented.');
  }

  /// 앱의 설치 출처 정보를 반환한다.
  Future<String?> getInstallSource() {
    throw UnimplementedError('getInstallSource() has not been implemented.');
  }
}
