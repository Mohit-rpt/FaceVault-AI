// lib/services/local_recognition/model_loader.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

enum ModelLoaderState {
  uninitialized,
  loading,
  ready,
  failed,
}

/// Singleton Model Loader for managing ONNX Runtime inference sessions.
///
/// Responsibilities:
/// - Lazy loads the InsightFace ONNX recognition model (`buffalo_sc / w600k_mbf.onnx`)
/// - Configures CPU execution provider with 1-thread optimization for memory efficiency
/// - Verifies model integrity & manages lifecycle (initialize, status, dispose)
class ModelLoader {
  static final ModelLoader _instance = ModelLoader._internal();
  factory ModelLoader() => _instance;
  ModelLoader._internal();

  static const String defaultModelAssetPath = 'assets/models/w600k_mbf.onnx';

  OrtSession? _session;
  ModelLoaderState _state = ModelLoaderState.uninitialized;
  String? _lastError;

  ModelLoaderState get state => _state;
  bool get isReady => _state == ModelLoaderState.ready && _session != null;
  OrtSession? get session => _session;
  String? get lastError => _lastError;

  /// Lazy load ONNX model into memory session.
  Future<bool> initialize({String modelAssetPath = defaultModelAssetPath}) async {
    if (_state == ModelLoaderState.ready) return true;
    if (_state == ModelLoaderState.loading) return false;

    _state = ModelLoaderState.loading;
    _lastError = null;
    debugPrint('🧠 [ModelLoader] Loading ONNX model from: $modelAssetPath');

    try {
      // Initialize ONNX Runtime Environment
      OrtEnv.instance.init();

      // Configure Session Options (CPU 1-thread allocation for mobile RAM safety)
      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(1);
      sessionOptions.setInterOpNumThreads(1);

      // Load model bytes from Flutter root bundle asset or fallback bytes
      Uint8List modelBytes;
      try {
        final rawData = await rootBundle.load(modelAssetPath);
        modelBytes = rawData.buffer.asUint8List();
      } catch (_) {
        debugPrint('⚠️ Model asset "$modelAssetPath" not bundled; initializing session placeholder.');
        // Initialize empty session option fallback
        _state = ModelLoaderState.uninitialized;
        return false;
      }

      if (modelBytes.isEmpty) {
        throw Exception('Model file is empty or corrupted');
      }

      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      sessionOptions.release();

      _state = ModelLoaderState.ready;
      debugPrint('✅ [ModelLoader] ONNX model session ready');
      return true;
    } catch (e) {
      _state = ModelLoaderState.failed;
      _lastError = 'Model loading failed: $e';
      debugPrint('❌ [ModelLoader] Error: $_lastError');
      return false;
    }
  }

  /// Release model resources
  Future<void> dispose() async {
    try {
      _session?.release();
      _session = null;
      OrtEnv.instance.release();
      _state = ModelLoaderState.uninitialized;
      debugPrint('🧹 [ModelLoader] Resources released');
    } catch (e) {
      debugPrint('⚠️ [ModelLoader] Disposal warning: $e');
    }
  }
}
