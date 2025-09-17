import 'dart:async';

import 'package:remote_assets_gen/settings/asset_type.dart';
import 'package:remote_assets_gen/settings/import.dart';

/// A base class for all integrations. An integration is a class that
/// generates code for a specific asset type.
abstract class Integration {
  Integration();

  bool isEnabled = false;

  List<Import> get requiredImports;

  String get classOutput;

  String get className;

  /// Is this asset type supported by this integration?
  FutureOr<bool> isSupport(
    AssetType asset,
    String Function(String) urlConstructor,
  );

  bool get isConstConstructor;

  String classInstantiate({String? value, AssetType? asset}) {
    assert(value != null || asset != null);
    final buffer = StringBuffer(className);
    buffer.write('(');
    buffer.write('\'$value\'');
    buffer.write(')');
    return buffer.toString();
  }

  static String get requiredHelperClasses => r"""
class RemoteAssetProvider {
  final String _assetUrl;

  RemoteAssetProvider(this._assetUrl);

  Future<File> getFile() async {
    final cacheManager = _RemoteAssetCacheManager.instance;
    final file = await cacheManager.getSingleFile(_assetUrl);
    return file;
  }
}
class _RemoteAssetCacheManager {
  static const key = 'remoteAssetCacheManager';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 5000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );
}

  """;
}

/// The deprecation message for the package argument
/// if the asset is a library asset.
const String deprecationMessagePackage =
    "@Deprecated('Do not specify package for a generated library asset')";

/// Useful metadata about the parsed asset file when [parseMetadata] is true.
/// Currently only contains the width and height, but could contain more in
/// future.
class ImageMetadata {
  const ImageMetadata({
    required this.width,
    required this.height,
    this.animation,
  });

  final double width;
  final double height;
  final ImageAnimation? animation;
}

/// Metadata about the parsed animation file when [parseAnimation] is true.
class ImageAnimation {
  const ImageAnimation({required this.frames, required this.duration});

  final int frames;
  final Duration duration;
}
