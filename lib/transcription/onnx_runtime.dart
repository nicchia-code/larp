import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Minimal binding to the ONNX Runtime C API, for CPU sessions (Linux) and CoreML sessions (macOS).
///
/// The C API is reached through its function table (OrtApi of ONNX Runtime 1.31, ORT_API_VERSION 31);
/// each entry below is named with its index in onnxruntime_c_api.h.
const _apiVersion = 31;

// ONNXTensorElementDataType values.
const _tensorFloat = 1;
const _tensorInt64 = 7;
const _tensorBool = 9;

/// An error reported by ONNX Runtime, with its message.
class OnnxRuntimeException implements Exception {
  OnnxRuntimeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A tensor passed to a session: [shape] is its dimensions and the data is row-major.
class OnnxTensor {
  OnnxTensor._(this._type, this.shape, this._data);

  OnnxTensor.float(List<int> shape, Float32List data) : this._(_tensorFloat, shape, data);

  OnnxTensor.int64(List<int> shape, Int64List data) : this._(_tensorInt64, shape, data);

  OnnxTensor.bool(List<int> shape, Uint8List data) : this._(_tensorBool, shape, data);

  final int _type;
  final List<int> shape;
  final TypedData _data;

  Uint8List get _bytes => _data.buffer.asUint8List(_data.offsetInBytes, _data.lengthInBytes);
}

typedef _GetApiBaseN = Pointer<Void> Function();
typedef _GetApiBase = Pointer<Void> Function();
typedef _GetApiN = Pointer<Void> Function(Uint32);
typedef _GetApi = Pointer<Void> Function(int);

typedef _ReleaseN = Void Function(Pointer<Void>);
typedef _Release = void Function(Pointer<Void>);
typedef _ErrorMessageN = Pointer<Utf8> Function(Pointer<Void>);
typedef _ErrorMessage = Pointer<Utf8> Function(Pointer<Void>);
typedef _CreateEnvN = Pointer<Void> Function(Int32, Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _CreateEnv = Pointer<Void> Function(int, Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _OutN = Pointer<Void> Function(Pointer<Pointer<Void>>);
typedef _Out = Pointer<Void> Function(Pointer<Pointer<Void>>);
typedef _CreateSessionN =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _CreateSession =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _AppendProviderN =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Utf8>>,
      Size,
    );
typedef _AppendProvider =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Utf8>>,
      int,
    );
typedef _CreateCpuMemoryInfoN = Pointer<Void> Function(Int32, Int32, Pointer<Pointer<Void>>);
typedef _CreateCpuMemoryInfo = Pointer<Void> Function(int, int, Pointer<Pointer<Void>>);
typedef _CreateTensorN =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Size,
      Pointer<Int64>,
      Size,
      Int32,
      Pointer<Pointer<Void>>,
    );
typedef _CreateTensor =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<Int64>,
      int,
      int,
      Pointer<Pointer<Void>>,
    );
typedef _RunN =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Void>>,
      Size,
      Pointer<Pointer<Utf8>>,
      Size,
      Pointer<Pointer<Void>>,
    );
typedef _Run =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Void>>,
      int,
      Pointer<Pointer<Utf8>>,
      int,
      Pointer<Pointer<Void>>,
    );
typedef _ValueOutN = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _ValueOut = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _ElementCountN = Pointer<Void> Function(Pointer<Void>, Pointer<Size>);
typedef _ElementCount = Pointer<Void> Function(Pointer<Void>, Pointer<Size>);

