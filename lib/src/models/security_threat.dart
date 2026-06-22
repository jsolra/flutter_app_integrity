import 'package:app_integrity/src/models/threat_type.dart';

/// 무결성 검증 시 탐지된 보안 위협을 나타내는 모델 클래스.
class SecurityThreat {
  /// 탐지된 위협의 유형.
  final ThreatType type;

  /// 위협에 대한 설명 메시지.
  final String message;

  const SecurityThreat({
    required this.type,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityThreat &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message;

  @override
  int get hashCode => type.hashCode ^ message.hashCode;

  @override
  String toString() => 'SecurityThreat(type: $type, message: $message)';
}
