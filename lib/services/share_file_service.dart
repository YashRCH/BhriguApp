import 'dart:io';

import 'package:flutter/services.dart';

class ShareFileService {
  static const MethodChannel _channel = MethodChannel(
    'dev.fluttercommunity.plus/share',
  );

  static Future<void> shareImageFile(
    File file, {
    String? text,
    String? subject,
  }) {
    return _channel.invokeMethod<void>('shareFiles', {
      'paths': [file.path],
      'mimeTypes': ['image/png'],
      if (text != null) 'text': text,
      if (subject != null) 'subject': subject,
    });
  }
}