/// The functions of the C API used here, read from the function table.
final class _Api {
  _Api(Pointer<Pointer<Void>> table)
    :
      getErrorMessage = table[2].cast<NativeFunction<_ErrorMessageN>>().asFunction<_ErrorMessage>(),
      createEnv = table[3].cast<NativeFunction<_CreateEnvN>>().asFunction<_CreateEnv>(),
      createSession = table[7].cast<NativeFunction<_CreateSessionN>>().asFunction<_CreateSession>(),
      run = table[9].cast<NativeFunction<_RunN>>().asFunction<_Run>(),
      createSessionOptions = table[10].cast<NativeFunction<_OutN>>().asFunction<_Out>(),
      createTensor = table[49].cast<NativeFunction<_CreateTensorN>>().asFunction<_CreateTensor>(),
      getTensorMutableData = table[51].cast<NativeFunction<_ValueOutN>>().asFunction<_ValueOut>(),
      getTensorShapeElementCount =
          table[64].cast<NativeFunction<_ElementCountN>>().asFunction<_ElementCount>(),
      getTensorTypeAndShape = table[65].cast<NativeFunction<_ValueOutN>>().asFunction<_ValueOut>(),
      createCpuMemoryInfo =
          table[69].cast<NativeFunction<_CreateCpuMemoryInfoN>>().asFunction<_CreateCpuMemoryInfo>(),
      appendProvider =
          table[216].cast<NativeFunction<_AppendProviderN>>().asFunction<_AppendProvider>(),
      releaseEnv = table[92].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseStatus = table[93].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseMemoryInfo = table[94].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseSession = table[95].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseValue = table[96].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseTensorTypeAndShapeInfo =
          table[99].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>(),
      releaseSessionOptions = table[100].cast<NativeFunction<_ReleaseN>>().asFunction<_Release>();

  final _ErrorMessage getErrorMessage;
  final _CreateEnv createEnv;
  final _CreateSession createSession;
  final _Run run;
  final _Out createSessionOptions;
  final _CreateTensor createTensor;
  final _ValueOut getTensorMutableData;
  final _ElementCount getTensorShapeElementCount;
  final _ValueOut getTensorTypeAndShape;
  final _CreateCpuMemoryInfo createCpuMemoryInfo;
  final _AppendProvider appendProvider;
  final _Release releaseEnv;
  final _Release releaseStatus;
  final _Release releaseMemoryInfo;
  final _Release releaseSession;
  final _Release releaseValue;
  final _Release releaseTensorTypeAndShapeInfo;
  final _Release releaseSessionOptions;

  /// Throws the message of [status] and releases it; a null status means success.
  void check(Pointer<Void> status) {
    if (status == nullptr) return;
    final message = getErrorMessage(status).toDartString();
    releaseStatus(status);
    throw OnnxRuntimeException(message);
  }
}

/// ONNX Runtime loaded once, with its environment and CPU memory description.
class OnnxRuntime {
  OnnxRuntime._(this._api, this._env, this._memoryInfo);

  /// Loads the library at [libraryPath] and creates its environment.
  static OnnxRuntime open(String libraryPath) {
    final library = DynamicLibrary.open(libraryPath);
    final base = library.lookupFunction<_GetApiBaseN, _GetApiBase>('OrtGetApiBase')();
    final getApi = base.cast<Pointer<NativeFunction<_GetApiN>>>().value.asFunction<_GetApi>();
    final table = getApi(_apiVersion);
    if (table == nullptr) {
      throw OnnxRuntimeException(
        'La libreria $libraryPath non supporta la versione $_apiVersion dell\'API di ONNX Runtime',
      );
    }
    final api = _Api(table.cast());
    final env = calloc<Pointer<Void>>();
    final memoryInfo = calloc<Pointer<Void>>();
    final name = 'CallToRecord'.toNativeUtf8();
    try {
      api.check(api.createEnv(3, name, env));
      api.check(api.createCpuMemoryInfo(1, 0, memoryInfo));
      return OnnxRuntime._(api, env.value, memoryInfo.value);
    } finally {
      calloc.free(name);
      calloc.free(env);
      calloc.free(memoryInfo);
    }
  }

  final _Api _api;
  final Pointer<Void> _env;
  final Pointer<Void> _memoryInfo;

