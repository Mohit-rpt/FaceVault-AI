import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'image_converter.dart';
import 'mobile_face_detector.dart';


/// Request sent from the UI isolate to the Background isolate.
class AIWorkerFrameRequest {
  final TransferableTypedData yBuffer;
  final TransferableTypedData uBuffer;
  final TransferableTypedData vBuffer;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int width;
  final int height;
  final int sensorOrientation;

  AIWorkerFrameRequest({
    required this.yBuffer,
    required this.uBuffer,
    required this.vBuffer,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.width,
    required this.height,
    required this.sensorOrientation,
  });
}

/// Result returned from Background isolate to UI isolate.
class AIWorkerResult {
  final FaceDetectionResult detection;
  final int totalPipelineMs;
  final int yuvConversionMs;
  final Uint8List rgbBytes;
  final int rgbWidth;
  final int rgbHeight;
  
  AIWorkerResult({
    required this.detection,
    required this.totalPipelineMs,
    required this.yuvConversionMs,
    required this.rgbBytes,
    required this.rgbWidth,
    required this.rgbHeight,
  });
}

class AiWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isBusy = false;

  // The latest result
  FaceDetectionResult? latestResult;
  int latestPipelineMs = 0;
  int latestYuvMs = 0;
  int latestScrfdMs = 0;
  Uint8List? latestRgbBytes;
  int latestRgbWidth = 0;
  int latestRgbHeight = 0;

  bool get isReady => _isReady;
  bool get isBusy => _isBusy;

  /// Initializes the isolate. MUST be called on the UI thread once.
  Future<void> initialize() async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;

    try {
      // 1. Load model bytes on the UI isolate via rootBundle
      final rawData = await rootBundle.load('assets/models/det_500m.onnx');
      final modelBytes = rawData.buffer.asUint8List(
        rawData.offsetInBytes,
        rawData.lengthInBytes,
      );

      final initPort = ReceivePort();
      
      _isolate = await Isolate.spawn(
        _workerEntrypoint,
        _WorkerInitData(
          sendPort: initPort.sendPort,
          modelBytes: modelBytes,
          rootToken: RootIsolateToken.instance!,
        ),
        debugName: 'FaceVault_AI_Worker',
      );

      // Wait for the worker to send back its SendPort so we can send frames to it
      final workerSendPort = await initPort.first as SendPort;
      _sendPort = workerSendPort;

      // Now listen for detection results
      _receivePort.listen((message) {
        if (message is AIWorkerResult) {
          latestResult = message.detection;
          latestPipelineMs = message.totalPipelineMs;
          latestYuvMs = message.yuvConversionMs;
          latestScrfdMs = message.detection.processTimeMs;
          latestRgbBytes = message.rgbBytes;
          latestRgbWidth = message.rgbWidth;
          latestRgbHeight = message.rgbHeight;
          _isBusy = false; // Mark as free for the next frame
        }
      });

      _isReady = true;
    } catch (e) {
      debugPrint('❌ [AI_WORKER] Failed to spawn isolate: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Pushes a camera frame to the worker. Uses strict latest-frame dropping.
  void processFrame({
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int width,
    required int height,
    required int sensorOrientation,
  }) {
    if (!_isReady || _sendPort == null) return;
    
    // STRICT LATEST-FRAME: Drop if busy. Queue size exactly 0 or 1.
    if (_isBusy) {
      return; 
    }
    
    _isBusy = true;

    // Wrap the raw planes in TransferableTypedData to avoid memory copying
    final request = AIWorkerFrameRequest(
      yBuffer: TransferableTypedData.fromList([yBytes]),
      uBuffer: TransferableTypedData.fromList([uBytes]),
      vBuffer: TransferableTypedData.fromList([vBytes]),
      yRowStride: yRowStride,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
      width: width,
      height: height,
      sensorOrientation: sensorOrientation,
    );

    _sendPort!.send([_receivePort.sendPort, request]);
  }

  void dispose() {
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isReady = false;
    _isBusy = false;
  }
}

/// Data used to initialize the worker isolate
class _WorkerInitData {
  final SendPort sendPort;
  final Uint8List modelBytes;
  final RootIsolateToken rootToken;

  _WorkerInitData({
    required this.sendPort,
    required this.modelBytes,
    required this.rootToken,
  });
}

/// Entrypoint for the background isolate
Future<void> _workerEntrypoint(_WorkerInitData initData) async {
  // Ensure background isolate can use platform channels and flutter services
  BackgroundIsolateBinaryMessenger.ensureInitialized(initData.rootToken);

  // 1. Initialize ONNX runtime exactly ONCE
  OrtEnv.instance.init();
  
  // 2. Initialize the Face Detector
  final detector = MobileFaceDetector();
  await detector.initializeFromBytes(initData.modelBytes);
  debugPrint('✅ [AI_WORKER] SCRFD_INITIALIZATION_COUNT = 1');

  // 3. Create a port to receive frames from the UI isolate
  final port = ReceivePort();
  
  // 4. Send the port back so the UI isolate can send us messages
  initData.sendPort.send(port.sendPort);

  // 5. Listen for incoming frames
  await for (final message in port) {
    if (message is List && message.length == 2) {
      final replyPort = message[0] as SendPort;
      final req = message[1] as AIWorkerFrameRequest;

      final sw = Stopwatch()..start();

      try {
        // Materialize the typed data
        final yBuffer = req.yBuffer.materialize().asUint8List();
        final uBuffer = req.uBuffer.materialize().asUint8List();
        final vBuffer = req.vBuffer.materialize().asUint8List();

        // 1. Convert YUV to 640x640 Tensor
        final tensorResult = ImageConverter.convertRawYuvToDetectorTensor(
          yBuffer: yBuffer,
          uBuffer: uBuffer,
          vBuffer: vBuffer,
          yRowStride: req.yRowStride,
          uvRowStride: req.uvRowStride,
          uvPixelStride: req.uvPixelStride,
          origW: req.width,
          origH: req.height,
          sensorOrientation: req.sensorOrientation,
          targetSize: 640,
        );

        final yuvTime = tensorResult.conversionTimeMs;

        // 2. Run SCRFD Inference
        final detection = await detector.detectFaces(
          detectorTensor: tensorResult.tensor,
          tensorSize: 640,
          scaleRatio: tensorResult.scaleRatio,
          padX: tensorResult.padX,
          padY: tensorResult.padY,
          originalWidth: tensorResult.originalWidth,
          originalHeight: tensorResult.originalHeight,
        );

        sw.stop();

        // 3. Return results
        replyPort.send(AIWorkerResult(
          detection: detection,
          totalPipelineMs: sw.elapsedMilliseconds,
          yuvConversionMs: yuvTime,
          rgbBytes: tensorResult.rgbBytes,
          rgbWidth: 640,
          rgbHeight: 640,
        ));

      } catch (e, stack) {
        debugPrint('❌ [AI_WORKER] Exception: $e');
        debugPrintStack(stackTrace: stack);
        
        // Return empty result on failure to unblock UI isolate
        sw.stop();
        replyPort.send(AIWorkerResult(
          detection: FaceDetectionResult(
            faces: [],
            frameWidth: req.width,
            frameHeight: req.height,
            timestamp: DateTime.now(),
            processTimeMs: 0,
          ),
          totalPipelineMs: sw.elapsedMilliseconds,
          yuvConversionMs: 0,
          rgbBytes: Uint8List(0),
          rgbWidth: 0,
          rgbHeight: 0,
        ));
      }
    }
  }
}
