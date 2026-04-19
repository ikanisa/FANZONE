import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/di/injection.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  PathProviderPlatform.instance = _TestPathProviderPlatform();
  await configureDependencies();
  await testMain();
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform() : _root = _ensureRoot();

  final Directory _root;

  static Directory _ensureRoot() {
    final directory = Directory(
      '${Directory.systemTemp.path}/fanzone_flutter_test_paths',
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<String?> _pathFor(String name) async {
    final directory = Directory('${_root.path}/$name');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory.path;
  }

  @override
  Future<String?> getApplicationCachePath() => _pathFor('application_cache');

  @override
  Future<String?> getApplicationDocumentsPath() =>
      _pathFor('application_documents');

  @override
  Future<String?> getApplicationSupportPath() =>
      _pathFor('application_support');

  @override
  Future<String?> getDownloadsPath() => _pathFor('downloads');

  @override
  Future<List<String>?> getExternalCachePaths() async => <String>[
    (await _pathFor('external_cache'))!,
  ];

  @override
  Future<String?> getExternalStoragePath() => _pathFor('external_storage');

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => <String>[(await _pathFor('external_storage_paths'))!];

  @override
  Future<String?> getLibraryPath() => _pathFor('library');

  @override
  Future<String?> getTemporaryPath() => _pathFor('temporary');
}
