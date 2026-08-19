import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'mobile_face_detector.dart';
import 'pipeline_profiler.dart';
import 'ai_worker.dart';
import 'frame_queue.dart';
import '../local_recognition/local_recognition_result.dart';

final Stopwatch globalUiClock = Stopwatch()..start();

const bool kCameraOnlyProfilingMode = false;

class FrameProcessorMetrics {
  final double cameraFps;
  final double processingFps;
  final int framesReceived;
  final int framesProcessed;
  final int framesDropped;
  final int averageProcessingTimeMs;
  final int queueSize;
  final int detectedFaceCount;
  final int yuvToRgbMs;
  final int scrfdMs;
  final int alignMs;
  final int embedMs;
  final int searchMs;

  FrameProcessorMetrics({
    required this.cameraFps,
    required this.processingFps,
    required this.framesReceived,
    required this.framesProcessed,
    required this.framesDropped,
    required this.averageProcessingTimeMs,
    required this.queueSize,
    required this.detectedFaceCount,
    this.yuvToRgbMs = 0,
    this.scrfdMs = 0,
    this.alignMs = 0,
    this.embedMs = 0,
    this.searchMs = 0,
  });

  @override
  String toString() {
    return 'CAM: ${cameraFps.toStringAsFixed(1)} FPS | PROC: ${processingFps.toStringAsFixed(1)} FPS | Q: $queueSize | DROP: $framesDropped | FACES: $detectedFaceCount';
  }
}

/// Frame processor using single-slot latest-frame strategy.
///
/// Architecture:
/// - Camera delivers ~30 FPS frames
/// - If AI is busy, frame is latched (latest-frame strategy)
/// - Background AI worker handles: YUV, SCRFD, alignment, ONNX embedding, and vector search
/// - Camera preview and main UI thread are NEVER blocked by AI processing
class FrameProcessor {
  final AiWorker worker;

  int sensorOrientation = 90;

  // Stats state
  int _framesReceived = 0;
  int _framesProcessed = 0;
  int _framesDropped = 0;
  int _framesReplaced = 0;

  AIWorkerResult? latestWorkerResult;
  int _latestDetectedFaceCount = 0;
  int _latestCallbackMs = 0;

  int _frameIdCounter = 0;

  // Stage latencies (measured inside the worker isolate)
  int _latestYuvToRgbMs = 0;
  int _latestScrfdMs = 0;
  int _latestAlignMs = 0;
  int _latestEmbedMs = 0;
  int _latestSearchMs = 0;

  // FPS tracking
  DateTime _fpsStartTime = DateTime.now();
  int _cameraFrameCountWindow = 0;
  int _procFrameCountWindow = 0;
  double _calculatedCameraFps = 0.0;
  double _calculatedProcFps = 0.0;

  // Throttled logging
  DateTime _lastLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  final ValueNotifier<FaceDetectionResult?> detectionNotifier =
      ValueNotifier<FaceDetectionResult?>(null);
  final ValueNotifier<List<LocalRecognitionResult>> recognitionResultsNotifier =
      ValueNotifier<List<LocalRecognitionResult>>([]);
  final ValueNotifier<FrameProcessorMetrics> metricsNotifier =
      ValueNotifier<FrameProcessorMetrics>(
    FrameProcessorMetrics(
      cameraFps: 0.0,
      processingFps: 0.0,
      framesReceived: 0,
      framesProcessed: 0,
      framesDropped: 0,
      averageProcessingTimeMs: 0,
      queueSize: 0,
      detectedFaceCount: 0,
    ),
  );

  FrameProcessor({
    required this.worker,
  });

  void updateRecognitionLatencies({
    required int alignMs,
    required int embedMs,
    required int searchMs,
  }) {
    _latestAlignMs = alignMs;
    _latestEmbedMs = embedMs;
    _latestSearchMs = searchMs;
    _emitMetrics();
  }

