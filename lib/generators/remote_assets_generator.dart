import 'dart:collection';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dartx/dartx.dart' hide IterableSorted;
import 'package:path/path.dart';
import 'package:remote_assets_gen/remote_assets_generator.dart';
import 'generator_helper.dart';
import 'integrations/image_integration.dart';
import 'integrations/integration.dart';
import 'integrations/lottie_integration.dart';
import 'integrations/svg_integration.dart';
import 'package:remote_assets_gen/settings/asset_type.dart';
import 'package:remote_assets_gen/settings/import.dart';
import 'package:remote_assets_gen/utils/string.dart';

Future<String> generateAssets(
  List<String> assetsPaths,
  String Function(String) urlConstructor,
  DartFormatter formatter,
  RemoteAssetsGenerator generator,
) async {
  final integrations = <Integration>[
    if (generator.imageIntegration) ImageIntegration(parseAnimation: false),
    if (generator.flutterSvgIntegration) SvgIntegration(),
    // if (config.flutterGen.integrations.rive)
    //   RiveIntegration(config.packageParameterLiteral),
    if (generator.lottieIntegration) LottieIntegration(),
  ];

  final classesBuffer = StringBuffer();
  final definition = _dotDelimiterStyleDefinition;
  final defRes = await definition(
    assetsPaths,
    urlConstructor,
    integrations,
    generator,
  );
  classesBuffer.writeln(defRes);

  final imports = <Import>{};
  for (final integration in integrations.where((e) => e.isEnabled)) {
    imports.addAll(integration.requiredImports);
    classesBuffer.writeln(integration.classOutput);
  }
  if (integrations.isNotEmpty) {
    classesBuffer.writeln(Integration.requiredHelperClasses);
  }

  final importsBuffer = StringBuffer();
  for (final e in imports.sorted((a, b) => a.import.compareTo(b.import))) {
    importsBuffer.writeln(import(e));
  }

  final buffer = StringBuffer();
  buffer.writeln('// dart format width=${formatter.pageWidth}\n');
  buffer.writeln(header);
  buffer.writeln(ignore);
  buffer.writeln(importsBuffer.toString());
  buffer.writeln(classesBuffer.toString());
  return formatter.format(buffer.toString());
}

/// Generate style like Assets.foo.bar
Future<String> _dotDelimiterStyleDefinition(
  List<String> assetsPaths,
  String Function(String) urlConstructor,
  List<Integration> integrations,
  RemoteAssetsGenerator generator,
) async {
  final rootPath = "/";
  final assetTypeQueue = ListQueue<AssetType>.from(
    _constructAssetTree(assetsPaths, "/").children,
  );

  final assetsStaticStatements = <_Statement>[];
  final buffer = StringBuffer();
  while (assetTypeQueue.isNotEmpty) {
    final assetType = assetTypeQueue.removeFirst();
    String assetPath = join(rootPath, assetType.path);
    final isDirectory = !assetType.path.contains(".");

    final isRootAsset =
        !isDirectory &&
        File(assetPath).parent.absolute.uri.toFilePath() == rootPath;
    // Handles directories, and explicitly handles root path assets.
    if (isDirectory || isRootAsset) {
      final List<_Statement?> results = await Future.wait(
        assetType.children
            .mapToUniqueAssetType(camelCase, justBasename: true)
            .map(
              (e) => _createAssetTypeStatement(e, urlConstructor, integrations),
            ),
      );
      final statements = results.whereType<_Statement>().toList();

      if (assetType.isDefaultAssetsDirectory) {
        assetsStaticStatements.addAll(statements);
      } else if (!isDirectory && isRootAsset) {
        // Creates explicit statement.
        final statement = await _createAssetTypeStatement(
          UniqueAssetType(assetType: assetType, style: camelCase),
          urlConstructor,
          integrations,
          true,
        );
        assetsStaticStatements.add(statement!);
      } else {
        final className = '\$${assetType.path.camelCase().capitalize()}Gen';
        String? directoryPath;
        buffer.writeln(
          _directoryClassGenDefinition(className, statements, directoryPath),
        );
        // Add this directory reference to Assets class
        // if we are not under the default asset folder
        if (dirname(assetType.path) == '.') {
          assetsStaticStatements.add(
            _Statement(
              type: className,
              filePath: assetType.posixStylePath,
              name: assetType.baseName.camelCase(),
              value: '$className()',
              isConstConstructor: false,
              isDirectory: true,
              needDartDoc: true,
            ),
          );
        }
      }

      assetTypeQueue.addAll(assetType.children);
    }
  }
  buffer.writeln(
    _dotDelimiterStyleAssetsClassDefinition(
      generator.className,
      assetsStaticStatements,
      null,
    ),
  );
  return buffer.toString();
}

String _dotDelimiterStyleAssetsClassDefinition(
  String className,
  List<_Statement> statements,
  String? packageName,
) {
  final statementsBlock = statements
      .map((statement) => statement.toStaticFieldString())
      .join('\n');
  final valuesBlock = _assetValuesDefinition(statements, static: true);

  return _assetsStaticClassDefinition(
    className,
    statements,
    statementsBlock,
    valuesBlock,
    packageName,
  );
}

