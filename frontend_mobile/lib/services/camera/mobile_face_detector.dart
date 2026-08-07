import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class FaceDetectionBox {
  final List<double> boundingBox; // [left, top, right, bottom] normalized (0.0 to 1.0)
  final double confidence;
  final List<List<double>>? landmarks; // 5-point facial landmarks

  FaceDetectionBox({
    required this.boundingBox,
    required this.confidence,
    this.landmarks,
  });
}

class FaceDetectionResult {
  final List<FaceDetectionBox> faces;
  final int frameWidth;
  final int frameHeight;
  final DateTime timestamp;
  final int processTimeMs;

  FaceDetectionResult({
    required this.faces,
    required this.frameWidth,
    required this.frameHeight,
    required this.timestamp,
    required this.processTimeMs,
  });
}

class MobileFaceDetector {
  static final MobileFaceDetector _instance = MobileFaceDetector._internal();
  factory MobileFaceDetector() => _instance;
  MobileFaceDetector._internal();

  static const String detectorModelPath = 'assets/models/det_500m.onnx';
  static bool _debugEnabled = false;

  OrtSession? _session;
  bool _isReady = false;

  bool get isReady => _isReady && _session != null;

  Future<bool> initialize() async {
    if (_isReady) return true;

    try {
      OrtEnv.instance.init();

      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(1);
      sessionOptions.setInterOpNumThreads(1);

      Uint8List modelBytes;
      try {
        final rawData = await rootBundle.load(detectorModelPath);
        modelBytes = rawData.buffer.asUint8List();
      } catch (_) {
        debugPrint('⚠️ Detector asset "$detectorModelPath" not found.');
        _isReady = true;
        return true;
      }

      if (modelBytes.isNotEmpty) {
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      }
      sessionOptions.release();

      _isReady = true;
      if (_debugEnabled) debugPrint('✅ [MobileFaceDetector] Face detector ready');
      return true;
    } catch (e) {
      debugPrint('⚠️ [MobileFaceDetector] Initialization failed: $e');
      _isReady = true;
      return true;
    }
  }

