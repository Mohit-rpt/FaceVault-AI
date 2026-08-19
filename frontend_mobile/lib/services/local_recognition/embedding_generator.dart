// lib/services/local_recognition/embedding_generator.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'model_loader.dart';

/// Generates 512-dimensional face embedding vectors via ONNX Runtime inference.
///
/// Responsibilities:
/// - Preprocesses aligned 112x112 face images into ONNX `[1, 3, 112, 112]` RGB float tensors
/// - Executes inference on `ModelLoader` session
/// - Applies L2 normalization: v = v / sqrt(sum(v_i^2))
/// - Returns 512-element Float32List embedding vector
class EmbeddingGenerator {
  static const int embeddingDim = 512;
  static const int inputWidth = 112;
  static const int inputHeight = 112;

  final ModelLoader loader;

  // Phase 6C Profiling Telemetry
  static int _benchmarkFrameCount = 0;
  static int _diagFrames = 0;
  
  static int _sumInputMicro = 0;
  static int _sumInfMicro = 0;
  static int _sumOutMicro = 0;
  static int _sumNormMicro = 0;
  static int _sumTotalMicro = 0;
  
  static int _maxInputMicro = 0;
  static int _maxInfMicro = 0;
  static int _maxOutMicro = 0;
  static int _maxNormMicro = 0;
  static int _maxTotalMicro = 0;
  
  static int _spikesInf100 = 0;
  static int _spikesTotal120 = 0;
  
  static final List<int> _inferenceHistory = [];
  
  static const int _benchmarkWarmupFrames = 30;
  static DateTime _lastSummaryTime = DateTime.fromMillisecondsSinceEpoch(0);

  EmbeddingGenerator({ModelLoader? loader}) : loader = loader ?? ModelLoader();

