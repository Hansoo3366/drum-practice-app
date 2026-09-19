import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';

class JamQrScanScreen extends StatefulWidget {
  const JamQrScanScreen({super.key});

  @override
  State<JamQrScanScreen> createState() => _JamQrScanScreenState();
}

class _JamQrScanScreenState extends State<JamQrScanScreen> {
  var _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) {
        continue;
      }
      final code = parseJamInvite(value);
      if (code == null) {
        continue;
      }
      _handled = true;
      Navigator.pop(context, code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: AppTheme.stage,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.scanQr)),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, _) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.cameraMissing,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.canvas,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Text(
                    l10n.jamHubHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.canvas.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