  Future<FaceDetectionResult> detectFaces({
    required Float32List detectorTensor,
    required int tensorSize,
    required double scaleRatio,
    required int padX,
    required int padY,
    required int originalWidth,
    required int originalHeight,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    final now = DateTime.now();

    if (!_isReady) {
      await initialize();
    }

    final detectedBoxes = <FaceDetectionBox>[];

    try {
      if (_session != null) {
        final inputShape = [1, 3, tensorSize, tensorSize];
        final inputTensor = OrtValueTensor.createTensorWithDataList(detectorTensor, inputShape);
        final inputName = _session!.inputNames.isNotEmpty ? _session!.inputNames[0] : 'input.1';

        final runOptions = OrtRunOptions();
        final outputs = _session!.run(runOptions, {inputName: inputTensor});
        runOptions.release();
        inputTensor.release();

        if (outputs.isNotEmpty && outputs.length >= 9) {
          final strides = [8, 16, 32];
          final List<_Candidate> candidates = [];

          for (int i = 0; i < strides.length; i++) {
            final stride = strides[i];
            final scoreList = outputs[i * 3]!.value as List;
            final bboxList = outputs[i * 3 + 1]!.value as List;
            final kpsList = outputs[i * 3 + 2]!.value as List;
            
            final gridH = tensorSize ~/ stride;
            final gridW = tensorSize ~/ stride;

            for (int iy = 0; iy < gridH; iy++) {
              for (int ix = 0; ix < gridW; ix++) {
                final anchorCx = ix * stride;
                final anchorCy = iy * stride;

                for (int a = 0; a < 2; a++) {
                  final idx = (iy * gridW + ix) * 2 + a;

                  // Output shapes: scores: [1, num_anchors, 1], bbox: [1, num_anchors, 4], kps: [1, num_anchors, 10]
                  final score = (scoreList[0][idx][0] as num).toDouble();
                  if (score > 0.5) {
                    final b0 = (bboxList[0][idx][0] as num).toDouble();
                    final b1 = (bboxList[0][idx][1] as num).toDouble();
                    final b2 = (bboxList[0][idx][2] as num).toDouble();
                    final b3 = (bboxList[0][idx][3] as num).toDouble();

                    final x1 = anchorCx - b0 * stride;
                    final y1 = anchorCy - b1 * stride;
                    final x2 = anchorCx + b2 * stride;
                    final y2 = anchorCy + b3 * stride;

                    final kps = <List<double>>[];
                    for (int k = 0; k < 5; k++) {
                      final kx = (kpsList[0][idx][k * 2] as num).toDouble();
                      final ky = (kpsList[0][idx][k * 2 + 1] as num).toDouble();
                      kps.add([anchorCx + kx * stride, anchorCy + ky * stride]);
                    }

                    candidates.add(_Candidate(score, x1, y1, x2, y2, kps));
                  }
                }
              }
            }
          }

          // Apply NMS
          candidates.sort((a, b) => b.score.compareTo(a.score));
          final kept = <_Candidate>[];

          for (final c in candidates) {
            bool suppress = false;
            for (final k in kept) {
              if (_iou(c, k) > 0.4) {
                suppress = true;
                break;
              }
            }
            if (!suppress) {
              kept.add(c);
            }
          }

          for (final c in kept) {
            // Unscale back to original
            final origX1 = (c.x1 - padX) / scaleRatio;
            final origY1 = (c.y1 - padY) / scaleRatio;
            final origX2 = (c.x2 - padX) / scaleRatio;
            final origY2 = (c.y2 - padY) / scaleRatio;

            // Normalize [0, 1] relative to original image size
            final normLeft = (origX1 / originalWidth).clamp(0.0, 1.0);
            final normTop = (origY1 / originalHeight).clamp(0.0, 1.0);
            final normRight = (origX2 / originalWidth).clamp(0.0, 1.0);
            final normBottom = (origY2 / originalHeight).clamp(0.0, 1.0);

            // Landmarks in original pixel coordinates
            final origKps = c.landmarks.map((kp) {
              final kpX = (kp[0] - padX) / scaleRatio;
              final kpY = (kp[1] - padY) / scaleRatio;
              return [kpX, kpY];
            }).toList();

            detectedBoxes.add(FaceDetectionBox(
              boundingBox: [normLeft, normTop, normRight, normBottom],
              confidence: c.score,
              landmarks: origKps,
            ));
          }
        }

        for (final out in outputs) {
          out?.release();
        }
      }
    } catch (e) {
      if (_debugEnabled) debugPrint('⚠️ [MobileFaceDetector] Detection warning: $e');
    }

    sw.stop();

    return FaceDetectionResult(
      faces: detectedBoxes,
      frameWidth: originalWidth,
      frameHeight: originalHeight,
      timestamp: now,
      processTimeMs: sw.elapsedMilliseconds,
    );
  }

  double _iou(_Candidate a, _Candidate b) {
    final interX1 = math.max(a.x1, b.x1);
    final interY1 = math.max(a.y1, b.y1);
    final interX2 = math.min(a.x2, b.x2);
    final interY2 = math.min(a.y2, b.y2);

    final interW = math.max(0.0, interX2 - interX1);
    final interH = math.max(0.0, interY2 - interY1);
    final interArea = interW * interH;

    if (interArea == 0.0) return 0.0;

    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);

    return interArea / (areaA + areaB - interArea);
  }

  Future<void> dispose() async {
    try {
      _session?.release();
      _session = null;
      _isReady = false;
    } catch (_) {}
  }
}

class _Candidate {
  final double score;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final List<List<double>> landmarks;

  _Candidate(this.score, this.x1, this.y1, this.x2, this.y2, this.landmarks);
}