String _assetValuesDefinition(
  List<_Statement> statements, {
  bool static = false,
}) {
  final values = statements.where((element) => !element.isDirectory);
  if (values.isEmpty) {
    return '';
  }
  final names = values.map((value) => value.name).join(', ');
  final type = values.every((element) => element.type == values.first.type)
      ? values.first.type
      : 'dynamic';

  return '''
  /// List of all assets
  ${static ? 'static ' : ''}List<$type> get values => [$names];''';
}

String _assetsStaticClassDefinition(
  String className,
  List<_Statement> statements,
  String statementsBlock,
  String valuesBlock,
  String? packageName,
) {
  return '''
class $className {
  const $className._();
${packageName != null ? "\n  static const String package = '$packageName';" : ''}

  $statementsBlock
  $valuesBlock
}
''';
}

AssetType _constructAssetTree(
  List<String> assetRelativePathList,
  String rootPath,
) {
  // Relative path is the key
  final assetTypeMap = <String, AssetType>{
    '.': AssetType(
      rootPath: rootPath,
      path: '.',
      flavors: {},
      transformers: {},
    ),
  };
  for (final asset in assetRelativePathList) {
    String path = asset;
    // Remove the trailing slash if it exists
    if (path.isNotEmpty && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    while (path != '.') {
      assetTypeMap.putIfAbsent(
        path,
        () => AssetType(
          rootPath: rootPath,
          path: path,
          flavors: {},
          transformers: {},
        ),
      );
      path = dirname(path);
    }
  }
  // Construct the AssetType tree
  for (final assetType in assetTypeMap.values) {
    if (assetType.path == '.') {
      continue;
    }
    final parentPath = dirname(assetType.path);
    assetTypeMap[parentPath]?.addChild(assetType);
  }
  return assetTypeMap['.']!;
}

class _Statement {
  const _Statement({
    required this.type,
    required this.filePath,
    required this.name,
    required this.value,
    required this.isConstConstructor,
    required this.isDirectory,
    required this.needDartDoc,
  });

  /// The type of this asset, e.g AssetGenImage, SvgGenImage, String, etc.
  final String type;

  /// The relative path of this asset from the root directory.
  final String filePath;

  /// The variable name of this asset.
  final String name;

  /// The code to instantiate this asset. e.g `AssetGenImage('assets/image.png');`
  final String value;

  final bool isConstConstructor;
  final bool isDirectory;
  final bool needDartDoc;

  String toDartDocString() => '/// File path: $filePath';

  String toGetterString() {
    final buffer = StringBuffer('');
    if (isDirectory) {
      buffer.writeln(
        '/// Directory path: '
        '${Directory(filePath).path.replaceAll(r'\', r'/')}',
      );
    }
    buffer.writeln(
      '$type get $name => ${isConstConstructor ? 'const' : ''} $value;',
    );
    return buffer.toString();
  }

  String toStaticFieldString() => 'static final $type $name = $value;';
}

Future<_Statement?> _createAssetTypeStatement(
  UniqueAssetType assetType,
  String Function(String) urlConstructor,
  List<Integration> integrations, [
  bool isDir = false,
]) async {
  final childAssetAbsolutePath = join("/", assetType.path);
  final isDirectory = !childAssetAbsolutePath.contains(".");
  if (isDirectory) {
    final childClassName = '\$${assetType.path.camelCase().capitalize()}Gen';
    return _Statement(
      type: childClassName,
      filePath: assetType.posixStylePath,
      name: assetType.name,
      value: '$childClassName()',
      isConstConstructor: true,
      isDirectory: true,
      needDartDoc: false,
    );
  } else if (!assetType.isIgnoreFile) {
    Integration? integration;
    for (final element in integrations) {
      final call = element.isSupport(assetType, urlConstructor);
      final bool isSupport;
      if (call is Future<bool>) {
        isSupport = await call;
      } else {
        isSupport = call;
      }
      if (isSupport) {
        integration = element;
        break;
      }
    }
    if (integration == null) {
      var assetKey = urlConstructor(assetType.posixStylePath);
      return _Statement(
        type: 'String',
        filePath: assetType.posixStylePath,
        name: assetType.name,
        value: '\'$assetKey\'',
        isConstConstructor: false,
        isDirectory: false,
        needDartDoc: true,
      );
    } else {
      integration.isEnabled = true;
      return _Statement(
        type: integration.className,
        filePath: assetType.posixStylePath,
        name: assetType.name,
        value: integration.classInstantiate(
          asset: assetType,
          value: urlConstructor(assetType.posixStylePath),
        ),
        isConstConstructor: false,
        isDirectory: false,
        needDartDoc: true,
      );
    }
  }
  return null;
}

String _directoryClassGenDefinition(
  String className,
  List<_Statement> statements,
  String? directoryPath,
) {
  final statementsBlock = statements
      .map((statement) {
        final buffer = StringBuffer();
        if (statement.needDartDoc) {
          buffer.writeln(statement.toDartDocString());
        }
        buffer.writeln(statement.toGetterString());
        return buffer.toString();
      })
      .join('\n');
  final pathBlock = directoryPath != null
      ? '''
  /// Directory path: $directoryPath
  String get path => '$directoryPath';
'''
      : '';
  final valuesBlock = _assetValuesDefinition(statements);

  return '''
class $className {
  const $className();
  
  $statementsBlock
  $pathBlock
  $valuesBlock
}
''';
}
