import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nex_core/nex_core.dart';
import 'package:pdfrx/pdfrx.dart';

/// A two-page ASCII fixture, used only by explicit native/widget QA probes.
List<int> desktopPdfProbeBytes() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count 2 /Kids [3 0 R 4 0 R] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    for (final page in ['one', 'two'])
      (() {
        final text = 'BT /F1 18 Tf 30 300 Td (Nex B8 probe page $page) Tj ET';
        return '<< /Length ${text.length} >>\nstream\n$text\nendstream';
      })(),
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = [0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return ascii.encode(out.toString());
}

/// Runs in the Release EXE, proving PDFium is bundled and usable offline,
/// Windows secure writes round-trip and private copying avoids Nex history.
/// Windows Hello itself always needs a real-person check, never a test bypass.
Future<Map<String, Object>> probeDesktopModules(
  String temporaryRoot, {
  void Function(String stage)? onStage,
}) async {
  onStage?.call('pdfFixture');
  final file = File('$temporaryRoot/b8-probe.pdf');
  await file.writeAsBytes(desktopPdfProbeBytes());
  onStage?.call('pdfInitialize');
  await pdfrxFlutterInitialize();
  onStage?.call('pdfOpen');
  final document = await PdfDocument.openFile(file.path);
  var rendered = false, searched = false;
  try {
    onStage?.call('pdfRender');
    final image = await document.pages.last.render(width: 300, height: 400);
    rendered = image != null && image.width == 300 && image.height == 400;
    image?.dispose();
    onStage?.call('pdfSearch');
    searched =
        (await document.pages.last.loadText())?.fullText.contains(
          'probe page two',
        ) ==
        true;
    if (document.pages.length != 2 || !rendered || !searched) {
      throw StateError('PDF probe failed');
    }
  } finally {
    onStage?.call('pdfClose');
    await document.dispose();
  }
  const storage = FlutterSecureStorage();
  final key = 'nex.windows.b8.probe.${newUuidV7()}';
  var secure = false;
  try {
    onStage?.call('secureWrite');
    await storage.write(key: key, value: 'synthetic-b8-probe');
    onStage?.call('secureRead');
    secure = await storage.read(key: key) == 'synthetic-b8-probe';
  } finally {
    onStage?.call('secureDelete');
    await storage.delete(key: key);
  }
  if (!secure) throw StateError('Secure storage round-trip failed');
  const native = MethodChannel('rp/native');
  onStage?.call('privateClipboard');
  final clipboard = await native.invokeMapMethod<String, bool>(
    'privateClipboardSelfTest',
  );
  final privateClipboard =
      clipboard != null &&
      const [
        'copied',
        'excluded',
        'cleared',
        'replacementRetained',
        'replacementCleared',
      ].every((key) => clipboard[key] == true);
  if (!privateClipboard) {
    throw StateError('Private clipboard probe failed: $clipboard');
  }
  onStage?.call('complete');
  return {
    'pdfPages': 2,
    'pdfRendered': rendered,
    'pdfSearch': searched,
    'secureStorage': secure,
    'privateClipboard': privateClipboard,
  };
}
