/// App Integrity Verification Plugin
///
/// Flutter Plugin으로 호스트 앱의 무결성을 런타임에 검증한다.
/// Android에서는 APK 서명 인증서 SHA-256 해시 비교를,
/// iOS에서는 코드서명 무결성 및 번들 ID 검증을 수행한다.
/// 위협 탐지 시 true, 정상 시 false를 반환하는 순수 검증 패키지이다.
library app_integrity;

export 'src/models/threat_type.dart';
export 'src/models/security_threat.dart';
export 'src/models/integrity_config.dart';
export 'src/integrity_checker.dart';
export 'app_integrity_platform_interface.dart';
