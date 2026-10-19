import 'dart:async';
import 'dart:io';
import 'package:nex_core/nex_core.dart';
import 'package:path/path.dart' as p;
import '../core/controller.dart';

Future<void> installWindowsUpdate(
  File installer,
  String digest,
  PanelController controller,
) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows installation only');
  final executable = File(Platform.resolvedExecutable);
  final helper = File(p.join(executable.parent.path, 'nex_update.exe'));
  final cachedHelper = await helper.copy(
    p.join(installer.parent.path, 'nex_update.exe'),
  );
  final ready = File('${installer.path}.ready');
  if (await ready.exists()) await ready.delete();
  final nonce = newUuidV7();
  final child = await Process.start(cachedHelper.path, [
    '--apply-update',
    '$pid',
    installer.path,
    digest,
    executable.path,
    nonce,
    controller.resolvedLanguage == 'fa' ? 'farsi' : 'english',
  ], mode: ProcessStartMode.detached);
  try {
    final until = DateTime.now().add(const Duration(seconds: 15));
    while (!await ready.exists() || (await ready.readAsString()) != nonce) {
      if (DateTime.now().isAfter(until)) {
        throw StateError('Updater did not become ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await controller.quit();
    if (!controller.shutdownQueued) {
      throw StateError('Could not save and close Nex');
    }
  } catch (_) {
    Process.killPid(child.pid);
    rethrow;
  }
}
