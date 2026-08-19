import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'mobile_face_detector.dart';

class ExperimentalSCRFDDetector {
  static final ExperimentalSCRFDDetector _instance =
      ExperimentalSCRFDDetector._internal();
  factory ExperimentalSCRFDDetector() => _instance;
  ExperimentalSCRFDDetector._internal();

  // Reusable lists to prevent per-frame allocations
  final List<_Candidate> _reusableCandidates = [];
  final List<_Candidate> _reusableKept = [];

  static const String detectorModelPath = 'assets/models/det_500m_320.onnx';

  OrtSession? _session;
  OrtRunOptions? _runOptions;
  bool _isReady = false;

  final double _confidenceThreshold = 0.45;
  final double _nmsThreshold = 0.4;

  // Output mapping: index -> (stride, head)
  Map<int, _OutputMapping>? _outputMappings;

  // Throttled logging
  DateTime _lastDiagTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _diagIntervalMs = 1000;

  // Phase 3 SCRFD Stage Profiling
  static DateTime _lastStageDiagTime = DateTime.fromMillisecondsSinceEpoch(0);
  static int _stageFrames = 0;
  static int _stageSumInput = 0;
  static int _stageSumInf = 0;
  static int _stageSumOut = 0;
  static int _stageSumDec = 0;
  static int _stageSumNms = 0;
  static int _stageSumTotal = 0;
  static int _stageMaxInput = 0;
  static int _stageMaxInf = 0;
  static int _stageMaxTotal = 0;
  static int _stageWorstFrame = -1;

  // Phase 7 Spike Root-Cause Profiling
  static const int _benchmarkWarmupFrames = 30; // Ignore first 30 frames
  static int _benchmarkFrameCount = 0;
  static int _diagFrames = 0;

  static int _sumWorkerToDetect = 0;
  static int _sumDetectToRun = 0;
  static int _sumOnnxInference = 0;
  static int _sumRunToPostprocess = 0;
  static int _sumScrfdTotal = 0;

  static int _maxWorkerToDetect = 0;
  static int _maxDetectToRun = 0;
  static int _maxOnnxInference = 0;
  static int _maxRunToPostprocess = 0;
  static int _maxScrfdTotal = 0;

  static int _spikesOnnx80 = 0;
  static int _spikesOnnx100 = 0;
  static int _spikesTotal100 = 0;

  static final List<int> _inferenceHistory = [];
  static DateTime _lastSummaryTime = DateTime.fromMillisecondsSinceEpoch(0);

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
      sessionOptions.setIntraOpNumThreads(1);
      sessionOptions.setInterOpNumThreads(1);
      sessionOptions.setSessionGraphOptimizationLevel(
          GraphOptimizationLevel.ortEnableAll);

      debugPrint(
          '[SCRFD_SMALL_INIT] SCRFD_CONFIG=A_INTRA1 model=det_500m_320.onnx input=320x320 provider=CPU threads_intra=1 threads_inter=1 graph_optimization=ORT_ENABLE_ALL');

      Uint8List modelBytes;
      try {
        final rawData = await rootBundle.load(detectorModelPath);
        // CRITICAL: Use correct ByteData offset/length to avoid corrupted model
        modelBytes = rawData.buffer.asUint8List(
          rawData.offsetInBytes,
          rawData.lengthInBytes,
        );
        debugPrint(
            '[SCRFD_SMALL_INIT] Model loaded: ${modelBytes.length} bytes (offset=${rawData.offsetInBytes}, length=${rawData.lengthInBytes})');
      } catch (e) {
        debugPrint(
            '⚠️ [SCRFD_SMALL_INIT] Asset "$detectorModelPath" not found: $e');
        return false;
      }

      if (modelBytes.isNotEmpty) {
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      }
      sessionOptions.release();

      if (_session == null) {
        debugPrint('⚠️ [SCRFD_SMALL_INIT] Session creation failed');
        return false;
      }

      _runOptions = OrtRunOptions();
      _isReady = true;

      // One-time initialization log
      debugPrint('✅ [SCRFD_SMALL_INIT] Face detector ready');
      for (int i = 0; i < _session!.inputNames.length; i++) {
        debugPrint(
            '[SCRFD_SMALL_INIT] INPUT #$i: name=${_session!.inputNames[i]}');
      }
      for (int i = 0; i < _session!.outputNames.length; i++) {
        debugPrint(
            '[SCRFD_SMALL_INIT] OUTPUT #$i: name=${_session!.outputNames[i]}');
      }

