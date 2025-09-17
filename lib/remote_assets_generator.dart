import 'dart:io';

import 'package:aws_client/s3_2006_03_01.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:remote_assets_gen/generators/remote_assets_generator.dart';
import 'package:remote_assets_gen/utils/log.dart';

class RemoteAssetsGenerator {
  final String outputDir;
  final String className;
  final String fileName;
  final String awsAccessKey;
  final String awsSecretKey;
  final String awsRegion;
  final String awsBucketName;
  final bool imageIntegration;
  final bool flutterSvgIntegration;
  final bool lottieIntegration;
  RemoteAssetsGenerator({
    this.outputDir = "lib/gen/",
    this.className = "Assets",
    this.fileName = "assets.gen.dart",
    required this.awsAccessKey,
    required this.awsSecretKey,
    required this.awsRegion,
    required this.awsBucketName,
    this.imageIntegration = true,
    this.flutterSvgIntegration = false,
    this.lottieIntegration = false,
  });

  Future<void> build() async {
    log.onRecord.listen((record) {
      if (record.level >= Level.WARNING) {
        stderr.writeln(
          '[${record.loggerName}] [${record.level.name}] ${record.message}',
        );
      } else {
        stdout.writeln('[${record.loggerName}] ${record.message}');
      }
    });

    bool validateRequiredFields(String field, String fieldName) {
      if (field.isEmpty) {
        log.severe('Required field "$fieldName" is empty.');
        return false;
      }
      return true;
    }

    final isAccessKeyValid = validateRequiredFields(
      awsAccessKey,
      "awsAccessKey",
    );
    final isSecretKeyValid = validateRequiredFields(
      awsSecretKey,
      "awsSecretKey",
    );
    final isRegionValid = validateRequiredFields(awsRegion, "awsRegion");
    final isBucketValid = validateRequiredFields(
      awsBucketName,
      "awsBucketName",
    );
    if (!isAccessKeyValid ||
        !isSecretKeyValid ||
        !isRegionValid ||
        !isBucketValid) {
      return;
    }

    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
      // trailingCommas: config.formatterTrailingCommas,
      lineEnding: '\n',
    );

    void defaultWriter(String contents, String path) {
      final file = File(path);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      file.writeAsStringSync(contents);
    }

    final writer = defaultWriter;

    final absoluteOutput = Directory(normalize(join(".", outputDir)));
    if (!absoluteOutput.existsSync()) {
      absoluteOutput.createSync(recursive: true);
    }

    final api = S3(
      region: awsRegion,
      credentials: AwsClientCredentials(
        accessKey: awsAccessKey,
        secretKey: awsSecretKey,
      ),
    );
    final res = await api.listObjectsV2(bucket: awsBucketName);
    final files = res.contents ?? [];
    final filesPaths = files.map((f) => f.key!).toList();
    log.info("Found ${filesPaths.length} files.");
    String urlConstructor(String path) =>
        'https://$awsBucketName.s3.$awsRegion.amazonaws.com/$path';

    final generated = await generateAssets(
      filesPaths,
      urlConstructor,
      formatter,
      this,
    );
    final assetsPath = normalize(join(absoluteOutput.path, fileName));
    writer(generated, assetsPath);
    log.info('Generated: $assetsPath');

    log.info('Finished generating.');
  }
}
