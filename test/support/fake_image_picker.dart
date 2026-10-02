import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Content doesn't matter -- every AI call in these tests is itself faked --
/// only that `readAsBytes()` returns something. A tiny valid 1x1 PNG.
const _tinyPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// Stands in for the real `image_picker` plugin in widget tests: no real
/// camera/gallery UI exists in the test environment, so
/// `ImagePickerPlatform.instance` is swapped for this fake, which always
/// "picks" the same tiny real PNG file -- letting Food Scanner's and
/// Health Report Reader's actual photo -> `analyzeImage()` -> AI pipeline
/// run for real in a widget test, rather than only being exercisable by
/// typing directly into the description field.
class FakeImagePickerPlatform extends ImagePickerPlatform {
  int pickCount = 0;
  bool returnNull = false;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickCount++;
    if (returnNull) return null;
    // `XFile.fromData` carries its bytes in memory, so `readAsBytes()`
    // (what the real screens call) returns them directly with no
    // filesystem access at all -- deliberate, since plain `XFile(path)`
    // backed by a real file requires writing one first, and an async
    // `File.writeAsBytes`/`readAsBytes` call hangs forever under this
    // project's sandboxed test runner instead of erroring (confirmed by
    // isolating each step while diagnosing this fake).
    return XFile.fromData(
      Uint8List.fromList(_tinyPngBytes),
      mimeType: 'image/png',
      name: 'fake_photo_$pickCount.png',
    );
  }
}
