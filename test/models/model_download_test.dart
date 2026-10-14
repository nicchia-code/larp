import 'dart:async';
import 'dart:io';

import 'package:call_to_record/call/call_controller.dart';
import 'package:call_to_record/call/call_screen.dart';
import 'package:call_to_record/models/model_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

/// Local HTTP server answering every request with [handler].
Future<HttpServer> serve(Future<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

/// Answers HEAD with the size and GET with the body; unknown paths get 404.
Future<void> Function(HttpRequest) files(Map<String, List<int>> bodies) => (request) async {
  final body = bodies[request.uri.path];
  if (body == null) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }
  request.response.contentLength = body.length;
  if (request.method == 'GET') request.response.add(body);
  await request.response.close();
};

/// Announces a 3 MB file and sends 1 MB of it, then stalls.
Future<void> stallingFile(HttpRequest request) async {
  request.response.contentLength = 3000000;
  if (request.method == 'HEAD') {
    await request.response.close();
    return;
  }
  request.response.add(List.filled(1000000, 1));
  await request.response.flush();
}

void main() {
  late Directory dir;
  late HttpServer server;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() => dir = Directory.systemTemp.createTempSync('model_download_test_'));

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  List<ModelFile> modelsOn(HttpServer server, Map<String, int> sizes) => [
    for (final entry in sizes.entries)
      ModelFile(entry.key, 'http://127.0.0.1:${server.port}/${entry.key}', entry.value),
  ];

  CallController controllerWith(List<ModelFile> files) => CallController(
    missingSources: () async => [],
    capture: (_) async => throw UnimplementedError(),
    newFile: (_) async => File('${dir.path}/call.wav'),
    newDownloader: ({required onProgress}) =>
        ModelDownloader(files: files, dir: dir, onProgress: onProgress),
  );

  test('downloads every file and reports bytes out of the total', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1), '/b.tsv': List.filled(20, 2)}));
    final progress = <(int, int)>[];
    final downloader = ModelDownloader(
      files: modelsOn(server, {'a.onnx': 10, 'b.tsv': 20}),
      dir: dir,
      onProgress: (received, total) => progress.add((received, total)),
    );

    await downloader.run();

    expect(progress.first, (0, 30));
    expect(progress.last, (30, 30));
    expect(File('${dir.path}/a.onnx').lengthSync(), 10);
    expect(File('${dir.path}/b.tsv').lengthSync(), 20);
    expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.part')), isEmpty);
  });

  test('a failed file throws and discards what was downloaded', () async {
    final ok = files({'/a.onnx': List.filled(10, 1), '/b.onnx': List.filled(5, 1)});
    server = await serve((request) async {
      if (request.uri.path == '/b.onnx' && request.method == 'GET') {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      await ok(request);
    });
    final downloader = ModelDownloader(
      files: modelsOn(server, {'a.onnx': 10, 'b.onnx': 5}),
      dir: dir,
      onProgress: (_, _) {},
    );

    await expectLater(downloader.run(), throwsA(isA<HttpException>()));
    downloader.discard();

    expect(dir.listSync(), isEmpty);
  });

  test('Downloading moves to Ready at completion, with progress', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final controller = controllerWith(modelsOn(server, {'a.onnx': 10}));
    final states = <CallState>[];
    controller.addListener(() => states.add(controller.state));

    final download = controller.downloadModels();
    await download;

    expect(controller.state, CallState.ready);
    expect(states, containsAllInOrder([CallState.downloading, CallState.ready]));
    expect(controller.downloadReceived, 10);
    expect(controller.downloadTotal, 10);
    expect(File('${dir.path}/a.onnx').existsSync(), isTrue);
    controller.dispose();
  });

  test('a failed download moves to Download failed and discards the files', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final controller = controllerWith(modelsOn(server, {'a.onnx': 10, 'missing.onnx': 1}));

    await controller.downloadModels();

    expect(controller.state, CallState.downloadFailed);
    expect(controller.downloadError, 'Il download dei modelli non è riuscito. Controlla la connessione e riprova.');
    expect(dir.listSync(), isEmpty);
    controller.dispose();
  });

  test('closing the window during a download abandons it and discards the files', () async {
    server = await serve(stallingFile);
    final controller = controllerWith(modelsOn(server, {'a.onnx': 3000000}));

    final download = controller.downloadModels();
    while (controller.downloadReceived == 0) {
      await settle();
    }
    expect(controller.closeWindow(), isTrue);
    await download;

    expect(controller.state, CallState.closed);
    expect(dir.listSync(), isEmpty);
    controller.dispose();
  });

  testWidgets('the screen shows the download text, bar and MB of the total', (tester) async {
    server = (await tester.runAsync(() => serve(stallingFile)))!;
    final controller = controllerWith(modelsOn(server, {'a.onnx': 3000000}));
    await tester.pumpWidget(MaterialApp(home: CallScreen(controller: controller)));

    await tester.runAsync(() async {
      unawaited(controller.downloadModels());
      while (controller.downloadReceived < 1000000) {
        await settle();
      }
    });
    await tester.pump();

    expect(find.text('Download dei modelli…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('1.0 MB di 3.0 MB'), findsOneWidget);

    await tester.runAsync(() async => controller.closeWindow());
    controller.dispose();
  });

  test('Riprova restarts the download from zero and moves to Ready', () async {
    var failing = true;
    final ok = files({'/a.onnx': List.filled(10, 1), '/b.onnx': List.filled(5, 1)});
    server = await serve((request) async {
      if (failing && request.uri.path == '/b.onnx' && request.method == 'GET') {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      await ok(request);
    });
    final controller = controllerWith(modelsOn(server, {'a.onnx': 10, 'b.onnx': 5}));
    await controller.downloadModels();
    expect(controller.state, CallState.downloadFailed);

    failing = false;
    final retry = controller.retryDownload();
    expect(controller.state, CallState.downloading);
    expect(controller.downloadReceived, 0);
    await retry;

    expect(controller.state, CallState.ready);
    expect(File('${dir.path}/a.onnx').lengthSync(), 10);
    expect(File('${dir.path}/b.onnx').lengthSync(), 5);
    controller.dispose();
  });

  test('a retry that fails again keeps the complete files that were on disk', () async {
    File('${dir.path}/a.onnx').writeAsBytesSync(List.filled(10, 2));
    final ok = files({'/a.onnx': List.filled(10, 1), '/b.onnx': List.filled(5, 1)});
    server = await serve((request) async {
      if (request.uri.path == '/b.onnx' && request.method == 'GET') {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      await ok(request);
    });
    final controller = controllerWith(modelsOn(server, {'a.onnx': 10, 'b.onnx': 5}));
    await controller.downloadModels();
    await controller.retryDownload();

    expect(controller.state, CallState.downloadFailed);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['a.onnx']);
    expect(File('${dir.path}/a.onnx').readAsBytesSync(), List.filled(10, 2));
    controller.dispose();
  });

  testWidgets('a failed download shows the error and Riprova restarts it', (tester) async {
    var failing = true;
    final ok = files({'/a.onnx': List.filled(10, 1)});
    server = (await tester.runAsync(() => serve((request) async {
      if (failing && request.method == 'GET') {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      await ok(request);
    })))!;
    final controller = controllerWith(modelsOn(server, {'a.onnx': 10}));
    await tester.pumpWidget(MaterialApp(home: CallScreen(controller: controller)));

    await tester.runAsync(() => controller.downloadModels());
    await tester.pump();

    expect(find.text('Download fallito'), findsOneWidget);
    expect(find.text(controller.downloadError!), findsOneWidget);
    expect(find.text('Avvia'), findsNothing);

    failing = false;
    await tester.runAsync(() async {
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Riprova')).onPressed!();
      while (controller.state == CallState.downloading) {
        await settle();
      }
    });
    await tester.pump();

    expect(controller.state, CallState.ready);
    expect(find.text('Download fallito'), findsNothing);
    expect(find.text('Avvia'), findsOneWidget);
    controller.dispose();
  });

  test('a file of another size fails the download and is discarded', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final downloader = ModelDownloader(
      files: modelsOn(server, {'a.onnx': 9}),
      dir: dir,
      onProgress: (_, _) {},
    );

    await expectLater(downloader.run(), throwsA(isA<HttpException>()));
    downloader.discard();

    expect(dir.listSync(), isEmpty);
  });

  test('a failed download keeps the complete files that were on disk before it', () async {
    File('${dir.path}/a.onnx').writeAsBytesSync(List.filled(10, 1));
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final downloader = ModelDownloader(
      files: modelsOn(server, {'a.onnx': 10, 'b.tsv': 20}),
      dir: dir,
      onProgress: (_, _) {},
    );

    await expectLater(downloader.run(), throwsA(isA<HttpException>()));
    downloader.discard();

    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['a.onnx']);
  });

  test('a failed download leaves the complete files on disk as they were before it', () async {
    File('${dir.path}/a.onnx').writeAsBytesSync(List.filled(10, 2));
    final ok = files({'/a.onnx': List.filled(10, 1), '/b.tsv': List.filled(20, 1)});
    server = await serve((request) async {
      if (request.uri.path == '/b.tsv' && request.method == 'GET') {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      await ok(request);
    });
    final downloader = ModelDownloader(
      files: modelsOn(server, {'a.onnx': 10, 'b.tsv': 20}),
      dir: dir,
      onProgress: (_, _) {},
    );

    await expectLater(downloader.run(), throwsA(isA<HttpException>()));
    downloader.discard();

    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['a.onnx']);
    expect(File('${dir.path}/a.onnx').readAsBytesSync(), List.filled(10, 2));
  });

  test('a file without an expected size fails the download before fetching it', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final downloader = ModelDownloader(
      files: [ModelFile('a.onnx', 'http://127.0.0.1:${server.port}/a.onnx', null)],
      dir: dir,
      onProgress: (_, _) {},
    );

    await expectLater(downloader.run(), throwsA(isA<StateError>()));
  });

  test('the models are present only when every file has its expected size', () {
    File('${dir.path}/a.onnx').writeAsBytesSync(List.filled(10, 1));
    File('${dir.path}/b.onnx').writeAsBytesSync(List.filled(5, 1));
    const a = ModelFile('a.onnx', '', 10);
    const b = ModelFile('b.onnx', '', 5);

    expect(modelsComplete([a, b], dir), isTrue);
    expect(modelsComplete([a, b, const ModelFile('c.onnx', '', 1)], dir), isFalse);
    expect(modelsComplete([const ModelFile('a.onnx', '', 9)], dir), isFalse);
    expect(modelsComplete([const ModelFile('a.onnx', '', null)], dir), isFalse);
  });

  test('startup finds the models on disk and moves to Ready without downloading', () async {
    var downloads = 0;
    final controller = CallController(
      modelsPresent: () => true,
      newDownloader: ({required onProgress}) {
        downloads++;
        return ModelDownloader(files: const [], dir: dir, onProgress: onProgress);
      },
    );

    await controller.checkModels();

    expect(controller.state, CallState.ready);
    expect(downloads, 0);
    controller.dispose();
  });

  test('startup with missing models downloads them and moves to Ready', () async {
    server = await serve(files({'/a.onnx': List.filled(10, 1)}));
    final controller = CallController(
      modelsPresent: () => false,
      newDownloader: ({required onProgress}) => ModelDownloader(
        files: modelsOn(server, {'a.onnx': 10}),
        dir: dir,
        onProgress: onProgress,
      ),
    );

    await controller.checkModels();

    expect(controller.state, CallState.ready);
    expect(File('${dir.path}/a.onnx').lengthSync(), 10);
    controller.dispose();
  });
}