  /// Opens the ONNX model at [modelPath], on CoreML when [coreMl] is set and on the CPU otherwise.
  OnnxSession openSession(String modelPath, {required bool coreMl}) {
    final options = calloc<Pointer<Void>>();
    final session = calloc<Pointer<Void>>();
    final path = modelPath.toNativeUtf8();
    try {
      _api.check(_api.createSessionOptions(options));
      if (coreMl) {
        final provider = 'CoreML'.toNativeUtf8();
        try {
          _api.check(_api.appendProvider(options.value, provider, nullptr, nullptr, 0));
        } finally {
          calloc.free(provider);
        }
      }
      _api.check(_api.createSession(_env, path, options.value, session));
      return OnnxSession._(this, session.value);
    } finally {
      if (options.value != nullptr) _api.releaseSessionOptions(options.value);
      calloc.free(path);
      calloc.free(options);
      calloc.free(session);
    }
  }

  /// Releases the environment. Close the sessions first.
  void close() {
    _api.releaseMemoryInfo(_memoryInfo);
    _api.releaseEnv(_env);
  }
}

/// A loaded model: [run] feeds it tensors and reads one float output.
class OnnxSession {
  OnnxSession._(this._runtime, this._session);

  final OnnxRuntime _runtime;
  final Pointer<Void> _session;

  /// Runs the model on [inputs] and returns the float values of [output].
  Float32List run(Map<String, OnnxTensor> inputs, String output) {
    final api = _runtime._api;
    final names = inputs.keys.toList(growable: false);
    final inputNames = calloc<Pointer<Utf8>>(names.length);
    final inputValues = calloc<Pointer<Void>>(names.length);
    final outputNames = calloc<Pointer<Utf8>>(1);
    final outputValues = calloc<Pointer<Void>>(1);
    final strings = <Pointer<Utf8>>[];
    final buffers = <Pointer<Void>>[];
    final values = <Pointer<Void>>[];
    try {
      for (var i = 0; i < names.length; i++) {
        inputNames[i] = names[i].toNativeUtf8();
        strings.add(inputNames[i]);
        inputValues[i] = _createValue(inputs[names[i]]!, buffers);
        values.add(inputValues[i]);
      }
      outputNames[0] = output.toNativeUtf8();
      strings.add(outputNames[0]);
      api.check(
        api.run(_session, nullptr, inputNames, inputValues, names.length, outputNames, 1, outputValues),
      );
      values.add(outputValues[0]);
      return _readFloats(outputValues[0]);
    } finally {
      for (final value in values) {
        api.releaseValue(value);
      }
      for (final pointer in strings) {
        calloc.free(pointer);
      }
      for (final buffer in buffers) {
        calloc.free(buffer);
      }
      calloc.free(inputNames);
      calloc.free(inputValues);
      calloc.free(outputNames);
      calloc.free(outputValues);
    }
  }

  /// Releases the session.
  void close() => _runtime._api.releaseSession(_session);

  // Copies [tensor] into native memory and wraps it in an OrtValue; [buffers] collects the memory to free.
  Pointer<Void> _createValue(OnnxTensor tensor, List<Pointer<Void>> buffers) {
    final bytes = tensor._bytes;
    final data = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    buffers.add(data.cast());
    data.asTypedList(bytes.length).setAll(0, bytes);
    final shape = calloc<Int64>(tensor.shape.length);
    buffers.add(shape.cast());
    for (var i = 0; i < tensor.shape.length; i++) {
      shape[i] = tensor.shape[i];
    }
    final out = calloc<Pointer<Void>>();
    try {
      _runtime._api.check(
        _runtime._api.createTensor(
          _runtime._memoryInfo,
          data.cast(),
          bytes.length,
          shape,
          tensor.shape.length,
          tensor._type,
          out,
        ),
      );
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  Float32List _readFloats(Pointer<Void> value) {
    final api = _runtime._api;
    final info = calloc<Pointer<Void>>();
    final count = calloc<Size>();
    final data = calloc<Pointer<Void>>();
    try {
      api.check(api.getTensorTypeAndShape(value, info));
      try {
        api.check(api.getTensorShapeElementCount(info.value, count));
      } finally {
        api.releaseTensorTypeAndShapeInfo(info.value);
      }
      api.check(api.getTensorMutableData(value, data));
      return Float32List.fromList(data.value.cast<Float>().asTypedList(count.value));
    } finally {
      calloc.free(info);
      calloc.free(count);
      calloc.free(data);
    }
  }
}