  /// Camera image stream callback.
  ///
  /// Ultra-lightweight:
  /// 1. Record monotonic timings & count frame for FPS
  /// 2. If AI is busy: latch freshest frame in persistent Uint8List buffer, return immediately
  /// 3. If AI is free: dispatch frame to background worker isolate, return immediately
  void onCameraFrame(CameraImage image) {
    final sw = Stopwatch()..start();

    PipelineProfiler.instance.framesReceived++;
    final int cameraEntryMicro = globalUiClock.elapsedMicroseconds;
    final int cameraEntryMs = DateTime.now().millisecondsSinceEpoch;
    _framesReceived++;
    _cameraFrameCountWindow++;
    _frameIdCounter++;
    final int currentFrameId = _frameIdCounter;
    _updateFpsCounters();

    final int tAfterBookkeeping = sw.elapsedMicroseconds;

    // Check if worker has a new result
    if (worker.latestResult != null &&
        worker.latestResult != detectionNotifier.value) {
      _framesProcessed++;
      _procFrameCountWindow++;

      _latestYuvToRgbMs = worker.latestYuvMs;
      _latestScrfdMs = worker.latestScrfdMs;
      _latestAlignMs = worker.latestAlignMs;
      _latestEmbedMs = worker.latestEmbedMs;
      _latestSearchMs = worker.latestSearchMs;

      latestWorkerResult = worker.latestWorkerResult;
      detectionNotifier.value = worker.latestResult;
      recognitionResultsNotifier.value = worker.latestRecognitionResults;
      _latestDetectedFaceCount = worker.latestResult!.faces.length;
    }

    final int tAfterResultCheck = sw.elapsedMicroseconds;

    if (!kUseContinuousFrameLatch) {
      if (worker.isBusy) {
        _framesDropped++;
        PipelineProfiler.instance.framesDropped++;
        sw.stop();
        _latestCallbackMs = sw.elapsedMilliseconds;
        _emitMetrics();
        return;
      }
    } else {
      if (worker.hasPendingFrame) {
        PipelineProfiler.instance.framesReplaced++;
      }
    }

    // Extract YUV bytes and send to worker.
    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      // ── Time plane access ──
      final int tPlaneStart = sw.elapsedMicroseconds;
      final Uint8List yBytes = image.planes[0].bytes;
      final Uint8List uBytes = image.planes[1].bytes;
      final Uint8List vBytes = image.planes[2].bytes;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      final int imgWidth = image.width;
      final int imgHeight = image.height;
      final int tPlaneEnd = sw.elapsedMicroseconds;

      worker.latestCamFps = _calculatedCameraFps;
      worker.latestProcFps = _calculatedProcFps;
      PipelineProfiler.instance.framesDispatched++;

      // ── Time processFrame call ──
      final int tProcessStart = sw.elapsedMicroseconds;
      worker.processFrame(
        yBytes: yBytes,
        uBytes: uBytes,
        vBytes: vBytes,
        yRowStride: yRowStride,
        uvRowStride: uvRowStride,
        uvPixelStride: uvPixelStride,
        width: imgWidth,
        height: imgHeight,
        sensorOrientation: sensorOrientation,
        cameraEntryMs: cameraEntryMs,
        cameraEntryMicro: cameraEntryMicro,
        frameId: currentFrameId,
      );
      final int tProcessEnd = sw.elapsedMicroseconds;

      final int planeAccessUs = tPlaneEnd - tPlaneStart;
      final int processFrameUs = tProcessEnd - tProcessStart;
      final int bookkeepingUs = tAfterBookkeeping;
      final int resultCheckUs = tAfterResultCheck - tAfterBookkeeping;

      _cbPlaneAccessAccum += planeAccessUs;
      _cbProcessFrameAccum += processFrameUs;
      _cbBookkeepingAccum += bookkeepingUs;
      _cbResultCheckAccum += resultCheckUs;
      _cbOuterDiagFrames++;
      if (planeAccessUs > _cbMaxPlaneAccess) _cbMaxPlaneAccess = planeAccessUs;
      if (processFrameUs > _cbMaxProcessFrame) _cbMaxProcessFrame = processFrameUs;
      if (bookkeepingUs > _cbMaxBookkeeping) _cbMaxBookkeeping = bookkeepingUs;
      if (resultCheckUs > _cbMaxResultCheck) _cbMaxResultCheck = resultCheckUs;
    }

