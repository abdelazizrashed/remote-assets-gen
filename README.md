# Remote Assets Gen

A code generator for your remote assets stored in AWS S3. It's a modification of the great `flutter_gen` package to support fetching assets from a remote source instead of local project assets.

This package generates type-safe classes for your assets, so you can use them in your Flutter app without using string paths.

## Features

*   **Type safety:** No more typos in asset paths.
*   **Remote assets:** Fetches assets directly from your AWS S3 bucket.
*   **Supports:**
    *   Images (png, jpg, jpeg, gif, webp, bmp, wbmp)
    *   SVG files (via `flutter_svg`)
    *   Lottie animations (via `lottie`)
*   **Auto-generation:** Generates asset classes automatically when you run the build command.

## Getting started

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  # Your other dependencies
  remote_assets_gen: <latest_version>

dev_dependencies:
  build_runner: <latest_version>
  remote_assets_gen: <latest_version>
```

Then run `flutter pub get`.

## Usage

Create a builder file (e.g., `tool/build.dart`) in your project's root directory:

```dart
import 'package:remote_assets_gen/remote_assets_generator.dart';

Future<void> main() async {
  final generator = RemoteAssetsGenerator(
    outputDir: "lib/gen/assets/", // [Optional]Y our desired output directory
    awsRegion: "us-east-1", // Your AWS region
    awsAccessKey: "YOUR_AWS_ACCESS_KEY", // IMPORTANT: Use a secure way to provide credentials
    awsSecretKey: "YOUR_AWS_SECRET_KEY", // IMPORTANT: Use a secure way to provide credentials
    awsBucketName: 'your-s3-bucket-name',
    flutterSvgIntegration: true, // Set to true if you use SVGs
    lottieIntegration: true, // Set to true if you use Lottie files
  );

  await generator.build();
}
```

**IMPORTANT SECURITY NOTE:** Do not hardcode your AWS credentials directly in your source code, especially if you are committing it to a public repository. Consider using environment variables or a secrets management solution to handle your credentials securely.

Then, run the builder to generate your asset classes:

```shell
dart run tool/build.dart
```

This will generate files in `lib/gen/assets/` (or your specified `outputDir`) which you can then use in your application.

For example, if you have an image `logo.png` in your S3 bucket, you can use it like this:

```dart
import 'package:flutter/material.dart';
import 'package:your_project/gen/assets/assets.gen.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.network(Assets.logo.url);
  }
}
```

## Additional information

This package is based on the great work of [flutter_gen](https://pub.dev/packages/flutter_gen). If you have any issues or feature requests, please file them on the project's GitHub repository.
