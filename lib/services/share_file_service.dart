import 'dart:io';

import 'package:share_plus/share_plus.dart';

class ShareFileService {
  static Future<void> shareImageFile(
    File file, {
    String? text,
    String? subject,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Share file does not exist', file.path);
    }

    // shareXFiles uses Android's result callback in share_plus 7.x, which can
    // stay locked if the chooser does not report back. We only need to open
    // the share sheet, so use the non-result file share path.
    // ignore: deprecated_member_use
    await Share.shareFiles(
      [file.path],
      mimeTypes: ['image/png'],
      text: text,
      subject: subject,
    );
  }
}