      // Build output mapping from names
      _buildOutputMappingFromNames();

      return true;
    } catch (e) {
      debugPrint('⚠️ [SCRFD_SMALL_INIT] Initialization failed: $e');
      _isReady = false;
      return false;
    }
  }

  Future<bool> initializeFromBytes(Uint8List modelBytes) async {
    if (_isReady && _session != null) return true;

    try {
      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(1);
      sessionOptions.setInterOpNumThreads(1);
      sessionOptions.setSessionGraphOptimizationLevel(
          GraphOptimizationLevel.ortEnableAll);

      debugPrint(
          '[SCRFD_SMALL_INIT] SCRFD_CONFIG=A_INTRA1 model=det_500m_320.onnx input=320x320 provider=CPU threads_intra=1 threads_inter=1 graph_optimization=ORT_ENABLE_ALL');

      if (modelBytes.isNotEmpty) {
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      }
      sessionOptions.release();

      if (_session == null) {
        debugPrint('⚠️ [SCRFD_SMALL_INIT] Session creation failed');
        return false;
      }

      _runOptions = OrtRunOptions();
      _isReady = true;
      _buildOutputMappingFromNames();
      return true;
    } catch (e) {
      debugPrint('⚠️ [SCRFD_SMALL_INIT] Initialization failed: $e');
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
      _OutputMapping(
          stride: 8,
          head: 'score',
          outputName: names.length > 0 ? names[0] : '443'),
      _OutputMapping(
          stride: 16,
          head: 'score',
          outputName: names.length > 1 ? names[1] : '468'),
      _OutputMapping(
          stride: 32,
          head: 'score',
          outputName: names.length > 2 ? names[2] : '493'),
      _OutputMapping(
          stride: 8,
          head: 'bbox',
          outputName: names.length > 3 ? names[3] : '446'),
      _OutputMapping(
          stride: 16,
          head: 'bbox',
          outputName: names.length > 4 ? names[4] : '471'),
      _OutputMapping(
          stride: 32,
          head: 'bbox',
          outputName: names.length > 5 ? names[5] : '496'),
      _OutputMapping(
          stride: 8,
          head: 'kps',
          outputName: names.length > 6 ? names[6] : '449'),
      _OutputMapping(
          stride: 16,
          head: 'kps',
          outputName: names.length > 7 ? names[7] : '474'),
      _OutputMapping(
          stride: 32,
          head: 'kps',
          outputName: names.length > 8 ? names[8] : '499'),
    ];

    for (int i = 0; i < strictMapping.length; i++) {
      _outputMappings![i] = strictMapping[i];
    }

    debugPrint('[SCRFD_MAPPING] Hardcoded true ONNX graph mapping:');
    _outputMappings?.forEach((i, m) {
      debugPrint(
          '[SCRFD_MAPPING] #$i "${m.outputName}" -> stride${m.stride} ${m.head.toUpperCase()}');
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
    int frameId = -1,
    int workerDelayMicro = 0,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    final now = DateTime.now();

    if (!_isReady || _session == null || _runOptions == null) {
      await initialize();
    }

    final detectedBoxes = <FaceDetectionBox>[];
    final bool shouldLog =
        now.difference(_lastDiagTime).inMilliseconds >= _diagIntervalMs;
    if (shouldLog) _lastDiagTime = now;

    try {
      if (_session != null) {
        if (shouldLog) {
          debugPrint(
              '[SCRFD_SMALL_INPUT_SCHEMA] modelInput=[1,3,$tensorSize,$tensorSize] tensorLength=${detectorTensor.length} cameraWidth=$originalWidth cameraHeight=$originalHeight padX=$padX padY=$padY scale=$scaleRatio');
        }

        if (detectorTensor.length != 307200) {
          debugPrint(
              '❌ [SCRFD_SMALL_FATAL] Detector tensor length must be exactly 307200 (320x320x3). Got ${detectorTensor.length}. Aborting inference.');
          return FaceDetectionResult(
            faces: [],
            frameWidth: originalWidth,
            frameHeight: originalHeight,
            timestamp: DateTime.now(),
            processTimeMs: sw.elapsedMilliseconds,
          );
        }

        final inputShape = [1, 3, tensorSize, tensorSize];

        final allocSw = Stopwatch()..start();
        final inputTensor =
            OrtValueTensor.createTensorWithDataList(detectorTensor, inputShape);
        allocSw.stop();
        final allocMs = allocSw.elapsedMilliseconds;

        final inputName = _session!.inputNames.isNotEmpty
            ? _session!.inputNames[0]
            : 'input.1';

        final int runStartMicro = sw.elapsedMicroseconds;

        final infSw = Stopwatch()..start();
        final outputs = _session!.run(_runOptions!, {inputName: inputTensor});
        infSw.stop();
        final infMs = infSw.elapsedMilliseconds;
        final infMicro = infSw.elapsedMicroseconds;

        inputTensor.release();

        int outputMs = 0;
        int decodeMs = 0;
        int nmsMs = 0;
        int releaseMs = 0;

        if (outputs.isNotEmpty && outputs.length >= 9) {
          if (_outputMappings == null || _outputMappings!.isEmpty) {
            _buildOutputMappingFromNames();
          }

          final Map<int, Map<String, List<double>>> strideOutputs = {
            8: {},
            16: {},
            32: {},
          };

          final outSw = Stopwatch()..start();
          for (int i = 0; i < outputs.length && i < 9; i++) {
            final out = outputs[i];
            if (out == null) continue;

            List<double> flatData;
            if (out is OrtValueTensor) {
              flatData = out.flatFloat32List;
            } else {
              if (out.value == null) continue;
              flatData = _flattenToList(out.value);
            }

            final mapping = _outputMappings?[i];

            if (mapping != null) {
              if (shouldLog) {
                debugPrint(
                    '[SCRFD_OUTPUT_SCHEMA] index=$i name=${mapping.outputName} mappedTo=stride${mapping.stride}_${mapping.head} flattenedLength=${flatData.length}');
              }
              strideOutputs[mapping.stride]![mapping.head] = flatData;
            }
          }
          outSw.stop();
          outputMs = outSw.elapsedMilliseconds;

          double maxProbability = 0.0;
          int totalCandidates = 0;
          int thresholdedCount = 0;
          
          _reusableCandidates.clear();
          
          final strides = [8, 16, 32];
          bool printedAnchorSchema = false;
          bool printedBBoxDebug = false;

          final decodeSw = Stopwatch()..start();
          for (final stride in strides) {
            final maps = strideOutputs[stride]!;
            final scoreFlat = maps['score'];
            final bboxFlat = maps['bbox'];
            final kpsFlat = maps['kps'];
            if (scoreFlat == null || bboxFlat == null || kpsFlat == null) {
              if (shouldLog)
                debugPrint('[SCRFD] WARNING: stride $stride missing data');
              continue;
            }

            final gridH = tensorSize ~/ stride;
            final gridW = tensorSize ~/ stride;

            if (!printedAnchorSchema) {
              debugPrint(
                  '[SCRFD_ANCHOR_SCHEMA] stride=$stride featureMap=${gridW}x$gridH anchorsPerLocation=2 totalAnchors=${gridW * gridH * 2} firstCenter=[0,0] lastCenter=[${(gridW - 1) * stride},${(gridH - 1) * stride}]');
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
              debugPrint(
                  '[SCRFD_SCORE_SCHEMA] stride=$stride min=$minScore max=$maxScore mean=${sumScore / scoreFlat.length}');
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
                    debugPrint(
                        '❌ [SCRFD_FATAL_INVALID_SCORE] rawScore/prob is $prob. Output tensor is likely misaligned! Expected 0.0 to 1.0.');
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
                      debugPrint(
                          '[SCRFD_BBOX_DEBUG] stride=$stride anchorIndex=$idx anchorCx=$anchorCx anchorCy=$anchorCy rawBBox=[$b0,$b1,$b2,$b3] decoded=[$x1,$y1,$x2,$y2]');
                    }

                    // Reject invalid boxes
                    if (x2 <= x1 ||
                        y2 <= y1 ||
                        x1.isNaN ||
                        y1.isNaN ||
                        x2.isNaN ||
                        y2.isNaN ||
                        x1.isInfinite ||
                        y1.isInfinite ||
                        x2.isInfinite ||
                        y2.isInfinite) {
                      continue;
                    }

                    final kps = <List<double>>[];
                    if (idx * 10 + 9 < kpsFlat.length) {
                      for (int k = 0; k < 5; k++) {
                        final kx = kpsFlat[idx * 10 + k * 2];
                        final ky = kpsFlat[idx * 10 + k * 2 + 1];
                        kps.add(
                            [anchorCx + kx * stride, anchorCy + ky * stride]);
                      }
                    }
                    _reusableCandidates.add(_Candidate(prob, x1, y1, x2, y2, kps));
                  }
                }
              }
            }
            if (!printedAnchorSchema && stride == 32)
              printedAnchorSchema = true;
            if (!printedBBoxDebug && thresholdedCount >= 5)
              printedBBoxDebug = true;
          }

          decodeSw.stop();
          decodeMs = decodeSw.elapsedMilliseconds;

          final candidatesBeforeNMS = _reusableCandidates.length;

          // NMS
          final nmsSw = Stopwatch()..start();
          _reusableCandidates.sort((a, b) => b.score.compareTo(a.score));
          _reusableKept.clear();
          
          for (final c in _reusableCandidates) {
            bool suppress = false;
            for (final k in _reusableKept) {
              if (_iou(c, k) > _nmsThreshold) {
                suppress = true;
                break;
              }
            }
            if (!suppress) {
              _reusableKept.add(c);
            }
          }
          nmsSw.stop();
          nmsMs = nmsSw.elapsedMilliseconds;
          final candidatesAfterNMS = _reusableKept.length;

          final int totalMs = sw.elapsedMilliseconds;

          if (shouldLog) {
            debugPrint(
                '[SCRFD_NMS] before=$candidatesBeforeNMS after=$candidatesAfterNMS threshold=$_confidenceThreshold maxIoU=0.4');
            debugPrint(
                '[SCRFD_STAGE_DIAG] frame=$frameId input_prepare=$allocMs inference=$infMs output=$outputMs decode=$decodeMs nms=$nmsMs total=$totalMs');
          }

          // SCRFD_STAGE_DIAG Accumulation
          _stageFrames++;
          _stageSumInput += allocMs;
          _stageSumInf += infMs;
          _stageSumOut += outputMs;
          _stageSumDec += decodeMs;
          _stageSumNms += nmsMs;
          _stageSumTotal += totalMs;

          if (allocMs > _stageMaxInput) _stageMaxInput = allocMs;
          if (infMs > _stageMaxInf) _stageMaxInf = infMs;
          if (totalMs > _stageMaxTotal) {
            _stageMaxTotal = totalMs;
            _stageWorstFrame = frameId;
          }

          // SCRFD_STAGE_STALL check
          if (infMs > 100 || totalMs > 120 || allocMs > 30) {
            debugPrint('[SCRFD_STAGE_STALL] frameId=$frameId input_prepare=$allocMs inference=$infMs output=$outputMs decode=$decodeMs nms=$nmsMs total=$totalMs');
          }

          // SCRFD_STAGE_SUMMARY
          if (shouldLog && _stageFrames >= 10) {
            final int avgInput = _stageFrames > 0 ? _stageSumInput ~/ _stageFrames : 0;
            final int avgInf = _stageFrames > 0 ? _stageSumInf ~/ _stageFrames : 0;
            final int avgOut = _stageFrames > 0 ? _stageSumOut ~/ _stageFrames : 0;
            final int avgDec = _stageFrames > 0 ? _stageSumDec ~/ _stageFrames : 0;
            final int avgNms = _stageFrames > 0 ? _stageSumNms ~/ _stageFrames : 0;
            final int avgTotal = _stageFrames > 0 ? _stageSumTotal ~/ _stageFrames : 0;

            debugPrint('[SCRFD_STAGE_SUMMARY] frames=$_stageFrames avg_input_prepare=$avgInput avg_inference=$avgInf avg_output=$avgOut avg_decode=$avgDec avg_nms=$avgNms avg_total=$avgTotal max_input_prepare=$_stageMaxInput max_inference=$_stageMaxInf max_total=$_stageMaxTotal worst_frame=$_stageWorstFrame');

            _stageFrames = 0;
            _stageSumInput = 0;
            _stageSumInf = 0;
            _stageSumOut = 0;
            _stageSumDec = 0;
            _stageSumNms = 0;
            _stageSumTotal = 0;
            _stageMaxInput = 0;
            _stageMaxInf = 0;
            _stageMaxTotal = 0;
            _stageWorstFrame = -1;
          }

          if (candidatesAfterNMS > 50) {
            debugPrint(
                '[SCRFD_ANOMALY] rawCandidates=$candidatesAfterNMS reason=unexpected_detection_explosion');
            return FaceDetectionResult(
              faces: [],
              frameWidth: originalWidth,
              frameHeight: originalHeight,
              timestamp: DateTime.now(),
              processTimeMs: sw.elapsedMilliseconds,
            );
          }

          // Convert to normalized coordinates
          for (final c in _reusableKept) {
            final origX1 = (c.x1 - padX) / scaleRatio;
            final origY1 = (c.y1 - padY) / scaleRatio;
            final origX2 = (c.x2 - padX) / scaleRatio;
            final origY2 = (c.y2 - padY) / scaleRatio;

            final normLeft = (origX1 / originalWidth).clamp(0.0, 1.0);
            final normTop = (origY1 / originalHeight).clamp(0.0, 1.0);
            final normRight = (origX2 / originalWidth).clamp(0.0, 1.0);
            final normBottom = (origY2 / originalHeight).clamp(0.0, 1.0);

            if (normRight - normLeft < 0.01 || normBottom - normTop < 0.01)
              continue;

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
              debugPrint(
                  '[SCRFD_BBOX] stride=${c.x1 < 160 ? "?" : "?"} score=${c.score.toStringAsFixed(3)} raw=[${c.x1.toStringAsFixed(1)},${c.y1.toStringAsFixed(1)},${c.x2.toStringAsFixed(1)},${c.y2.toStringAsFixed(1)}] norm=[${normLeft.toStringAsFixed(3)},${normTop.toStringAsFixed(3)},${normRight.toStringAsFixed(3)},${normBottom.toStringAsFixed(3)}]');
            }
          }

          // Throttled diagnostic
          if (shouldLog) {
            final logTotalMs = sw.elapsedMilliseconds;
            debugPrint(
                '[SCRFD_SMALL_PERF] SCRFD_CONFIG=A_INTRA1 INPUT=320 TENSOR_ALLOC=${allocMs}ms INFERENCE=${infMs}ms OUTPUT=${outputMs}ms DECODE=${decodeMs}ms NMS=${nmsMs}ms TOTAL=${logTotalMs}ms FACES=${detectedBoxes.length}');
            debugPrint(
                '[SCRFD_SMALL_RESULT] faces=${detectedBoxes.length} boxes=${detectedBoxes.length} latency=${logTotalMs}ms');
          }
        } else if (shouldLog) {
          debugPrint(
              '[SCRFD] WARNING: expected >=9 outputs, got ${outputs.length}');
        }

        final releaseSw = Stopwatch()..start();
        for (final out in outputs) {
          out?.release();
        }
        releaseSw.stop();
        releaseMs = releaseSw.elapsedMilliseconds;
        
        final endTotalMs = sw.elapsedMilliseconds;
        final totalMicro = sw.elapsedMicroseconds;

        // --- Phase 7 Telemetry ---
        final int workerToDetectMs = workerDelayMicro ~/ 1000;
        final int detectToRunMs = runStartMicro ~/ 1000;
        final int onnxInferenceMs = infMicro ~/ 1000;
        final int runToPostprocessMs = (totalMicro - runStartMicro - infMicro) ~/ 1000;
        final int scrfdTotalMs = totalMicro ~/ 1000;

        if (onnxInferenceMs > 80 || scrfdTotalMs > 100) {
          debugPrint('[SCRFD_SPIKE_DIAG]\n'
              'frame=$frameId\n'
              'worker_to_detect=$workerToDetectMs\n'
              'detect_to_run=$detectToRunMs\n'
              'onnx_inference=$onnxInferenceMs\n'
              'run_to_postprocess=$runToPostprocessMs\n'
              'scrfd_total=$scrfdTotalMs');
        }

        if (scrfdTotalMs > 100) {
          String classification = 'UNKNOWN';
          if (onnxInferenceMs > 100) {
            classification = 'ONNX_INFERENCE_SPIKE';
          } else if (workerToDetectMs > 30) {
            classification = 'WORKER_SCHEDULING_SPIKE';
          } else if (detectToRunMs > 30) {
            classification = 'PRE_INFERENCE_SPIKE';
          } else if (runToPostprocessMs > 30) {
            classification = 'POST_INFERENCE_SPIKE';
          } else {
            classification = 'DISTRIBUTED_OVERHEAD_SPIKE';
          }
          
          debugPrint('[SCRFD_SPIKE_CLASSIFICATION]\n'
              'frame=$frameId\n'
              'classification=$classification\n'
              'worker_to_detect=$workerToDetectMs\n'
              'detect_to_run=$detectToRunMs\n'
              'onnx_inference=$onnxInferenceMs\n'
              'run_to_postprocess=$runToPostprocessMs\n'
              'scrfd_total=$scrfdTotalMs');
        }

        _benchmarkFrameCount++;
        if (_benchmarkFrameCount > _benchmarkWarmupFrames) {
          _diagFrames++;
          _sumWorkerToDetect += workerDelayMicro;
          _sumDetectToRun += runStartMicro;
          _sumOnnxInference += infMicro;
          _sumRunToPostprocess += (totalMicro - runStartMicro - infMicro);
          _sumScrfdTotal += totalMicro;

          if (workerDelayMicro > _maxWorkerToDetect) _maxWorkerToDetect = workerDelayMicro;
          if (runStartMicro > _maxDetectToRun) _maxDetectToRun = runStartMicro;
          if (infMicro > _maxOnnxInference) _maxOnnxInference = infMicro;
          if ((totalMicro - runStartMicro - infMicro) > _maxRunToPostprocess) _maxRunToPostprocess = (totalMicro - runStartMicro - infMicro);
          if (totalMicro > _maxScrfdTotal) _maxScrfdTotal = totalMicro;

          if (onnxInferenceMs > 80) _spikesOnnx80++;
          if (onnxInferenceMs > 100) _spikesOnnx100++;
          if (scrfdTotalMs > 100) _spikesTotal100++;

          _inferenceHistory.add(infMicro);

          final nowTime = DateTime.now();
          if (_diagFrames >= 100 && nowTime.difference(_lastSummaryTime).inMilliseconds >= 2000) {
            final sortedInf = List<int>.from(_inferenceHistory)..sort();
            final medianInfMs = (sortedInf[sortedInf.length ~/ 2] / 1000.0).toStringAsFixed(1);
            final p95InfMs = (sortedInf[(sortedInf.length * 0.95).floor()] / 1000.0).toStringAsFixed(1);

            final avgWorkerToDetect = (_sumWorkerToDetect / _diagFrames / 1000.0).toStringAsFixed(1);
            final avgDetectToRun = (_sumDetectToRun / _diagFrames / 1000.0).toStringAsFixed(1);
            final avgOnnxInference = (_sumOnnxInference / _diagFrames / 1000.0).toStringAsFixed(1);
            final avgRunToPostprocess = (_sumRunToPostprocess / _diagFrames / 1000.0).toStringAsFixed(1);
            final avgScrfdTotal = (_sumScrfdTotal / _diagFrames / 1000.0).toStringAsFixed(1);

            debugPrint('[SCRFD_SPIKE_SUMMARY]\n'
                'frames=$_diagFrames\n'
                'avg_worker_to_detect=$avgWorkerToDetect\n'
                'avg_detect_to_run=$avgDetectToRun\n'
                'avg_onnx_inference=$avgOnnxInference\n'
                'avg_run_to_postprocess=$avgRunToPostprocess\n'
                'avg_scrfd_total=$avgScrfdTotal\n'
                'median_onnx_inference=$medianInfMs\n'
                'p95_onnx_inference=$p95InfMs\n'
                'max_worker_to_detect=${_maxWorkerToDetect ~/ 1000}\n'
                'max_detect_to_run=${_maxDetectToRun ~/ 1000}\n'
                'max_onnx_inference=${_maxOnnxInference ~/ 1000}\n'
                'max_run_to_postprocess=${_maxRunToPostprocess ~/ 1000}\n'
                'max_scrfd_total=${_maxScrfdTotal ~/ 1000}\n'
                'onnx_spikes_over_80=$_spikesOnnx80\n'
                'onnx_spikes_over_100=$_spikesOnnx100\n'
                'total_spikes_over_100=$_spikesTotal100\n'
                'worst_frame=unknown');

            _inferenceHistory.clear();
            _diagFrames = 0;
            _sumWorkerToDetect = 0;
            _sumDetectToRun = 0;
            _sumOnnxInference = 0;
            _sumRunToPostprocess = 0;
            _sumScrfdTotal = 0;
            _maxWorkerToDetect = 0;
            _maxDetectToRun = 0;
            _maxOnnxInference = 0;
            _maxRunToPostprocess = 0;
            _maxScrfdTotal = 0;
            _spikesOnnx80 = 0;
            _spikesOnnx100 = 0;
            _spikesTotal100 = 0;
            _lastSummaryTime = nowTime;
          }
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
          for (final sub in item) {
            extract(sub);
          }
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
      _runOptions?.release();
      _runOptions = null;
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
  _OutputMapping(
      {required this.stride, required this.head, required this.outputName});
}

class _Candidate {
  final double score;
  final double x1, y1, x2, y2;
  final List<List<double>> landmarks;
  _Candidate(this.score, this.x1, this.y1, this.x2, this.y2, this.landmarks);
}