    sw.stop();
    _latestCallbackMs = sw.elapsedMilliseconds;
    if (_latestCallbackMs > _maxCallbackMs) _maxCallbackMs = _latestCallbackMs;
    _emitMetrics();
  }

  // Phase 12: outer callback stage accumulators
  int _cbPlaneAccessAccum = 0;
  int _cbProcessFrameAccum = 0;
  int _cbBookkeepingAccum = 0;
  int _cbResultCheckAccum = 0;
  int _cbOuterDiagFrames = 0;
  int _cbMaxPlaneAccess = 0;
  int _cbMaxProcessFrame = 0;
  int _cbMaxBookkeeping = 0;
  int _cbMaxResultCheck = 0;

  int _maxCallbackMs = 0;

  void _updateFpsCounters() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_fpsStartTime).inMilliseconds;
    if (elapsedMs >= 1000) {
      _calculatedCameraFps = (_cameraFrameCountWindow * 1000.0) / elapsedMs;
      _calculatedProcFps = (_procFrameCountWindow * 1000.0) / elapsedMs;
      _cameraFrameCountWindow = 0;
      _procFrameCountWindow = 0;
      _fpsStartTime = now;
    }
  }

  void _emitMetrics() {
    final totalMs = _latestYuvToRgbMs +
        _latestScrfdMs +
        _latestAlignMs +
        _latestEmbedMs +
        _latestSearchMs;

    // Throttled telemetry log (~1 per second)
    final now = DateTime.now();
    if (now.difference(_lastLogTime).inMilliseconds >= 1000) {
      _lastLogTime = now;
      final bool busy = worker.isBusy;
      
      debugPrint('\n[CAMERA_PIPELINE_PERF]\n'
          'camera_fps=${_calculatedCameraFps.toStringAsFixed(1)}\n'
          'camera_callback_ms=$_latestCallbackMs\n'
          'camera_callback_max_ms=$_maxCallbackMs\n'
          'frames_received=$_framesReceived\n'
          'frames_replaced=${worker.latchReplaced}\n'
          'worker_busy=$busy\n'
          'processing_fps=${_calculatedProcFps.toStringAsFixed(1)}\n'
          'pending_frame=${worker.hasPendingFrame}\n');
          
      _maxCallbackMs = 0;
      
      final int drops = kUseContinuousFrameLatch ? worker.latchReplaced : _framesDropped;
      debugPrint(
          '[AI_PERF_V2] CAM_FPS=${_calculatedCameraFps.toStringAsFixed(1)} PROC_FPS=${_calculatedProcFps.toStringAsFixed(1)} FACES=$_latestDetectedFaceCount CAMERA_CALLBACK_MS=$_latestCallbackMs WORKER_QUEUE=${busy ? 1 : 0} WORKER_BUSY=$busy YUV_MS=${_latestYuvToRgbMs} SCRFD_MS=${_latestScrfdMs} ALIGN_MS=$_latestAlignMs EMBED_MS=$_latestEmbedMs SEARCH_MS=$_latestSearchMs DROP=$drops');
      
      if (kUseContinuousFrameLatch) {
        debugPrint('[AI_LATCH] received=${worker.latchReceived} replaced=${worker.latchReplaced} processed=${worker.latchProcessed} pending=${worker.hasPendingFrame}');
      }

      // Phase 12: outer callback stage breakdown
      if (_cbOuterDiagFrames > 0) {
        debugPrint('\n[CAMERA_CALLBACK_OUTER_SUMMARY]\n'
            'frames=$_cbOuterDiagFrames\n'
            'avg_bookkeeping=${_cbBookkeepingAccum ~/ _cbOuterDiagFrames}us\n'
            'max_bookkeeping=${_cbMaxBookkeeping}us\n'
            'avg_result_check=${_cbResultCheckAccum ~/ _cbOuterDiagFrames}us\n'
            'max_result_check=${_cbMaxResultCheck}us\n'
            'avg_plane_access=${_cbPlaneAccessAccum ~/ _cbOuterDiagFrames}us\n'
            'max_plane_access=${_cbMaxPlaneAccess}us\n'
            'avg_process_frame=${_cbProcessFrameAccum ~/ _cbOuterDiagFrames}us\n'
            'max_process_frame=${_cbMaxProcessFrame}us\n');

        _cbPlaneAccessAccum = 0;
        _cbProcessFrameAccum = 0;
        _cbBookkeepingAccum = 0;
        _cbResultCheckAccum = 0;
        _cbOuterDiagFrames = 0;
        _cbMaxPlaneAccess = 0;
        _cbMaxProcessFrame = 0;
        _cbMaxBookkeeping = 0;
        _cbMaxResultCheck = 0;
      }
    }

    metricsNotifier.value = FrameProcessorMetrics(
      cameraFps: _calculatedCameraFps,
      processingFps: _calculatedProcFps,
      framesReceived: _framesReceived,
      framesProcessed: _framesProcessed,
      framesDropped: kUseContinuousFrameLatch ? worker.latchReplaced : _framesDropped,
      averageProcessingTimeMs: totalMs,
      queueSize: worker.isBusy ? 1 : 0,
      detectedFaceCount: _latestDetectedFaceCount,
      yuvToRgbMs: _latestYuvToRgbMs,
      scrfdMs: _latestScrfdMs,
      alignMs: _latestAlignMs,
      embedMs: _latestEmbedMs,
      searchMs: _latestSearchMs,
    );
  }

  void resetStats() {
    _framesReceived = 0;
    _framesProcessed = 0;
    _framesDropped = 0;
    _latestDetectedFaceCount = 0;
    _latestYuvToRgbMs = 0;
    _latestScrfdMs = 0;
    _latestAlignMs = 0;
    _latestEmbedMs = 0;
    _latestSearchMs = 0;
  }

  void dispose() {
    detectionNotifier.dispose();
    recognitionResultsNotifier.dispose();
    metricsNotifier.dispose();
  }
}
