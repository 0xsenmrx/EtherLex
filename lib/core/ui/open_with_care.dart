import 'package:flutter/widgets.dart';

import '../../design_system/ether/dialog.dart';
import '../utils/open_path.dart';

/// Opens a file that came from Canvas the careful way: programs and scripts
/// are only shown in their folder, web pages ask first (their scripts run in
/// the browser), everything else opens marked as downloaded from the internet.
Future<void> openWithCare(BuildContext context, String path) async {
  switch (openSafetyOf(path)) {
    case OpenSafety.open:
    case OpenSafety.revealOnly:
      await openDownloaded(path);
    case OpenSafety.askFirst:
      final ok = await confirmAction(
        context,
        title: 'Open this web page?',
        message: 'It came from Canvas and opens in your browser, where its scripts can run. '
            'Open it only if you trust where it came from.',
        confirmLabel: 'Open in browser',
      );
      if (!ok) return;
      try {
        await launchMarked(path);
      } catch (_) {}
  }
}
