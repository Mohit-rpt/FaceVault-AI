// lib/services/camera/frame_processor.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'frame_queue.dart';
import 'image_converter.dart';
import 'mobile_face_detector.dart';

/// Real-time Debug Performance Metrics object.
class FrameProcessorMetrics {
  final double cameraFps;
  final double processingFps;
  final int framesReceived;
  final int framesProcessed;
  final int framesDropped;
  final int averageProcessingTimeMs;
  final int queueSize;
  final int detectedFaceCount;

  FrameProcessorMetrics({
    required this.cameraFps,
    required this.processingFps,
    required this.framesReceived,
    required this.framesProcessed,
    required this.framesDropped,
    required this.averageProcessingTimeMs,
    required this.queueSize,
    required this.detectedFaceCount,
  });

  @override
  String toString() {
    return 'Camera: ${cameraFps.toStringAsFixed(1)} FPS | Proc: ${processingFps.toStringAsFixed(1)} FPS | Rec: $framesReceived | Proc: $framesProcessed | Drop: $framesDropped | Avg: ${averageProcessingTimeMs}ms | Faces: $detectedFaceCount';
  }
}

/// Orchestrates real-time frame throttling, queueing, background conversion, and face detection.
class FrameProcessor {
  final MobileFaceDetector detector;
  final FrameQueue frameQueue;

  /// Target processing interval in milliseconds (e.g. 66ms = ~15 FPS, 100ms = ~10 FPS)
  int targetProcessingIntervalMs;
  DateTime _lastProcessedTime = DateTime.fromMillisecondsSinceEpoch(0);

  int _framesReceived = 0;
  int _framesProcessed = 0;
  int _totalProcessTimeMs = 0;
  int _latestDetectedFaceCount = 0;

  DateTime _fpsStartTime = DateTime.now();
  int _cameraFrameCountWindow = 0;
  int _procFrameCountWindow = 0;
  double _calculatedCameraFps = 0.0;
  double _calculatedProcFps = 0.0;

  final ValueNotifier<FaceDetectionResult?> detectionNotifier = ValueNotifier<FaceDetectionResult?>(null);
  final ValueNotifier<FrameProcessorMetrics> metricsNotifier = ValueNotifier<FrameProcessorMetrics>(
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
    MobileFaceDetector? detector,
    FrameQueue? frameQueue,
    this.targetProcessingIntervalMs = 66, // Default 15 FPS sampling
  })  : detector = detector ?? MobileFaceDetector(),
        frameQueue = frameQueue ?? FrameQueue(maxCapacity: 2);

  /// Process incoming raw CameraImage frame from stream.
  void onCameraFrame(CameraImage image) {
    _framesReceived++;
    _cameraFrameCountWindow++;
    _updateFpsCounters();

    final now = DateTime.now();
    final elapsedSinceLast = now.difference(_lastProcessedTime).inMilliseconds;

    // Frame Throttling check (skip frames faster than target FPS interval)
    if (elapsedSinceLast < targetProcessingIntervalMs) {
      return;
    }

    // Enqueue frame into bounded queue
    frameQueue.enqueue(image);

    // Trigger async processing if lock is free
    _processNextQueuedFrame();
  }

  /// Pop frame from queue and execute YUV → RGB conversion and Face Detection.
  Future<void> _processNextQueuedFrame() async {
    final item = frameQueue.popForProcessing();
    if (item == null) return;

    _lastProcessedTime = DateTime.now();

    try {
      final image = item.image;

      // Step 1: YUV420/BGRA to normalized RGB Float32List tensor
      final Float32List rgbTensor = ImageConverter.convertCameraImageToRgbTensor(
        image,
        targetWidth: 112,
        targetHeight: 112,
      );

      // Step 2: Run Face Detection ONLY (No face recognition)
      final FaceDetectionResult detection = await detector.detectFaces(
        rgbData: rgbTensor,
        width: image.width,
        height: image.height,
      );

      _framesProcessed++;
      _procFrameCountWindow++;
      _totalProcessTimeMs += detection.processTimeMs;
      _latestDetectedFaceCount = detection.faces.length;

      // Update detection payload notifier
      detectionNotifier.value = detection;
    } catch (e) {
      debugPrint('⚠️ [FrameProcessor] Processing error: $e');
    } finally {
      frameQueue.releaseProcessingLock();
      _emitMetrics();
    }
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
    final avgTime = _framesProcessed > 0 ? (_totalProcessTimeMs ~/ _framesProcessed) : 0;
    metricsNotifier.value = FrameProcessorMetrics(
      cameraFps: _calculatedCameraFps,
      processingFps: _calculatedProcFps,
      framesReceived: _framesReceived,
      framesProcessed: _framesProcessed,
      framesDropped: frameQueue.droppedCount,
      averageProcessingTimeMs: avgTime,
      queueSize: frameQueue.currentSize,
      detectedFaceCount: _latestDetectedFaceCount,
    );
  }

  void resetStats() {
    _framesReceived = 0;
    _framesProcessed = 0;
    _totalProcessTimeMs = 0;
    _latestDetectedFaceCount = 0;
    frameQueue.resetStats();
  }

  void dispose() {
    frameQueue.clear();
    detectionNotifier.dispose();
    metricsNotifier.dispose();
  }
}