  /// Generate normalized 512-dim embedding vector from preprocessed float RGB tensor [1, 3, 112, 112].
  Future<Float32List?> generateFromTensor(Float32List tensorData) async {
    if (!loader.isReady || loader.session == null) {
      debugPrint('⚠️ [EmbeddingGenerator] Model session not ready');
      return null;
    }

    try {
      final totalSw = Stopwatch()..start();

      final inputShape = [1, 3, inputHeight, inputWidth];
      
      final inputSw = Stopwatch()..start();
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        tensorData,
        inputShape,
      );
      inputSw.stop();
      final inputMicro = inputSw.elapsedMicroseconds;

      final String inputName = loader.session!.inputNames.isNotEmpty
          ? loader.session!.inputNames[0]
          : 'input.1';
      final inputs = {inputName: inputTensor};
      final runOptions = OrtRunOptions();

      final infSw = Stopwatch()..start();
      final outputs = loader.session!.run(runOptions, inputs);
      infSw.stop();
      final infMicro = infSw.elapsedMicroseconds;
      
      runOptions.release();
      inputTensor.release();

      if (outputs.isEmpty || outputs[0] == null) {
        return null;
      }

      final outSw = Stopwatch()..start();
      final rawValue = outputs[0]!.value;
      outputs[0]!.release();

      List<double> rawFloats;
      if (rawValue is List) {
        rawFloats = rawValue.expand((e) => e is List ? e : [e]).cast<double>().toList();
      } else if (rawValue is Float32List) {
        rawFloats = rawValue.toList();
      } else {
        return null;
      }

      final Float32List emb = Float32List(embeddingDim);
      for (int i = 0; i < math.min(embeddingDim, rawFloats.length); i++) {
        emb[i] = rawFloats[i];
      }
      outSw.stop();
      final outMicro = outSw.elapsedMicroseconds;

      final normSw = Stopwatch()..start();
      final result = l2Normalize(emb);
      normSw.stop();
      final normMicro = normSw.elapsedMicroseconds;

      totalSw.stop();
      final totalMicro = totalSw.elapsedMicroseconds;

      // --- Phase 6C Telemetry ---
      _benchmarkFrameCount++;
      
      final infMs = infMicro ~/ 1000;
      final totalMs = totalMicro ~/ 1000;
      final inputMs = inputMicro ~/ 1000;
      final outMs = outMicro ~/ 1000;
      final normMs = normMicro ~/ 1000;

      // Diag (every frame)
      if (_benchmarkFrameCount % 10 == 0) {
        // Throttled just so we don't spam everything, but it logs individual executions
        debugPrint('[EMBED_STAGE_DIAG] config=B_INTRA2\n'
            'input_prepare=$inputMs\n'
            'inference=$infMs\n'
            'output_extract=$outMs\n'
            'normalize=$normMs\n'
            'total=$totalMs');
      }

      // Stall Detection
      if (infMs > 100 || totalMs > 120) {
        String bottleneck = 'unknown';
        if (infMs > 100) bottleneck = 'inference';
        else if (inputMs > 50) bottleneck = 'input_prepare';
        else if (outMs > 50) bottleneck = 'output_extract';
        else if (normMs > 50) bottleneck = 'normalize';
        else bottleneck = 'total_overhead';

        debugPrint('[EMBED_STAGE_STALL] config=B_INTRA2\n'
            'frame=unknown\n'
            'input_prepare=$inputMs\n'
            'inference=$infMs\n'
            'output_extract=$outMs\n'
            'normalize=$normMs\n'
            'total=$totalMs\n'
            'bottleneck=$bottleneck');
      }

      if (_benchmarkFrameCount > _benchmarkWarmupFrames) {
        _diagFrames++;
        _sumInputMicro += inputMicro;
        _sumInfMicro += infMicro;
        _sumOutMicro += outMicro;
        _sumNormMicro += normMicro;
        _sumTotalMicro += totalMicro;
        
        if (inputMicro > _maxInputMicro) _maxInputMicro = inputMicro;
        if (infMicro > _maxInfMicro) _maxInfMicro = infMicro;
        if (outMicro > _maxOutMicro) _maxOutMicro = outMicro;
        if (normMicro > _maxNormMicro) _maxNormMicro = normMicro;
        if (totalMicro > _maxTotalMicro) _maxTotalMicro = totalMicro;
        
        if (infMs > 100) _spikesInf100++;
        if (totalMs > 120) _spikesTotal120++;
        
        _inferenceHistory.add(infMicro);

        final now = DateTime.now();
        // Emit summary periodically (min 100 samples)
        if (_diagFrames >= 100 && now.difference(_lastSummaryTime).inMilliseconds >= 2000) {
          final sortedInf = List<int>.from(_inferenceHistory)..sort();
          final medianInfMicro = sortedInf[sortedInf.length ~/ 2];
          final p95InfMicro = sortedInf[(sortedInf.length * 0.95).floor()];

          final avgInput = (_sumInputMicro / _diagFrames / 1000.0).toStringAsFixed(2);
          final avgInf = (_sumInfMicro / _diagFrames / 1000.0).toStringAsFixed(1);
          final avgOut = (_sumOutMicro / _diagFrames / 1000.0).toStringAsFixed(2);
          final avgNorm = (_sumNormMicro / _diagFrames / 1000.0).toStringAsFixed(2);
          final avgTotal = (_sumTotalMicro / _diagFrames / 1000.0).toStringAsFixed(1);

          final medianInf = (medianInfMicro / 1000.0).toStringAsFixed(1);
          final p95Inf = (p95InfMicro / 1000.0).toStringAsFixed(1);

          final maxInputMs = _maxInputMicro ~/ 1000;
          final maxInfMs = _maxInfMicro ~/ 1000;
          final maxOutMs = _maxOutMicro ~/ 1000;
          final maxNormMs = _maxNormMicro ~/ 1000;
          final maxTotalMs = _maxTotalMicro ~/ 1000;

          debugPrint('[EMBED_STAGE_SUMMARY] config=B_INTRA2\n'
              'frames=$_diagFrames\n'
              'avg_input_prepare=$avgInput\n'
              'avg_inference=$avgInf\n'
              'avg_output_extract=$avgOut\n'
              'avg_normalize=$avgNorm\n'
              'avg_total=$avgTotal\n'
              'median_inference=$medianInf\n'
              'p95_inference=$p95Inf\n'
              'max_input_prepare=$maxInputMs\n'
              'max_inference=$maxInfMs\n'
              'max_output_extract=$maxOutMs\n'
              'max_normalize=$maxNormMs\n'
              'max_total=$maxTotalMs\n'
              'spikes_inference_over_100=$_spikesInf100\n'
              'spikes_total_over_120=$_spikesTotal120\n'
              'worst_frame=unknown');

          // Reset history after reporting to keep it fresh
          _inferenceHistory.clear();
          _diagFrames = 0;
          _sumInputMicro = 0;
          _sumInfMicro = 0;
          _sumOutMicro = 0;
          _sumNormMicro = 0;
          _sumTotalMicro = 0;
          _maxInputMicro = 0;
          _maxInfMicro = 0;
          _maxOutMicro = 0;
          _maxNormMicro = 0;
          _maxTotalMicro = 0;
          _spikesInf100 = 0;
          _spikesTotal120 = 0;
          _lastSummaryTime = now;
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ [EmbeddingGenerator] Inference error: $e');
      return null;
    }
  }

  /// Perform L2 normalization on embedding vector.
  static Float32List l2Normalize(Float32List vector) {
    double sumSq = 0.0;
    for (int i = 0; i < vector.length; i++) {
      sumSq += vector[i] * vector[i];
    }
    final double norm = math.sqrt(sumSq);
    if (norm == 0.0 || norm.isNaN) return vector;

    final Float32List normalized = Float32List(vector.length);
    for (int i = 0; i < vector.length; i++) {
      normalized[i] = vector[i] / norm;
    }
    return normalized;
  }

  /// Convert 112x112 RGB image bytes into normalized NCHW Float32List tensor.
  /// Preprocessing matches InsightFace buffalo_sc exact specification:
  /// (pixel - 127.5) / 127.5 in NCHW planar layout.
  static Float32List preprocessImageRgb(Uint8List rgbBytes, {int width = inputWidth, int height = inputHeight}) {
    final Float32List tensor = Float32List(1 * 3 * height * width);
    final int planeSize = height * width;

    if (rgbBytes.length < width * height * 3) {
      // Fallback synthetic pattern if raw bytes smaller
      for (int i = 0; i < tensor.length; i++) {
        tensor[i] = ((i % 256) - 127.5) / 127.5;
      }
      return tensor;
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int pixelIdx = (y * width + x) * 3;
        final int planeIdx = y * width + x;

        final double r = (rgbBytes[pixelIdx + 0] - 127.5) / 127.5;
        final double g = (rgbBytes[pixelIdx + 1] - 127.5) / 127.5;
        final double b = (rgbBytes[pixelIdx + 2] - 127.5) / 127.5;

        tensor[0 * planeSize + planeIdx] = r;
        tensor[1 * planeSize + planeIdx] = g;
        tensor[2 * planeSize + planeIdx] = b;
      }
    }

    return tensor;
  }
}
