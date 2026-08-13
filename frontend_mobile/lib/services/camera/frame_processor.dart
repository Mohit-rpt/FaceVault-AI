import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'mobile_face_detector.dart';
import 'ai_worker.dart';

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
/// - If AI is busy, frame is dropped (latest-frame strategy)
/// - If AI is free, YUV conversion happens synchronously (CameraImage is valid),
///   then SCRFD runs asynchronously
/// - Camera preview is NEVER blocked by AI processing
class FrameProcessor {
  final AiWorker worker;

  int sensorOrientation = 90;

  // Counters
  int _framesReceived = 0;
  int _framesProcessed = 0;
  int _framesDropped = 0;
  int _latestDetectedFaceCount = 0;
  int _latestCallbackMs = 0;

  // Stage latencies
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

  // Latest RGB bytes for recognition pipeline
  Uint8List? _latestRgbBytes;
  int _latestRgbWidth = 0;
  int _latestRgbHeight = 0;

  // Throttled logging
  DateTime _lastLogTime = DateTime.fromMillisecondsSinceEpoch(0);

  Uint8List? get latestRgbBytes => _latestRgbBytes;
  int get latestRgbWidth => _latestRgbWidth;
  int get latestRgbHeight => _latestRgbHeight;

  final ValueNotifier<FaceDetectionResult?> detectionNotifier =
      ValueNotifier<FaceDetectionResult?>(null);
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
  /// MUST be ultra-lightweight:
  /// 1. Count frame for FPS
  /// 2. If AI is busy: drop frame, return immediately
  /// 3. If AI is free: convert YUV synchronously (CameraImage valid in callback),
  ///    then kick off async SCRFD
  void onCameraFrame(CameraImage image) {
    final sw = Stopwatch()..start();
    _framesReceived++;
    _cameraFrameCountWindow++;
    _updateFpsCounters();

    // Check if worker has a new result
    if (worker.latestResult != null &&
        worker.latestResult != detectionNotifier.value) {
      _framesProcessed++;
      _procFrameCountWindow++;

      _latestYuvToRgbMs = worker.latestYuvMs;
      _latestScrfdMs = worker.latestScrfdMs;
      _latestRgbBytes = worker.latestRgbBytes;
      _latestRgbWidth = worker.latestRgbWidth;
      _latestRgbHeight = worker.latestRgbHeight;

      detectionNotifier.value = worker.latestResult;
      _latestDetectedFaceCount = worker.latestResult!.faces.length;
    }

    if (worker.isBusy) {
      _framesDropped++;
      sw.stop();
      _latestCallbackMs = sw.elapsedMilliseconds;
      _emitMetrics();
      return;
    }

    // Extract YUV bytes without copying (as much as possible)
    // and send to worker.
    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      worker.processFrame(
        yBytes: image.planes[0].bytes,
        uBytes: image.planes[1].bytes,
        vBytes: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        width: image.width,
        height: image.height,
        sensorOrientation: sensorOrientation,
      );
    }

    sw.stop();
    _latestCallbackMs = sw.elapsedMilliseconds;
    _emitMetrics();
  }

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
      debugPrint(
          '[AI_PERF_V2] CAM_FPS=${_calculatedCameraFps.toStringAsFixed(1)} PROC_FPS=${_calculatedProcFps.toStringAsFixed(1)} FACES=$_latestDetectedFaceCount CAMERA_CALLBACK_MS=$_latestCallbackMs WORKER_QUEUE=${busy ? 1 : 0} WORKER_BUSY=$busy YUV_MS=${_latestYuvToRgbMs} SCRFD_MS=${_latestScrfdMs} POSTPROCESS_MS=0 RESULT_TRANSFER_MS=0 DROP=$_framesDropped');
    }

    metricsNotifier.value = FrameProcessorMetrics(
      cameraFps: _calculatedCameraFps,
      processingFps: _calculatedProcFps,
      framesReceived: _framesReceived,
      framesProcessed: _framesProcessed,
      framesDropped: _framesDropped,
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
    metricsNotifier.dispose();
  }
}
