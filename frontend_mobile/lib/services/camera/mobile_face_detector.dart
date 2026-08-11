import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class FaceDetectionBox {
  final List<double> boundingBox; // [left, top, right, bottom] normalized 0.0-1.0
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

  OrtSession? _session;
  bool _isReady = false;

  final double _confidenceThreshold = 0.45;
  final double _nmsThreshold = 0.4;

  // Output mapping: index -> (stride, head)
  Map<int, _OutputMapping>? _outputMappings;

  // Throttled logging
  DateTime _lastDiagTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _diagIntervalMs = 1000;

  bool get isReady => _isReady && _session != null;

  Future<bool> initialize() async {
    if (_isReady && _session != null) return true;

    try {
      // Note: OrtEnv.instance.init() must be called BEFORE this, 
      // either here or in the caller Isolate.
      if (!PlatformDispatcher.instance.views.isEmpty) {
        OrtEnv.instance.init(); // Init safely if on UI isolate
      }

      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setInterOpNumThreads(1);

      Uint8List modelBytes;
      try {
        final rawData = await rootBundle.load(detectorModelPath);
        // CRITICAL: Use correct ByteData offset/length to avoid corrupted model
        modelBytes = rawData.buffer.asUint8List(
          rawData.offsetInBytes,
          rawData.lengthInBytes,
        );
        debugPrint('[SCRFD_INIT] Model loaded: ${modelBytes.length} bytes (offset=${rawData.offsetInBytes}, length=${rawData.lengthInBytes})');
      } catch (e) {
        debugPrint('⚠️ [SCRFD_INIT] Asset "$detectorModelPath" not found: $e');
        return false;
      }

      if (modelBytes.isNotEmpty) {
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      }
      sessionOptions.release();

      if (_session == null) {
        debugPrint('⚠️ [SCRFD_INIT] Session creation failed');
        return false;
      }

      _isReady = true;

      // One-time initialization log
      debugPrint('✅ [SCRFD_INIT] Face detector ready');
      for (int i = 0; i < _session!.inputNames.length; i++) {
        debugPrint('[SCRFD_INIT] INPUT #$i: name=${_session!.inputNames[i]}');
      }
      for (int i = 0; i < _session!.outputNames.length; i++) {
        debugPrint('[SCRFD_INIT] OUTPUT #$i: name=${_session!.outputNames[i]}');
      }

      // Build output mapping from names
      _buildOutputMappingFromNames();

      return true;
    } catch (e) {
      debugPrint('⚠️ [SCRFD_INIT] Initialization failed: $e');
      _isReady = false;
      return false;
    }
  }

  Future<bool> initializeFromBytes(Uint8List modelBytes) async {
    if (_isReady && _session != null) return true;

    try {
      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setInterOpNumThreads(1);

      if (modelBytes.isNotEmpty) {
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      }
      sessionOptions.release();

      if (_session == null) {
        debugPrint('⚠️ [SCRFD_INIT] Session creation failed');
        return false;
      }

      _isReady = true;
      _buildOutputMappingFromNames();
      return true;
    } catch (e) {
      debugPrint('⚠️ [SCRFD_INIT] Initialization failed: $e');
      _isReady = false;
      return false;
    }
  }

  void _buildOutputMappingFromNames() {
    if (_session == null) return;
    final names = _session!.outputNames;
    _outputMappings = {};

    // EXACT ONNX GRAPH OUTPUT ORDER FOR det_500m.onnx
    // The graph outputs are grouped by HEAD, not by STRIDE.
    // 0 = score8
    // 1 = score16
    // 2 = score32
    // 3 = bbox8
    // 4 = bbox16
    // 5 = bbox32
    // 6 = kps8
    // 7 = kps16
    // 8 = kps32

    final strictMapping = [
      _OutputMapping(stride: 8, head: 'score', outputName: names.length > 0 ? names[0] : '443'),
      _OutputMapping(stride: 16, head: 'score', outputName: names.length > 1 ? names[1] : '468'),
      _OutputMapping(stride: 32, head: 'score', outputName: names.length > 2 ? names[2] : '493'),
      _OutputMapping(stride: 8, head: 'bbox', outputName: names.length > 3 ? names[3] : '446'),
      _OutputMapping(stride: 16, head: 'bbox', outputName: names.length > 4 ? names[4] : '471'),
      _OutputMapping(stride: 32, head: 'bbox', outputName: names.length > 5 ? names[5] : '496'),
      _OutputMapping(stride: 8, head: 'kps', outputName: names.length > 6 ? names[6] : '449'),
      _OutputMapping(stride: 16, head: 'kps', outputName: names.length > 7 ? names[7] : '474'),
      _OutputMapping(stride: 32, head: 'kps', outputName: names.length > 8 ? names[8] : '499'),
    ];

    for (int i = 0; i < strictMapping.length; i++) {
      _outputMappings![i] = strictMapping[i];
    }

    debugPrint('[SCRFD_MAPPING] Hardcoded true ONNX graph mapping:');
    _outputMappings?.forEach((i, m) {
      debugPrint('[SCRFD_MAPPING] #$i "${m.outputName}" -> stride${m.stride} ${m.head.toUpperCase()}');
    });
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

    if (!_isReady || _session == null) {
      await initialize();
    }

    final detectedBoxes = <FaceDetectionBox>[];
    final bool shouldLog = now.difference(_lastDiagTime).inMilliseconds >= _diagIntervalMs;
    if (shouldLog) _lastDiagTime = now;

    try {
      if (_session != null) {
        if (shouldLog) {
        debugPrint('[SCRFD_INPUT_SCHEMA] modelInput=[1,3,640,640] tensorLength=${detectorTensor.length} cameraWidth=$originalWidth cameraHeight=$originalHeight padX=$padX padY=$padY scale=$scaleRatio');
      }

      if (detectorTensor.length != 1228800) {
        debugPrint('❌ [SCRFD_FATAL] Detector tensor length must be exactly 1228800 (640x640x3). Got ${detectorTensor.length}. Aborting inference.');
        return FaceDetectionResult(
          faces: [],
          frameWidth: originalWidth,
          frameHeight: originalHeight,
          timestamp: DateTime.now(),
          processTimeMs: sw.elapsedMilliseconds,
        );
      }

      final inputShape = [1, 3, tensorSize, tensorSize];
        final inputTensor = OrtValueTensor.createTensorWithDataList(detectorTensor, inputShape);
        final inputName = _session!.inputNames.isNotEmpty ? _session!.inputNames[0] : 'input.1';

        final runOptions = OrtRunOptions();
        final outputs = _session!.run(runOptions, {inputName: inputTensor});
        runOptions.release();
        inputTensor.release();

        if (outputs.isNotEmpty && outputs.length >= 9) {
          if (_outputMappings == null || _outputMappings!.isEmpty) {
            _buildOutputMappingFromNames();
          }

          final Map<int, Map<String, List<double>>> strideOutputs = {
            8: {}, 16: {}, 32: {},
          };

          for (int i = 0; i < outputs.length && i < 9; i++) {
            final out = outputs[i];
            if (out == null || out.value == null) continue;
            
            final flatData = _flattenToList(out.value);
            final mapping = _outputMappings?[i];
            
            if (mapping != null) {
              if (shouldLog) {
                debugPrint('[SCRFD_OUTPUT_SCHEMA] index=$i name=${mapping.outputName} mappedTo=stride${mapping.stride}_${mapping.head} flattenedLength=${flatData.length}');
              }
              strideOutputs[mapping.stride]![mapping.head] = flatData;
            }
          }

          double maxProbability = 0.0;
          int totalCandidates = 0;
          int thresholdedCount = 0;
          final List<_Candidate> candidates = [];
          final strides = [8, 16, 32];
          bool printedAnchorSchema = false;
          bool printedBBoxDebug = false;

          for (final stride in strides) {
            final maps = strideOutputs[stride]!;
            final scoreFlat = maps['score'];
            final bboxFlat = maps['bbox'];
            final kpsFlat = maps['kps'];
            if (scoreFlat == null || bboxFlat == null || kpsFlat == null) {
              if (shouldLog) debugPrint('[SCRFD] WARNING: stride $stride missing data');
              continue;
            }

            final gridH = tensorSize ~/ stride;
            final gridW = tensorSize ~/ stride;

            if (!printedAnchorSchema) {
              debugPrint('[SCRFD_ANCHOR_SCHEMA] stride=$stride featureMap=${gridW}x$gridH anchorsPerLocation=2 totalAnchors=${gridW*gridH*2} firstCenter=[0,0] lastCenter=[${(gridW-1)*stride},${(gridH-1)*stride}]');
            }

            // Optional: check score bounds once
            if (!printedAnchorSchema) {
              double minScore = 999;
              double maxScore = -999;
              double sumScore = 0;
              for (final s in scoreFlat) {
                if (s < minScore) minScore = s;
                if (s > maxScore) maxScore = s;
                sumScore += s;
              }
              debugPrint('[SCRFD_SCORE_SCHEMA] stride=$stride min=$minScore max=$maxScore mean=${sumScore / scoreFlat.length}');
            }

            for (int iy = 0; iy < gridH; iy++) {
              for (int ix = 0; ix < gridW; ix++) {
                final anchorCx = ix * stride;
                final anchorCy = iy * stride;
                for (int a = 0; a < 2; a++) {
                  final idx = (iy * gridW + ix) * 2 + a;
                  final rawScore = scoreFlat[idx];
                  
                  // The det_500m.onnx already has Sigmoid outputs. 
                  // DO NOT apply another sigmoid.
                  final double prob = rawScore;

                  if (prob < 0.0 || prob > 1.0) {
                     debugPrint('❌ [SCRFD_FATAL_INVALID_SCORE] rawScore/prob is $prob. Output tensor is likely misaligned! Expected 0.0 to 1.0.');
                     return FaceDetectionResult(
                        faces: [],
                        frameWidth: originalWidth,
                        frameHeight: originalHeight,
                        timestamp: DateTime.now(),
                        processTimeMs: sw.elapsedMilliseconds,
                      );
                  }

                  if (prob > maxProbability) maxProbability = prob;

                  if (prob > _confidenceThreshold) {
                    thresholdedCount++;

                    final b0 = bboxFlat[idx * 4 + 0];
                    final b1 = bboxFlat[idx * 4 + 1];
                    final b2 = bboxFlat[idx * 4 + 2];
                    final b3 = bboxFlat[idx * 4 + 3];

                    final x1 = anchorCx - b0 * stride;
                    final y1 = anchorCy - b1 * stride;
                    final x2 = anchorCx + b2 * stride;
                    final y2 = anchorCy + b3 * stride;

                    if (!printedBBoxDebug && thresholdedCount <= 5) {
                      debugPrint('[SCRFD_BBOX_DEBUG] stride=$stride anchorIndex=$idx anchorCx=$anchorCx anchorCy=$anchorCy rawBBox=[$b0,$b1,$b2,$b3] decoded=[$x1,$y1,$x2,$y2]');
                    }

                    // Reject invalid boxes
                    if (x2 <= x1 || y2 <= y1 ||
                        x1.isNaN || y1.isNaN || x2.isNaN || y2.isNaN ||
                        x1.isInfinite || y1.isInfinite || x2.isInfinite || y2.isInfinite) {
                      continue;
                    }

                    final kps = <List<double>>[];
                    if (idx * 10 + 9 < kpsFlat.length) {
                      for (int k = 0; k < 5; k++) {
                        final kx = kpsFlat[idx * 10 + k * 2];
                        final ky = kpsFlat[idx * 10 + k * 2 + 1];
                        kps.add([anchorCx + kx * stride, anchorCy + ky * stride]);
                      }
                    }
                    candidates.add(_Candidate(prob, x1, y1, x2, y2, kps));
                  }
                }
              }
            }
            if (!printedAnchorSchema && stride == 32) printedAnchorSchema = true;
            if (!printedBBoxDebug && thresholdedCount >= 5) printedBBoxDebug = true;
          }

          final candidatesBeforeNMS = candidates.length;

          // NMS
          candidates.sort((a, b) => b.score.compareTo(a.score));
          final kept = <_Candidate>[];
          for (final c in candidates) {
            bool suppress = false;
            for (final k in kept) {
              if (_iou(c, k) > _nmsThreshold) { suppress = true; break; }
            }
            if (!suppress) {
              kept.add(c);
            }
          }
          final candidatesAfterNMS = kept.length;

          if (shouldLog) {
            debugPrint('[SCRFD_NMS] before=$candidatesBeforeNMS after=$candidatesAfterNMS threshold=$_confidenceThreshold maxIoU=0.4');
          }

          if (candidatesAfterNMS > 50) {
            debugPrint('[SCRFD_ANOMALY] rawCandidates=$candidatesAfterNMS reason=unexpected_detection_explosion');
            return FaceDetectionResult(
               faces: [],
               frameWidth: originalWidth,
               frameHeight: originalHeight,
               timestamp: DateTime.now(),
               processTimeMs: sw.elapsedMilliseconds,
             );
          }

          // Convert to normalized coordinates
          for (final c in kept) {
            final origX1 = (c.x1 - padX) / scaleRatio;
            final origY1 = (c.y1 - padY) / scaleRatio;
            final origX2 = (c.x2 - padX) / scaleRatio;
            final origY2 = (c.y2 - padY) / scaleRatio;

            final normLeft = (origX1 / originalWidth).clamp(0.0, 1.0);
            final normTop = (origY1 / originalHeight).clamp(0.0, 1.0);
            final normRight = (origX2 / originalWidth).clamp(0.0, 1.0);
            final normBottom = (origY2 / originalHeight).clamp(0.0, 1.0);

            if (normRight - normLeft < 0.01 || normBottom - normTop < 0.01) continue;

            final normKps = c.landmarks.map((kp) {
              final kpX = ((kp[0] - padX) / scaleRatio) / originalWidth;
              final kpY = ((kp[1] - padY) / scaleRatio) / originalHeight;
              return [kpX.clamp(0.0, 1.0), kpY.clamp(0.0, 1.0)];
            }).toList();

            detectedBoxes.add(FaceDetectionBox(
              boundingBox: [normLeft, normTop, normRight, normBottom],
              confidence: c.score,
              landmarks: normKps,
            ));

            // Log one valid candidate for bbox validation
            if (shouldLog && detectedBoxes.length == 1) {
              debugPrint('[SCRFD_BBOX] stride=${c.x1 < 160 ? "?" : "?"} score=${c.score.toStringAsFixed(3)} raw=[${c.x1.toStringAsFixed(1)},${c.y1.toStringAsFixed(1)},${c.x2.toStringAsFixed(1)},${c.y2.toStringAsFixed(1)}] norm=[${normLeft.toStringAsFixed(3)},${normTop.toStringAsFixed(3)},${normRight.toStringAsFixed(3)},${normBottom.toStringAsFixed(3)}]');
            }
          }

          // Throttled diagnostic
          if (shouldLog) {
            debugPrint('[SCRFD] probMax=${maxProbability.toStringAsFixed(4)} candidates=$totalCandidates thresh=$thresholdedCount nms=${kept.length} faces=${detectedBoxes.length}');
          }
        } else if (shouldLog) {
          debugPrint('[SCRFD] WARNING: expected >=9 outputs, got ${outputs.length}');
        }

        for (final out in outputs) {
          out?.release();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SCRFD] Detection error: $e');
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

  List<double> _flattenToList(dynamic rawVal) {
    if (rawVal is Float32List) return rawVal;
    if (rawVal is List) {
      final result = <double>[];
      void extract(dynamic item) {
        if (item is num) {
          result.add(item.toDouble());
        } else if (item is List) {
          for (final sub in item) { extract(sub); }
        }
      }
      extract(rawVal);
      return result;
    }
    return [];
  }

  double _iou(_Candidate a, _Candidate b) {
    final ix1 = math.max(a.x1, b.x1);
    final iy1 = math.max(a.y1, b.y1);
    final ix2 = math.min(a.x2, b.x2);
    final iy2 = math.min(a.y2, b.y2);
    final iw = math.max(0.0, ix2 - ix1);
    final ih = math.max(0.0, iy2 - iy1);
    final inter = iw * ih;
    if (inter == 0.0) return 0.0;
    final aA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final aB = (b.x2 - b.x1) * (b.y2 - b.y1);
    return inter / (aA + aB - inter);
  }

  Future<void> dispose() async {
    try {
      _session?.release();
      _session = null;
      _isReady = false;
    } catch (_) {}
  }
}

class _OutputMapping {
  final int stride;
  final String head;
  final String outputName;
  _OutputMapping({required this.stride, required this.head, required this.outputName});
}

class _Candidate {
  final double score;
  final double x1, y1, x2, y2;
  final List<List<double>> landmarks;
  _Candidate(this.score, this.x1, this.y1, this.x2, this.y2, this.landmarks);
}
