/// 무결성 검증 시 탐지 가능한 위협 유형을 정의하는 열거형.
enum ThreatType {
  /// Android 서명 해시 불일치
  signatureMismatch,

  /// 서명 정보를 가져올 수 없음
  signatureUnavailable,

  /// iOS 번들 ID 불일치
  bundleIdMismatch,

  /// iOS _CodeSignature 디렉토리 누락
  codeSignatureDirectoryMissing,

  /// iOS 실행파일 손상/누락
  executableCorrupted,

  /// 비공식 설치 출처
  unofficialInstallSource,
}
