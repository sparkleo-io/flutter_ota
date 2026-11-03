import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// In-memory OTA session logs captured when `updateFirmware` is called with
/// `saveOtaLogs: true` (the default).
///
/// Read via [otaSessionLogs] / [otaSessionLogText]; clear with
/// [clearOtaSessionLogs].
///
/// Capture stores status / handshake / progress / error lines only. Raw
/// firmware payloads and other oversized dumps are never written to the buffer
/// (see [_maxSessionLogMessageLength]).
final List<String> _otaSessionLogBuffer = <String>[];

bool _otaLogCaptureEnabled = false;

/// Messages longer than this are treated as accidental binary dumps and
/// skipped from [otaSessionLogs] (a full `.bin` `toString()` is megabytes).
const int _maxSessionLogMessageLength = 2048;

/// Whether the package is currently appending OTA logs to [otaSessionLogs].
bool get otaLogCaptureEnabled => _otaLogCaptureEnabled;

/// Unmodifiable snapshot of captured OTA session log lines.
List<String> get otaSessionLogs =>
    List<String>.unmodifiable(_otaSessionLogBuffer);

/// Captured OTA session logs as a single newline-separated string.
String get otaSessionLogText => _otaSessionLogBuffer.join('\n');

/// Clears any previously captured OTA session logs.
void clearOtaSessionLogs() {
  _otaSessionLogBuffer.clear();
}

/// Starts or stops in-memory OTA log capture for the current session.
///
/// When [enabled] is `true`, existing logs are cleared so the buffer reflects
/// only the upcoming OTA run.
void setOtaLogCaptureEnabled(bool enabled) {
  _otaLogCaptureEnabled = enabled;
  if (enabled) {
    _otaSessionLogBuffer.clear();
  }
}

/// Shared logger for the OTA package.
///
/// Uses [PrettyPrinter] on the console so the BLE/OTA flow is easy to follow
/// during development. When log capture is enabled (see
/// [setOtaLogCaptureEnabled]), lines are also stored in [otaSessionLogs] so
/// host apps can show them on a logger screen. Capture continues in release
/// builds; console output still follows the usual development filter unless
/// capture is on.
final Logger otaLogger = Logger(
  filter: _OtaLogFilter(),
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 6,
    lineLength: 90,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  output: MultiOutput([
    ConsoleOutput(),
    _OtaSessionLogOutput(),
  ]),
);

/// When `true`, emits extra transfer traces (packet indices, payload lengths,
/// small handshake opcodes). Off by default to reduce console noise.
///
/// Never enables logging of full firmware binaries — only status-style lines.
bool otaVerboseLogging = false;

void verboseTrace(String message) {
  if (otaVerboseLogging) {
    otaLogger.t(message);
  }
}

void verboseDebug(String message) {
  if (otaVerboseLogging) {
    otaLogger.d(message);
  }
}

class _OtaLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (_otaLogCaptureEnabled) return true;
    var allow = !kReleaseMode;
    assert(() {
      allow = true;
      return true;
    }());
    return allow;
  }
}

/// Stores plain, ANSI-free lines for UI display while the console keeps
/// PrettyPrinter formatting.
class _OtaSessionLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (!_otaLogCaptureEnabled) return;

    final LogEvent origin = event.origin;
    final String message = origin.message?.toString() ?? '';
    if (!_isSafeForSessionLog(message)) return;

    final String time = DateTime.now().toIso8601String().substring(11, 23);
    final String level = origin.level.name.toUpperCase().padRight(7);
    final StringBuffer line = StringBuffer('[$time] $level $message');
    if (origin.error != null) {
      final String errorText = origin.error.toString();
      if (_isSafeForSessionLog(errorText)) {
        line.write(' | error: $errorText');
      }
    }
    _otaSessionLogBuffer.add(line.toString());
  }
}

/// Returns false for oversized or firmware-dump-shaped messages so session
/// logs stay readable and never retain binary payloads.
bool _isSafeForSessionLog(String text) {
  if (text.length > _maxSessionLogMessageLength) return false;
  // Defensive: older builds interpolated `Uint8List.toString()` here.
  if (text.startsWith('Loaded firmware bytes: [')) return false;
  return true;
}
