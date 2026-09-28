import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('gallery_saver');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  MethodCall? lastCall;

  setUp(() {
    lastCall = null;
    messenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      lastCall = methodCall;
      switch (methodCall.method) {
        case 'saveImage':
          return true;
        case 'saveVideo':
          return false;
      }
      return 'unknown method';
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('save image', () async {
    expect(await GallerySaver.saveImage('/storage/emulated/image.jpg'), true);
  });

  test('save video', () async {
    expect(await GallerySaver.saveVideo('/storage/emulated/video.mov'), false);
  });

  test('forwards video filename and creation date', () async {
    final createdAt = DateTime.utc(2026, 1, 12, 16, 45);

    expect(
      await GallerySaver.saveVideo(
        '/storage/emulated/video.mov',
        albumName: 'Guardy',
        fileName: 'Guardy recording',
        creationDate: createdAt,
      ),
      false,
    );
    expect(lastCall?.method, 'saveVideo');
    expect(lastCall?.arguments, containsPair('fileName', 'Guardy recording'));
    expect(lastCall?.arguments,
        containsPair('creationDate', createdAt.millisecondsSinceEpoch));
  });
}
