import 'dart:io';
import 'package:archive/archive_io.dart';

enum NexBackupKind {
  library,
  full,
  export;

  /// Read the container, not a file-provider-assigned suffix.
  static NexBackupKind detect(String path) {
    final file = File(path);
    final handle = file.openSync();
    try {
      final header = handle.readSync(16);
      if (String.fromCharCodes(header) == 'SQLite format 3\u0000') {
        return NexBackupKind.library;
      }
    } finally {
      handle.closeSync();
    }
    final input = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      if (archive.findFile('format.json') != null &&
          archive.findFile('settings.aes.zip') != null &&
          archive.findFile('library.nexbak') != null) {
        return NexBackupKind.full;
      }
      if (archive.findFile('nex.sqlite') != null) return NexBackupKind.library;
      if (archive.findFile('notes.json') != null) return NexBackupKind.export;
      throw const FormatException('Not a Nex backup or export');
    } finally {
      input.closeSync();
    }
  }
}
