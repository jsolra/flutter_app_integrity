import 'package:flutter/material.dart';
import 'package:app_integrity/app_integrity.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Integrity Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const IntegrityCheckPage(),
    );
  }
}

class IntegrityCheckPage extends StatefulWidget {
  const IntegrityCheckPage({super.key});

  @override
  State<IntegrityCheckPage> createState() => _IntegrityCheckPageState();
}

class _IntegrityCheckPageState extends State<IntegrityCheckPage> {
  late final IntegrityChecker _checker;
  List<SecurityThreat> _threats = [];
  bool _isLoading = false;
  bool _hasVerified = false;
  bool _hasThreat = false;

  @override
  void initState() {
    super.initState();
    _initChecker();
    _runVerification();
  }

  /// IntegrityConfig를 생성하고 IntegrityChecker를 초기화합니다.
  void _initChecker() {
    const config = IntegrityConfig(
      // Android: 유효한 APK 서명 SHA-256 해시 (Base64 인코딩)
      // 실제 앱에서는 본인의 서명 해시로 교체하세요.
      validSigningHashes: [
        'YOUR_SIGNING_HASH_HERE',
      ],
      // iOS: 유효한 번들 ID 목록
      // 실제 앱에서는 본인의 번들 ID로 교체하세요.
      validBundleIds: [
        'com.example.appIntegrityExample',
      ],
      // 설치 출처 검증 활성화 (공식 스토어 외 설치 탐지)
      enableInstallSourceCheck: true,
      // 디버그 모드에서 검증 건너뛰기 (개발 중 편의를 위해 true 권장)
      skipInDebugMode: false,
    );

    _checker = IntegrityChecker(config: config);
  }

  /// 무결성 검증을 실행합니다.
  /// verify()는 위협 탐지 시 true, 정상 시 false를 반환합니다.
  Future<void> _runVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasThreat = await _checker.verify();
      if (mounted) {
        setState(() {
          _hasThreat = hasThreat;
          _threats = _checker.detectedThreats;
          _isLoading = false;
          _hasVerified = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasVerified = true;
        });
        debugPrint('검증 중 오류 발생: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Integrity Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 검증 상태 카드
            _buildStatusCard(),
            const SizedBox(height: 16),
            // 위협 목록
            if (_hasVerified) ...[
              Text(
                '검증 결과',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildThreatList()),
            ],
            const SizedBox(height: 16),
            // 수동 검증 버튼
            FilledButton.icon(
              onPressed: _isLoading ? null : _runVerification,
              icon: const Icon(Icons.refresh),
              label: const Text('무결성 재검증'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (_isLoading) {
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty;
      statusText = '검증 중...';
    } else if (!_hasVerified) {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = '검증 대기';
    } else if (_hasThreat) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = '위협 탐지됨 (${_threats.length}건)';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '위협 없음 - 앱이 안전합니다';
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: statusColor,
                    ),
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatList() {
    if (_threats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 64, color: Colors.green),
            SizedBox(height: 8),
            Text('탐지된 위협이 없습니다.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _threats.length,
      itemBuilder: (context, index) {
        final threat = _threats[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.amber),
            title: Text(threat.type.name),
            subtitle: Text(threat.message),
          ),
        );
      },
    );
  }
}
