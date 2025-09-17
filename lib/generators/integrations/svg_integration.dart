import 'integration.dart';
import 'package:remote_assets_gen/settings/asset_type.dart';
import 'package:remote_assets_gen/settings/import.dart';

class SvgIntegration extends Integration {
  SvgIntegration() : super();

  @override
  List<Import> get requiredImports => const [
    Import('package:flutter/widgets.dart'),
    Import('package:flutter/services.dart'),
    Import('package:flutter_svg/flutter_svg.dart', alias: '_svg'),
    Import('package:vector_graphics/vector_graphics.dart', alias: '_vg'),
  ];

  @override
  String get classOutput => _classDefinition;

  String get _classDefinition => '''
class RemoteSvgGenImage extends RemoteAssetProvider {
  RemoteSvgGenImage(super._assetUrl, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  RemoteSvgGenImage.vec(super._assetUrl, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;
  File? file;

  Widget svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,

    /// Widget displayed while the target [imageUrl] is loading.
    final Widget Function(BuildContext context, String url)?
    progressIndicatorBuilder,

    /// Widget displayed while the target [imageUrl] failed loading.
    final Widget Function(BuildContext context, String url, Object error)?
    errorWidgetBuilder,

    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    return FutureBuilder(
      future: getFile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          file = snapshot.data;
          final _svg.BytesLoader loader;
          if (_isVecFormat) {
            loader = FileBytesLoading(file!);
          } else {
            loader = _svg.SvgFileLoader(
              file!,
              theme: theme,
              colorMapper: colorMapper,
            );
          }
          return _svg.SvgPicture(
            loader,
            key: key,
            matchTextDirection: matchTextDirection,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
            placeholderBuilder: placeholderBuilder,
            semanticsLabel: semanticsLabel,
            excludeFromSemantics: excludeFromSemantics,
            colorFilter:
                colorFilter ??
                (color == null
                    ? null
                    : ColorFilter.mode(color, colorBlendMode)),
            clipBehavior: clipBehavior,
            cacheColorFilter: cacheColorFilter,
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

  String get url => _assetUrl;

  String? get filePath => file?.path;
}

class FileBytesLoading extends _vg.BytesLoader {
  const FileBytesLoading(this.file);

  final File file;
  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    final fBytes = await file.readAsBytes();
    return fBytes.buffer.asByteData();
  }
}
      ''';

  @override
  String get className => 'RemoteSvgGenImage';

  static const vectorCompileTransformer = 'vector_graphics_compiler';

  @override
  String classInstantiate({AssetType? asset, String? value}) {
    assert(asset != null && value != null);
    // Query extra information about the SVG.
    final buffer = StringBuffer(className);
    if (asset!.extension == '.vec' ||
        asset.transformers.contains(vectorCompileTransformer)) {
      buffer.write('.vec');
    }
    buffer.write('(');
    buffer.write('\'$value\'');
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool isSupport(AssetType asset, String Function(String) urlConstructor) =>
      asset.mime == 'image/svg+xml' || asset.extension == '.vec';

  @override
  bool get isConstConstructor => true;
}
