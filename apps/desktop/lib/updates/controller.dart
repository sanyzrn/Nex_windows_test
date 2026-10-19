import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

enum UpdatePhase { idle, checking, available, downloading, ready, installing }

/// Only stable releases and the exact x64 assets from our public repository.
class WindowsRelease {
  WindowsRelease._(this.version, this.installer, this.checksums);
  final String version;
  final Map<String, dynamic> installer, checksums;
  String get filename => 'Nex-Windows-Setup-$version-x64.exe';
  String get digest => (installer['digest'] as String).substring(7);
  int get size => installer['size'] as int;
  Uri get page => Uri.parse('$repository/releases/tag/v$version');
  static const repository = 'https://github.com/sanyzrn/Nex_windows_test';
  static final latest = Uri.parse(
    'https://api.github.com/repos/sanyzrn/Nex_windows_test/releases/latest',
  );
  static List<int> parts(String version) {
    final match = RegExp(
      r'^(?:v)?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
    ).firstMatch(version);
    if (match == null) throw const FormatException('Invalid release version');
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  static int compare(String a, String b) {
    final left = parts(a), right = parts(b);
    for (var i = 0; i < 3; i++) {
      final c = left[i].compareTo(right[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  factory WindowsRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (json['draft'] != false ||
        json['prerelease'] != false ||
        tag is! String ||
        !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
      throw const FormatException('Not a stable release');
    }
    final version = tag.substring(1);
    parts(version);
    final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
    Map<String, dynamic> asset(String name, int maximum) {
      final matches = assets.where((a) => a['name'] == name).toList();
      if (matches.length != 1) throw const FormatException('Missing asset');
      final a = matches.single;
      if (a['state'] != 'uploaded' ||
          a['size'] is! int ||
          (a['size'] as int) <= 0 ||
          (a['size'] as int) > maximum ||
          a['digest'] is! String ||
          !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(a['digest'] as String) ||
          a['browser_download_url'] !=
              '$repository/releases/download/$tag/$name') {
        throw const FormatException('Untrusted release asset');
      }
      return a;
    }

    return WindowsRelease._(
      version,
      asset('Nex-Windows-Setup-$version-x64.exe', 256 * 1024 * 1024),
      asset('SHA256SUMS', 64 * 1024),
    );
  }
}

/// The application owns this service; building a settings widget never starts
/// networking. No GitHub token, note, API credential or device ID is sent.
class DesktopUpdates extends ChangeNotifier {
  DesktopUpdates({
    required this.currentVersion,
    required this.cache,
    required this.install,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;
  final String currentVersion;
  final Directory cache;
  final Future<void> Function(File installer, String digest) install;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  SharedPreferences? _prefs;
  Future<void>? _loadTask, _operation;
  http.Client? _client;
  Timer? _timer;
  int _generation = 0;
  bool _closed = false;
  bool automatic = true;
  UpdatePhase phase = UpdatePhase.idle;
  WindowsRelease? release;
  File? installer;
  double progress = 0;
  String? error;
  DateTime? lastChecked;
  bool get busy => const {
    UpdatePhase.checking,
    UpdatePhase.downloading,
    UpdatePhase.installing,
  }.contains(phase);
  bool get ready => installer != null;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() => _loadTask ??= _load();
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    automatic = _prefs!.getBool('updates.automatic') ?? true;
    lastChecked = DateTime.tryParse(_prefs!.getString('updates.checked') ?? '');
    try {
      final raw = _prefs!.getString('updates.release');
      if (raw != null) {
        final candidate = WindowsRelease.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (WindowsRelease.compare(candidate.version, currentVersion) > 0) {
          release = candidate;
          phase = UpdatePhase.available;
          final file = File(
            p.join(cache.path, 'v${candidate.version}', candidate.filename),
          );
          if (await _valid(file, candidate)) {
            installer = file;
            phase = UpdatePhase.ready;
            final result = File('${file.path}.result');
            if (await result.exists() &&
                (await result.readAsString()).trim() != '0') {
              error = 'install';
            }
          }
        }
      }
    } catch (_) {
      // A 304 is only useful when the cached release itself is valid.
      await _prefs!.remove('updates.etag');
      await _prefs!.remove('updates.release');
      await _prefs!.remove('updates.checked');
      lastChecked = null;
    }
    _notify();
  }

  Future<void> start() async {
    if (_closed) return;
    await initialize();
    if (_closed) return;
    _timer ??= Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(check(manual: false)),
    );
    await _cleanOldDownloads();
    unawaited(check(manual: false));
  }

  Future<void> _cleanOldDownloads() async {
    if (!await cache.exists()) return;
    await for (final entry in cache.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (!RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(name)) continue;
      if (WindowsRelease.compare(name, currentVersion) <= 0) {
        try {
          await entry.delete(recursive: true);
        } on FileSystemException {
          /* A helper may still be exiting. */
        }
      }
    }
  }

  Future<void> setAutomatic(bool value) async {
    await initialize();
    if (!await _prefs!.setBool('updates.automatic', value)) {
      throw StateError('Preference not saved');
    }
    automatic = value;
    if (!value && phase != UpdatePhase.installing) cancel();
    _notify();
    if (value) unawaited(check(manual: false));
  }

  Future<void> check({bool manual = true}) => _coalesce(() async {
    await initialize();
    if (_closed ||
        (!manual &&
            (!automatic ||
                lastChecked != null &&
                    _clock().difference(lastChecked!) <
                        const Duration(hours: 6)))) {
      return;
    }
    final generation = _generation;
    phase = UpdatePhase.checking;
    error = null;
    _notify();
    try {
      final client = _client = _clientFactory();
      final response = await client
          .get(
            WindowsRelease.latest,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Nex-Windows/$currentVersion',
              'X-GitHub-Api-Version': '2026-03-10',
              if (_prefs!.getString('updates.etag') case final String etag)
                'If-None-Match': etag,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (_stale(generation)) return;
      if (response.statusCode == 200) {
        if (response.bodyBytes.length > 1024 * 1024) {
          throw const FormatException('Metadata too large');
        }
        final raw = jsonDecode(response.body) as Map<String, dynamic>;
        final candidate = WindowsRelease.fromJson(raw);
        await _prefs!.setString('updates.release', jsonEncode(raw));
        final etag = response.headers['etag'];
        if (etag != null) {
          await _prefs!.setString('updates.etag', etag);
        } else {
          await _prefs!.remove('updates.etag');
        }
        if (WindowsRelease.compare(candidate.version, currentVersion) > 0) {
          if (release?.digest != candidate.digest) installer = null;
          release = candidate;
        } else {
          release = null;
          installer = null;
        }
      } else if (response.statusCode != 304 ||
          _prefs!.getString('updates.release') == null) {
        throw HttpException('Release status ${response.statusCode}');
      }
      lastChecked = _clock();
      await _prefs!.setString(
        'updates.checked',
        lastChecked!.toUtc().toIso8601String(),
      );
      if (_stale(generation)) return;
      phase = ready
          ? UpdatePhase.ready
          : release == null
          ? UpdatePhase.idle
          : UpdatePhase.available;
      _notify();
      if (automatic && release != null && !ready) await _download(generation);
    } catch (_) {
      if (!_stale(generation)) {
        error = 'check';
        phase = ready
            ? UpdatePhase.ready
            : release == null
            ? UpdatePhase.idle
            : UpdatePhase.available;
      }
    } finally {
      if (!_stale(generation)) {
        _client?.close();
        _client = null;
        _notify();
      }
    }
  });

  Future<void> download() => _coalesce(() async {
    await initialize();
    if (_closed || release == null || ready) return;
    _client = _clientFactory();
    final generation = _generation;
    try {
      await _download(generation);
    } catch (_) {
      if (!_stale(generation)) {
        error = 'download';
        phase = UpdatePhase.available;
      }
    } finally {
      if (!_stale(generation)) {
        _client?.close();
        _client = null;
        _notify();
      }
    }
  });

  Future<void> _download(int generation) async {
    final target = release!;
    phase = UpdatePhase.downloading;
    progress = 0;
    error = null;
    _notify();
    final directory = Directory(p.join(cache.path, 'v${target.version}'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, target.filename));
    final partial = File('${file.path}.part');
    final deadline = Timer(const Duration(minutes: 8), () {
      if (!_stale(generation)) _client?.close();
    });
    try {
      final sums = await _bytes(target.checksums, generation);
      if (sha256.convert(sums).toString() !=
              (target.checksums['digest'] as String).substring(7) ||
          utf8.decode(sums).trim() != '${target.digest}  ${target.filename}') {
        throw const FormatException('Manifest mismatch');
      }
      final response = await _response(
        Uri.parse(target.installer['browser_download_url'] as String),
      );
      if (response.statusCode != 200 ||
          response.contentLength != null &&
              response.contentLength != target.size) {
        throw const FormatException('Installer response mismatch');
      }
      var count = 0, shownPercent = -1;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          if (_stale(generation)) throw StateError('Cancelled');
          count += chunk.length;
          if (count > target.size) {
            throw const FormatException('Oversized installer');
          }
          sink.add(chunk);
          progress = count / target.size;
          final percent = (progress * 100).floor();
          if (percent != shownPercent) {
            shownPercent = percent;
            _notify();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (_stale(generation)) return;
      if (count != target.size || !await _valid(partial, target)) {
        throw const FormatException('Installer checksum mismatch');
      }
      if (_stale(generation)) return;
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
      installer = file;
      phase = UpdatePhase.ready;
      _notify();
    } finally {
      deadline.cancel();
      if (await partial.exists()) await partial.delete();
    }
  }

  static bool _downloadHost(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      const {
        'github.com',
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
      }.contains(uri.host);
  Future<http.StreamedResponse> _response(Uri uri) async {
    for (var redirect = 0; redirect <= 5; redirect++) {
      if (!_downloadHost(uri)) {
        throw const FormatException('Untrusted redirect');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['User-Agent'] = 'Nex-Windows/$currentVersion';
      final response = await _client!
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null) throw const FormatException('Missing redirect');
        uri = uri.resolve(location);
        continue;
      }
      return response;
    }
    throw const FormatException('Too many redirects');
  }

  Future<List<int>> _bytes(Map<String, dynamic> asset, int generation) async {
    final response = await _response(
      Uri.parse(asset['browser_download_url'] as String),
    );
    if (response.statusCode != 200) {
      throw const FormatException('Download failed');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (_stale(generation)) throw StateError('Cancelled');
      bytes.addAll(chunk);
      if (bytes.length > (asset['size'] as int)) {
        throw const FormatException('Oversized checksum');
      }
    }
    if (bytes.length != asset['size']) {
      throw const FormatException('Truncated checksum');
    }
    return bytes;
  }

  Future<bool> _valid(File file, WindowsRelease target) async {
    if (!await file.exists() || await file.length() != target.size) {
      return false;
    }
    final header = await file.open();
    try {
      final magic = await header.read(2);
      if (magic.length != 2 || magic[0] != 0x4d || magic[1] != 0x5a) {
        return false;
      }
    } finally {
      await header.close();
    }
    return (await sha256.bind(file.openRead()).first).toString() ==
        target.digest;
  }

  Future<void> installReady() => _coalesce(() async {
    if (installer == null || release == null || _closed) return;
    phase = UpdatePhase.installing;
    error = null;
    _notify();
    try {
      if (!await _valid(installer!, release!)) {
        installer = null;
        error = 'download';
        phase = UpdatePhase.available;
        _notify();
        return;
      }
      await install(installer!, release!.digest);
    } catch (_) {
      if (!_closed) {
        error = 'install';
        phase = UpdatePhase.ready;
        _notify();
      }
    }
  });

  Future<void> _coalesce(Future<void> Function() body) {
    if (_operation != null) return _operation!;
    final task = Future<void>.sync(body);
    _operation = task;
    return task.whenComplete(() {
      if (identical(_operation, task)) _operation = null;
    });
  }

  bool _stale(int generation) => _closed || generation != _generation;
  void cancel() {
    if (phase == UpdatePhase.installing) return;
    _generation++;
    _client?.close();
    _client = null;
    phase = ready
        ? UpdatePhase.ready
        : release == null
        ? UpdatePhase.idle
        : UpdatePhase.available;
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _timer?.cancel();
    _client?.close();
    super.dispose();
  }
}
