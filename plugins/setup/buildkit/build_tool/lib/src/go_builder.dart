import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'environment.dart';
import 'error.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('go_builder');

String _resolveCcAndroid(Target target) {
  final ndk = Environment.androidNdk;
  final prebuiltDir = Directory(
    p.join(ndk, 'toolchains', 'llvm', 'prebuilt'),
  );
  final entries = prebuiltDir
      .listSync()
      .where((e) => !p.basename(e.path).startsWith('.'))
      .toList();
  if (entries.isEmpty) {
    throw BuildException('No NDK prebuilt toolchain found in $prebuiltDir');
  }
  return p.join(entries.first.path, 'bin', target.ndkCcName);
}

String _resolveCcOpenHarmony(Target target) {
  final ndk = Environment.openHarmonySdk;
  final prebuiltDir = Directory(
    p.join(ndk, 'native', 'llvm'),
  );
  return p.join(prebuiltDir.path, 'bin', target.ndkCcName);
}

class GoBuilder {
  final String rootDir;
  final BuildConfig config;

  GoBuilder({required this.rootDir, required this.config});

  String get _corePath => p.join(rootDir, config.coreDir);
  String get _outputPath => p.join(rootDir, config.outputDir);

  Future<String> build(Target target) async {
    // Desktop: output directly to libclash/{platform}/
    // Android: output to libclash/android/{abi}/
    final outDir = target.isLib
        ? p.join(_outputPath, target.platformDir, target.abi!)
        : p.join(_outputPath, target.platformDir);
    ensureDir(outDir);

    final fileName = target.isLib
        ? '${config.libName}${target.dynamicLibExtension}'
        : '${config.coreName}${target.executableExtension}';
    final outFile = p.join(outDir, fileName);

    final env = <String, String>{
      'GOOS': target.goos,
      'GOARCH': target.goarch,
    };

    if (target.isLib) {
      switch (target.goos) {
        case 'android':
          env['CGO_ENABLED'] = '1';
          env['CC'] = _resolveCcAndroid(target);
          env['CFLAGS'] = '-O3 -Werror';
        case 'openharmony':
          env['CGO_ENABLED'] = '1';
          env['CC'] = _resolveCcOpenHarmony(target);
          env['CFLAGS'] = '-O3 -Werror';
        default:
          throw Exception('Unknown GOOS: $target.goos');
      }
    } else {
      env['CGO_ENABLED'] = '0';
    }

    final args = [
      'build',
      '-ldflags=${config.goLdflags}',
      '-tags=${config.tags}',
      if (target.isLib) '-buildmode=c-shared',
      '-o',
      outFile,
    ];

    _log.info(kDoubleSeparator);
    _log.info(
        'Building Go core: $target ${target.isLib ? "(CGO, c-shared)" : "(standalone)"}');
    _log.info(kSeparator);

    await runCommandStream('go', args,
        workingDirectory: _corePath, environment: env);

    if (target.isLib && target.abi != null) {
      switch (target.goos) {
        case 'android':
          await _adjustAndroidOutput(
            outDir: p.join(_outputPath, target.platformDir),
            abiDir: target.abi!,
            archName: target.abi!,
            libPath: outFile,
            libName: fileName);
        case 'openharmony':
          await _adjustOpenHarmonyOutput(
            outDir: p.join(_outputPath, target.platformDir),
            abiDir: target.abi!,
            archName: target.abi!,
            libPath: outFile,
            libName: fileName);
        default:
          throw Exception('Unknown GOOS: $target.goos');
      }
      
    }

    _log.info('Built: $outFile');
    return outFile;
  }

  Future<List<String>> buildAll(List<Target> targets) async {
    final results = await Future.wait(targets.map(build));
    return results;
  }

  Future<void> _adjustAndroidOutput({
    required String outDir,
    required String abiDir,
    required String archName,
    required String libPath,
    required String libName,
  }) async {
    final includesPath = p.join(outDir, 'includes', archName);
    final androidCoreMainPath =
        p.join(rootDir, 'android', 'core', 'src', 'main');
    final jniLibsPath = p.join(androidCoreMainPath, 'jniLibs', abiDir);
    final cppIncludesPath =
        p.join(androidCoreMainPath, 'cpp', 'includes', archName);

    ensureDir(jniLibsPath);
    ensureDir(includesPath);
    _clearDirectory(includesPath);
    ensureDir(cppIncludesPath);
    _clearDirectory(cppIncludesPath);

    _deleteIfExists(p.join(jniLibsPath, libName));
    File(libPath).copySync(p.join(jniLibsPath, libName));

    final abiDirPath = p.join(outDir, abiDir);
    final headerFiles = [
      ...Directory(abiDirPath).listSync(),
      ...Directory(_corePath).listSync(),
    ];
    for (final file in headerFiles) {
      if (!file.path.endsWith('.h')) continue;
      final fileName = p.basename(file.path);
      final source = File(file.path);
      source.copySync(p.join(includesPath, fileName));
      source.copySync(p.join(cppIncludesPath, fileName));
      if (file.path.startsWith(abiDirPath)) {
        source.deleteSync();
      }
    }
  }

  Future<void> _adjustOpenHarmonyOutput({
    required String outDir,
    required String abiDir,
    required String archName,
    required String libPath,
    required String libName,
  }) async {
    final includesPath = p.join(outDir, 'includes', archName);
    final openHarmonyCoreMainPath =
        p.join(rootDir, 'ohos', 'core');
    final libsPath = p.join(openHarmonyCoreMainPath, 'libs', abiDir);
    final cppIncludesPath =
        p.join(openHarmonyCoreMainPath, 'src', 'main', 'cpp', 'includes', archName);

    ensureDir(libsPath);
    ensureDir(includesPath);
    _clearDirectory(includesPath);
    ensureDir(cppIncludesPath);
    _clearDirectory(cppIncludesPath);

    _deleteIfExists(p.join(libsPath, libName));
    File(libPath).copySync(p.join(libsPath, libName));

    final abiDirPath = p.join(outDir, abiDir);
    final headerFiles = [
      ...Directory(abiDirPath).listSync(),
      ...Directory(_corePath).listSync(),
    ];
    for (final file in headerFiles) {
      if (!file.path.endsWith('.h')) continue;
      final fileName = p.basename(file.path);
      final source = File(file.path);
      source.copySync(p.join(includesPath, fileName));
      source.copySync(p.join(cppIncludesPath, fileName));
      if (file.path.startsWith(abiDirPath)) {
        source.deleteSync();
      }
    }
  }

  void _clearDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync()) {
      if (entity is File || entity is Link) {
        entity.deleteSync();
      } else if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }
  }

  void _deleteIfExists(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
