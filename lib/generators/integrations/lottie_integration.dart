import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'integration.dart';
import 'package:remote_assets_gen/settings/asset_type.dart';
import 'package:remote_assets_gen/settings/import.dart';
import 'package:remote_assets_gen/utils/log.dart';

class LottieIntegration extends Integration {
  LottieIntegration() : super();

  // These are required keys for this integration.
  static const lottieKeys = [
    'w', // width
    'h', // height
    'ip', // The frame at which the Lottie animation starts at
    'op', // The frame at which the Lottie animation ends at
    'fr', // frame rate
    'v', // // Must include version
    'layers', // Must include layers
  ];

  static const _supportedMimeTypes = ['application/json', 'application/zip'];

  @override
  List<Import> get requiredImports => const [
    Import('package:flutter/widgets.dart'),
    Import('package:lottie/lottie.dart', alias: '_lottie'),
  ];

  @override
  String get classOutput => _classDefinition;

  String get _classDefinition => '''
class RemoteLottieGenImage extends RemoteAssetProvider {
  RemoteLottieGenImage(super._assetUrl, {this.flavors = const {}});

  final Set<String> flavors;

  File? file;

  Widget lottie({
    Animation<double>? controller,
    bool? animate,
    _lottie.FrameRate? frameRate,
    bool? repeat,
    bool? reverse,
    _lottie.LottieDelegates? delegates,
    _lottie.LottieOptions? options,
    void Function(_lottie.LottieComposition)? onLoaded,
    _lottie.LottieImageProviderFactory? imageProviderFactory,
    Key? key,
    AssetBundle? bundle,
    Widget Function(BuildContext, Widget, _lottie.LottieComposition?)?
    frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    double? width,
    double? height,
    BoxFit? fit,
    AlignmentGeometry? alignment,
    String? package,
    bool? addRepaintBoundary,
    FilterQuality? filterQuality,
    void Function(String)? onWarning,
    _lottie.LottieDecoder? decoder,
    _lottie.RenderCache? renderCache,
    bool? backgroundLoading,

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
          return _lottie.Lottie.file(
            file!,
            controller: controller,
            animate: animate,
            frameRate: frameRate,
            repeat: repeat,
            reverse: reverse,
            delegates: delegates,
            options: options,
            onLoaded: onLoaded,
            imageProviderFactory: imageProviderFactory,
            key: key,
            frameBuilder: frameBuilder,
            errorBuilder: errorBuilder,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            addRepaintBoundary: addRepaintBoundary,
            filterQuality: filterQuality,
            onWarning: onWarning,
            decoder: decoder,
            renderCache: renderCache,
            backgroundLoading: backgroundLoading,
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
      ''';

  @override
  String get className => 'RemoteLottieGenImage';

  @override
  Future<bool> isSupport(
    AssetType asset,
    String Function(String) urlConstructor,
  ) async => await isLottieFile(asset, urlConstructor);

  @override
  bool get isConstConstructor => true;

  Future<bool> isLottieFile(
    AssetType asset,
    String Function(String) urlConstructor,
  ) async {
    if (asset.extension == '.lottie' || asset.extension == '.tgs') {
      return true;
    }
    if (!_supportedMimeTypes.contains(asset.mime)) {
      return false;
    }
    final url = urlConstructor(asset.posixStylePath);
    try {
      final response = await HttpClient().getUrl(Uri.parse(url));
      // get [File] object from response
      final file = await response.close();

      if (file.statusCode != HttpStatus.ok) {
        return false;
      }

      final content = await file.transform(utf8.decoder).join();
      return _isValidJsonFile(asset, overrideInput: content);
    } catch (e, t) {
      log.warning('Lottie JSON file is not valid.', e, t);
      return false;
    }
  }

  bool _isValidJsonFile(AssetType type, {String? overrideInput}) {
    try {
      final String input;
      if (overrideInput != null) {
        input = overrideInput;
      } else {
        final absolutePath = p.join(type.rootPath, type.path);
        input = File(absolutePath).readAsStringSync();
      }
      final fileKeys = jsonDecode(input) as Map<String, dynamic>;
      if (lottieKeys.every(fileKeys.containsKey) && fileKeys['v'] != null) {
        var version = Version.parse(fileKeys['v']);
        // Lottie version 4.4.0 is the first version that supports BodyMovin.
        // https://github.com/xvrh/lottie-flutter/blob/0e7499d82ea1370b6acf023af570395bbb59b42f/lib/src/parser/lottie_composition_parser.dart#L60
        return version >= Version(4, 4, 0);
      }
    } on FormatException catch (_) {
      // Catches bad/corrupted json and reports it to user.
      // log.warning('Lottie JSON file is not valid.', e, s);
      // no-op
    } on TypeError catch (_) {
      // Catches bad/corrupted json and reports it to user.
      // log.warning('Lottie JSON file has invalid type.', e, s);
      // no-op
    }
    return false;
  }
}
