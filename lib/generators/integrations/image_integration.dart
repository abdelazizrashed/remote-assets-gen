import 'integration.dart';
import 'package:remote_assets_gen/settings/asset_type.dart';
import 'package:remote_assets_gen/settings/import.dart';

/// The main image integration, supporting all image asset types. See
/// [isSupport] for the exact supported mime types.
///
/// This integration is by enabled by default.
class ImageIntegration extends Integration {
  ImageIntegration({required this.parseAnimation});

  final bool parseAnimation;

  @override
  List<Import> get requiredImports => const [
    Import('dart:io'),
    Import('package:flutter/material.dart'),
    Import("package:flutter_cache_manager/flutter_cache_manager.dart"),
  ];

  @override
  String get classOutput => _classDefinition;

  String get _classDefinition => '''
class RemoteAssetGenImage extends RemoteAssetProvider {
  RemoteAssetGenImage(
    super._assetUrl, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final Size? size;
  final Set<String> flavors;
  final RemoteAssetGenImageAnimation? animation;

  File? file;

  Widget image({
    Key? key,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,

    /// Widget displayed while the target [imageUrl] is loading.
    final Widget Function(BuildContext context, String url)?
    progressIndicatorBuilder,

    /// Widget displayed while the target [imageUrl] failed loading.
    final Widget Function(BuildContext context, String url, Object error)?
    errorWidgetBuilder,
  }) {
    return FutureBuilder(
      future: getFile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          file = snapshot.data;
          return Image.file(
            snapshot.data!,
            key: key,
            frameBuilder: frameBuilder,
            errorBuilder: errorBuilder,
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
            width: width,
            height: height,
            color: color,
            opacity: opacity,
            colorBlendMode: colorBlendMode,
            fit: fit,
            alignment: alignment,
            repeat: repeat,
            centerSlice: centerSlice,
            matchTextDirection: matchTextDirection,
            gaplessPlayback: gaplessPlayback,
            isAntiAlias: isAntiAlias,
            filterQuality: filterQuality,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
          );
        } else if (snapshot.hasError && errorWidgetBuilder != null) {
          return errorWidgetBuilder(context, _assetUrl, snapshot.error ?? '');
        } else if (progressIndicatorBuilder != null) {
          return progressIndicatorBuilder(context, _assetUrl);
        } else {
          return Container(width: width, height: height, color: Colors.grey);
        }
      },
    );
  }

  ImageProvider provider() {
    if (file != null) {
      return FileImage(file!);
    } else {
      return NetworkImage(_assetUrl);
    }
  }

  String get url => _assetUrl;

  String? get filePath => file?.path;
}

class RemoteAssetGenImageAnimation {
  const RemoteAssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
''';

  @override
  String get className => 'RemoteAssetGenImage';

  @override
  String classInstantiate({String? value, AssetType? asset}) {
    assert(value != null);
    final buffer = StringBuffer(className);
    buffer.write('(');
    buffer.write('\'$value\'');
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool isSupport(AssetType asset, String Function(String) urlConstructor) {
    /// Flutter official supported image types. See
    /// https://api.flutter.dev/flutter/widgets/Image-class.html
    switch (asset.mime) {
      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
      case 'image/bmp':
      case 'image/vnd.wap.wbmp':
      case 'image/webp':
        return true;
      default:
        return false;
    }
  }

  @override
  bool get isConstConstructor => false;
}
