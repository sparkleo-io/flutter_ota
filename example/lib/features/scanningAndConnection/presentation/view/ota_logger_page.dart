import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ota/flutter_ota.dart';

import '../../../../common/toast/show_toast.dart';

/// Displays in-memory OTA session logs captured when `saveOtaLogs` is enabled.
class OtaLoggerPage extends StatefulWidget {
  const OtaLoggerPage({super.key});

  @override
  State<OtaLoggerPage> createState() => _OtaLoggerPageState();
}

class _OtaLoggerPageState extends State<OtaLoggerPage> {
  void _refresh() => setState(() {});

  Future<void> _copyLogs() async {
    final String logText = otaSessionLogText;
    if (logText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: logText));
    showToast('Logs copied');
  }

  void _clearLogs() {
    clearOtaSessionLogs();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> logs = otaSessionLogs;
    final bool hasLogs = logs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OTA Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy logs',
            onPressed: hasLogs ? _copyLogs : null,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Clear logs',
            onPressed: hasLogs ? _clearLogs : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: !hasLogs
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No OTA logs yet.\nStart an OTA update with saveOtaLogs '
                    'enabled to capture detailed logs here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return SelectableText(
                    logs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
