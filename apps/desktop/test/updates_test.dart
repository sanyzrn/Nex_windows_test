import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nex_desktop/updates/controller.dart';
import 'package:nex_desktop/updates/widgets.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _binary = [0x4d, 0x5a, 1, 2, 3, 4];
String _hash(List<int> bytes) => sha256.convert(bytes).toString();
Map<String, dynamic> _release({String version = '0.22.0', List<int>? bytes}) {
  bytes ??= _binary;
  final name = 'Nex-Windows-Setup-$version-x64.exe';
  final sums = utf8.encode('${_hash(bytes)}  $name\r\n');
  Map<String, dynamic> asset(String name, List<int> content) => {
    'name': name,
    'state': 'uploaded',
    'size': content.length,
    'digest': 'sha256:${_hash(content)}',
    'browser_download_url':
        '${WindowsRelease.repository}/releases/download/v$version/$name',
  };
  return {
    'tag_name': 'v$version',
    'draft': false,
    'prerelease': false,
    'assets': [asset(name, bytes), asset('SHA256SUMS', sums)],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DesktopUpdates updates;
  var installed = 0;
  final requests = <http.Request>[];
  late Map<String, dynamic> metadata;
  FutureOr<http.Response> Function(http.Request)? respond;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('nex-updates-test-');
    metadata = _release();
    installed = 0;
    respond = null;
    requests.clear();
    updates = DesktopUpdates(
      currentVersion: '0.21.0',
      cache: root,
      install: (file, digest) async {
        installed++;
      },
      clientFactory: () => MockClient((r) async {
        requests.add(r);
        if (respond != null) return await respond!(r);
        if (r.url == WindowsRelease.latest) {
          return http.Response(
            jsonEncode(metadata),
            200,
            headers: {'etag': 'release-v22'},
          );
        }
        if (r.url.path.endsWith('/SHA256SUMS')) {
          return http.Response(
            '${_hash(_binary)}  Nex-Windows-Setup-0.22.0-x64.exe\r\n',
            200,
          );
        }
        return http.Response.bytes(_binary, 200);
      }),
    );
  });
  tearDown(() async {
    updates.dispose();
    await root.delete(recursive: true);
  });
  Future<void> waitUntil(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(condition(), isTrue);
  }

  test(
    'version ordering rejects downgrade, prerelease and malformed versions',
    () {
      expect(WindowsRelease.compare('0.22.0', '0.21.9'), greaterThan(0));
      expect(WindowsRelease.compare('0.9.9', '0.21.0'), lessThan(0));
      expect(WindowsRelease.compare('0.21.0+14', 'v0.21.0'), 0);
      for (final raw in [
        'v1.0',
        '1.0.0-rc.1',
        'https://evil.test/1.0.0',
        '../1.2.3',
      ]) {
        expect(() => WindowsRelease.parts(raw), throwsFormatException);
      }
      expect(
        () => WindowsRelease.fromJson(_release()..['prerelease'] = true),
        throwsFormatException,
      );
      expect(
        () => WindowsRelease.fromJson(_release()..['draft'] = true),
        throwsFormatException,
      );
    },
  );
  test(
    'initialization never makes a request or launches an installer',
    () async {
      await updates.initialize();
      expect(updates.automatic, isTrue);
      expect(requests, isEmpty);
      expect(installed, 0);
    },
  );
  test(
    'latest stable download is checked, cached and only installed on request',
    () async {
      await updates.check();
      expect(requests, hasLength(3));
      expect(updates.phase, UpdatePhase.ready);
      expect(await updates.installer!.readAsBytes(), _binary);
      expect(installed, 0);
      await updates.installReady();
      expect(installed, 1);
    },
  );
  test('a lower or same release never downloads or installs', () async {
    for (final version in ['0.20.0', '0.21.0']) {
      metadata = _release(version: version);
      await updates.check();
      expect(updates.release, isNull);
      expect(updates.installer, isNull);
    }
    expect(requests, hasLength(2));
    expect(installed, 0);
  });
  test(
    'manual check respects disabled automatic download and offers an update',
    () async {
      await updates.initialize();
      await updates.setAutomatic(false);
      await updates.check();
      expect(requests, hasLength(1));
      expect(updates.phase, UpdatePhase.available);
      await updates.download();
      expect(updates.ready, isTrue);
    },
  );
  test(
    'untrusted asset URL or unsupported executable is rejected before download',
    () async {
      (metadata['assets'] as List).first['browser_download_url'] =
          'https://evil.test/installer.exe';
      await updates.check();
      expect(requests, hasLength(1));
      expect(updates.ready, isFalse);
      expect(updates.error, 'check');
      metadata = _release();
      (metadata['assets'] as List).first['size'] = 300 * 1024 * 1024;
      await updates.check();
      expect(requests, hasLength(2));
    },
  );
  test(
    'checksum manifest corruption prevents even requesting the executable',
    () async {
      respond = (r) => r.url == WindowsRelease.latest
          ? http.Response(jsonEncode(metadata), 200)
          : http.Response('wrong checksum', 200);
      await updates.check();
      expect(requests, hasLength(2));
      expect(updates.ready, isFalse);
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );
  test('corrupt executable is removed and cannot be installed', () async {
    respond = (r) {
      if (r.url == WindowsRelease.latest) {
        return http.Response(jsonEncode(metadata), 200);
      }
      if (r.url.path.endsWith('SHA256SUMS')) {
        return http.Response(
          '${_hash(_binary)}  Nex-Windows-Setup-0.22.0-x64.exe\r\n',
          200,
        );
      }
      return http.Response.bytes([0x4d, 0x5a, 9, 9, 9, 9], 200);
    };
    await updates.check();
    expect(updates.ready, isFalse);
    await updates.installReady();
    expect(installed, 0);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });
  test('an untrusted redirect is never followed', () async {
    respond = (r) => r.url == WindowsRelease.latest
        ? http.Response(jsonEncode(metadata), 200)
        : http.Response(
            '',
            302,
            headers: {'location': 'https://evil.test/payload'},
          );
    await updates.check();
    expect(
      requests.every(
        (r) => ['api.github.com', 'github.com'].contains(r.url.host),
      ),
      isTrue,
    );
    expect(updates.ready, isFalse);
  });
  test(
    'repeated checks coalesce and cancellation discards a delayed response',
    () async {
      final response = Completer<http.Response>();
      respond = (_) => response.future;
      final first = updates.check();
      final second = updates.check();
      await waitUntil(() => requests.isNotEmpty);
      updates.cancel();
      response.complete(http.Response(jsonEncode(metadata), 200));
      await Future.wait([first, second]);
      expect(requests, hasLength(1));
      expect(updates.release, isNull);
      expect(updates.ready, isFalse);
    },
  );
  test(
    'disabling automatic updates cancels a delayed installer download',
    () async {
      final response = Completer<http.Response>();
      respond = (r) {
        if (r.url == WindowsRelease.latest) {
          return http.Response(jsonEncode(metadata), 200);
        }
        if (r.url.path.endsWith('SHA256SUMS')) {
          return http.Response(
            '${_hash(_binary)}  Nex-Windows-Setup-0.22.0-x64.exe\r\n',
            200,
          );
        }
        return response.future;
      };
      final task = updates.check();
      await waitUntil(() => requests.length == 3);
      await updates.setAutomatic(false);
      response.complete(http.Response.bytes(_binary, 200));
      await task;
      expect(updates.ready, isFalse);
      expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );
  test(
    'a cached installer changed after verification is re-downloaded, never run',
    () async {
      await updates.check();
      await updates.installer!.writeAsBytes([1, 2, 3]);
      await updates.installReady();
      expect(installed, 0);
      expect(updates.phase, UpdatePhase.available);
      expect(updates.error, 'download');
      await updates.download();
      expect(updates.ready, isTrue);
    },
  );
  test(
    'corrupt cached metadata drops its ETag and cannot pass as up to date',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('updates.release', '{bad');
      await prefs.setString('updates.etag', 'bad-etag');
      await updates.initialize();
      expect(prefs.getString('updates.etag'), isNull);
      await updates.check();
      expect(requests.first.headers.containsKey('If-None-Match'), isFalse);
      expect(updates.ready, isTrue);
    },
  );
  test(
    'a temporary GitHub failure keeps the previous verified update usable',
    () async {
      await updates.check();
      final file = updates.installer;
      respond = (_) => http.Response('rate limited', 403);
      await updates.check();
      expect(updates.installer, file);
      expect(updates.phase, UpdatePhase.ready);
      expect(updates.error, 'check');
    },
  );

  for (final locale in ['en', 'fa']) {
    testWidgets(
      'update controls wrap and remain actionable in $locale at 200%',
      (t) async {
        await t.runAsync(updates.check);
        t.view.physicalSize = const Size(420, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('fa')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: locale == 'fa' ? nexDarkTheme() : nexLightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: NexUpdateCard(updates: updates),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final install = find.text(
          locale == 'fa' ? 'نصب و راه‌اندازی مجدد' : 'Install & restart',
        );
        await t.ensureVisible(install);
        await t.tap(install);
        for (var i = 0; i < 30 && installed == 0; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await t.pump();
        }
        expect(installed, 1);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
