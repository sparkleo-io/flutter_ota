import 'package:flutter/material.dart';
import 'package:flutter_ota/flutter_ota.dart';
import 'package:ota_new_protocol/utils/colors.dart';

import '../../ota_integrity_mode.dart';

class OtaOptionsForm extends StatelessWidget {
  const OtaOptionsForm({
    super.key,
    required this.updateType,
    required this.firmwareType,
    required this.integrityMode,
    required this.urlController,
    required this.shaController,
    required this.mtuController,
    required this.onUpdateTypeChanged,
    required this.onFirmwareTypeChanged,
    required this.onIntegrityModeChanged,
    required this.onValidateImage,
  });

  final UpdateType updateType;
  final FirmwareType firmwareType;
  final OtaIntegrityMode integrityMode;
  final TextEditingController urlController;
  final TextEditingController shaController;
  final TextEditingController mtuController;
  final ValueChanged<UpdateType> onUpdateTypeChanged;
  final ValueChanged<FirmwareType> onFirmwareTypeChanged;
  final ValueChanged<OtaIntegrityMode> onIntegrityModeChanged;
  final VoidCallback onValidateImage;

  @override
  Widget build(BuildContext context) {
    final int maxMtu = maxMtuForUpdateType(updateType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Module type'),
        const SizedBox(height: 8),
        SegmentedButton<UpdateType>(
          segments: const [
            ButtonSegment(
              value: UpdateType.espidf,
              label: Text('ESP-IDF'),
              icon: Icon(Icons.memory, size: 18),
            ),
            ButtonSegment(
              value: UpdateType.arduino,
              label: Text('Arduino'),
              icon: Icon(Icons.developer_board, size: 18),
            ),
          ],
          selected: {updateType},
          onSelectionChanged: (selection) {
            onUpdateTypeChanged(selection.first);
          },
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Chunk size (MTU)'),
        const SizedBox(height: 8),
        TextField(
          controller: mtuController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Firmware bytes per write',
            hintText: '$maxMtu max for ${updateType.name}',
            helperText: updateType == UpdateType.arduino
                ? 'Arduino adds a 2-byte header on the wire. Range 1–$maxMtu.'
                : 'ESP-IDF range 1–$maxMtu (ATT write max when MTU is 512).',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Firmware source'),
        const SizedBox(height: 8),
        SegmentedButton<FirmwareType>(
          segments: const [
            ButtonSegment(
              value: FirmwareType.filepicker,
              label: Text('File'),
              icon: Icon(Icons.folder_open, size: 18),
            ),
            ButtonSegment(
              value: FirmwareType.url,
              label: Text('URL'),
              icon: Icon(Icons.link, size: 18),
            ),
          ],
          selected: {firmwareType},
          onSelectionChanged: (selection) {
            onFirmwareTypeChanged(selection.first);
          },
        ),
        if (firmwareType == FirmwareType.url ||
            firmwareType == FirmwareType.assets) ...[
          const SizedBox(height: 12),
          TextField(
            controller: urlController,
            keyboardType: firmwareType == FirmwareType.url
                ? TextInputType.url
                : TextInputType.text,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: firmwareType == FirmwareType.url
                  ? 'Firmware URL'
                  : 'Asset path',
              hintText: firmwareType == FirmwareType.url
                  ? 'https://example.com/firmware.bin'
                  : 'assets/firmware.bin',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (firmwareType == FirmwareType.url)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 100,
                height: 30,
                child: OutlinedButton(
                  onPressed: onValidateImage,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: secondaryColor,
                    side: BorderSide(color: secondaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Validate'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        const _SectionLabel('Integrity'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in OtaIntegrityMode.values)
              ChoiceChip(
                label: Text(_labelFor(mode)),
                selected: integrityMode == mode,
                selectedColor: secondaryColor.withValues(alpha: 0.25),
                onSelected: (_) => onIntegrityModeChanged(mode),
              ),
          ],
        ),
        if (integrityMode.needsSha) ...[
          const SizedBox(height: 12),
          TextField(
            controller: shaController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Expected SHA-256 (hex)',
              hintText: '64 hex characters',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  static String _labelFor(OtaIntegrityMode mode) {
    return switch (mode) {
      OtaIntegrityMode.none => 'None',
      OtaIntegrityMode.preSha => 'Pre SHA',
      OtaIntegrityMode.postSha => 'Post SHA',
      OtaIntegrityMode.both => 'Both',
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
