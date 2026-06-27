import 'dart:typed_data';

import 'emapps_client.dart';

class EmAppRuntimeException implements Exception {
  const EmAppRuntimeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmAppRuntimeLogEntry {
  const EmAppRuntimeLogEntry({
    required this.kind,
    required this.message,
    required this.time,
  });

  final String kind;
  final String message;
  final DateTime time;
}

class EmAppLaunchResult {
  const EmAppLaunchResult({
    required this.package,
    required this.url,
    required this.logs,
    required this.close,
    this.unsupported = false,
  });

  final EmAppPackage package;
  final Uri url;
  final List<EmAppRuntimeLogEntry> logs;
  final Future<void> Function() close;
  final bool unsupported;
}

class EmAppRuntime {
  EmAppRuntime({required EmAppsClient client, bool persistLogs = false})
    : _client = client;

  final EmAppsClient _client;

  Future<List<EmAppRuntimeLogEntry>> loadStoredLogs() async {
    return const <EmAppRuntimeLogEntry>[];
  }

  Future<void> clearStoredData() async {}

  Future<EmAppLaunchResult> open(String appId) async {
    final info = await _client.info(appId);
    return EmAppLaunchResult(
      package: info,
      url: Uri.parse('about:blank'),
      logs: [
        EmAppRuntimeLogEntry(
          kind: 'EMAPPS',
          message: 'eMApps runtime is not supported on Web.',
          time: DateTime.now(),
        ),
      ],
      close: () async {},
      unsupported: true,
    );
  }
}

Future<String> emAppPackageSha256Hex(Uint8List bytes) async {
  throw const EmAppRuntimeException('eMApps runtime is not supported on Web.');
}
