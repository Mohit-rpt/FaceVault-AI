import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'image_converter.dart';
import 'mobile_face_detector.dart';
import 'experimental_scrfd_detector.dart';
import 'frame_processor.dart';
import '../local_recognition/local_recognition_result.dart';
import '../local_recognition/face_alignment_service.dart';
import '../local_recognition/vector_index_manager.dart';
import '../local_recognition/face_tracker.dart';

// PRODUCTION CANDIDATE SWITCH: 320x320 vs 640x640 SCRFD
// - true: Uses the optimized 320x320 ExperimentalSCRFDDetector
// - false: Uses the original 640x640 MobileFaceDetector
const bool kUseExperimentalScrfd = true;

// CAMERA -> AI WORKER DECOUPLING EXPERIMENT
const bool kUseContinuousFrameLatch = true;

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

  // Pipeline Forensics
  final int frameId;
  final int cameraEntryMs;
  final int cameraEntryMicro;
  int dispatchMs = 0;
  int dispatchMicro = 0;

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
    required this.frameId,
    required this.cameraEntryMs,
    required this.cameraEntryMicro,
  });
}

/// Message to update the in-memory vector index inside the worker isolate.
class AIWorkerUpdateVectorIndexMessage {
  final List<VectorIndexItem> items;
  AIWorkerUpdateVectorIndexMessage({required this.items});
}

/// Message to reset the face tracker inside the worker isolate.
class AIWorkerResetTrackerMessage {}

/// Compact result returned from Background isolate to UI isolate.
/// Note: rgbBytes are intentionally OMITTED to prevent large memory transfers to the main isolate.
class AIWorkerResult {
  final FaceDetectionResult detection;
  final List<LocalRecognitionResult> recognitionResults;
  final int totalPipelineMs;
  final int yuvConversionMs;
  final int scrfdMs;
  final int alignMs;
  final int embedMs;
  final int searchMs;
  final int trackingMs;
  
  // Pipeline Forensics
  final int frameId;
  final int cameraEntryMs;
  final int cameraEntryMicro;
  final int dispatchMs;
  final int dispatchMicro;
  
  final int workerStartMs;
  final int workerStartMicro;
  final int yuvStartMicro;
  final int yuvEndMicro;
  final int scrfdStartMicro;
  final int scrfdEndMicro;
  final int workerEndMs;
  final int workerEndMicro;
  final int workerResultStartMicro;
  final int workerResultEndMicro;
  int? uiReceiveMicro;
  
  AIWorkerResult({
    required this.detection,
    required this.recognitionResults,
    required this.totalPipelineMs,
    required this.yuvConversionMs,
    required this.scrfdMs,
    required this.alignMs,
    required this.embedMs,
    required this.searchMs,
    required this.trackingMs,
    required this.frameId,
    required this.cameraEntryMs,
    required this.cameraEntryMicro,
    required this.dispatchMs,
    required this.dispatchMicro,
    required this.workerStartMs,
    required this.workerStartMicro,
    required this.yuvStartMicro,
    required this.yuvEndMicro,
    required this.scrfdStartMicro,
    required this.scrfdEndMicro,
    required this.workerEndMs,
    required this.workerEndMicro,
    required this.workerResultStartMicro,
    required this.workerResultEndMicro,
  });
}

class AiWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isBusy = false;

  // The latest results from the worker
  FaceDetectionResult? latestResult;
  List<LocalRecognitionResult> latestRecognitionResults = [];
  AIWorkerResult? latestWorkerResult;
  int latestPipelineMs = 0;
  int latestYuvMs = 0;
  int latestScrfdMs = 0;
  int latestAlignMs = 0;
  int latestEmbedMs = 0;
  int latestSearchMs = 0;
  int latestTrackingMs = 0;
  
  double latestCamFps = 0.0;
  double latestProcFps = 0.0;
  
  // Latch metrics
  int latchReceived = 0;
  int latchReplaced = 0;
  int latchProcessed = 0;
  
  bool _hasPendingFrame = false;
  Uint8List? _pendingY;
  Uint8List? _pendingU;
  Uint8List? _pendingV;
  int _pendingYRowStride = 0;
  int _pendingUvRowStride = 0;
  int _pendingUvPixelStride = 0;
  int _pendingWidth = 0;
  int _pendingHeight = 0;
  int _pendingSensorOrientation = 0;
  int _pendingFrameId = 0;
  int _pendingCameraEntryMs = 0;
  int _pendingCameraEntryMicro = 0;
  
  bool get hasPendingFrame => _hasPendingFrame;
  
  // V2 Diag metrics
  DateTime _lastDiagTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _diagFramesReceived = 0;
  int _diagFramesProcessed = 0;
  int _diagFramesReplaced = 0;
  int _diagNormalCycles = 0;
  int _diagStallCycles = 0;
  int _diagMaxTotalCycle = 0;
  int _diagMaxCameraToDispatch = 0;
  int _diagMaxDispatchToWorker = 0;
  int _diagMaxYuv = 0;
  int _diagMaxScrfd = 0;
  int _diagMaxWorkerProcessing = 0;
  int _diagMaxWorkerToUi = 0;
  int _diagSumNormalCycle = 0;
  int _diagSumNormalScrfd = 0;
  int _diagSumNormalYuv = 0;
  int _diagWorstStallFrameId = -1;

  // Phase 14 Worker Stage Profiling
  DateTime _lastWorkerStageDiagTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _workerStageFrames = 0;
  int _wsSumYuv = 0;
  int _wsSumScrfd = 0;
  int _wsSumAlign = 0;
  int _wsSumEmbed = 0;
  int _wsSumSearch = 0;
  int _wsSumTrack = 0;
  int _wsSumTotal = 0;
  int _wsMaxYuv = 0;
  int _wsMaxScrfd = 0;
  int _wsMaxAlign = 0;
  int _wsMaxEmbed = 0;
  int _wsMaxSearch = 0;
  int _wsMaxTrack = 0;
  int _wsMaxTotal = 0;
  int _wsWorstFrameId = -1;

  bool get isReady => _isReady;
  bool get isInitialized => _isReady;
  bool get isBusy => _isBusy;

  // ── Phase 12: callback stage profiling (main isolate only) ──
  final Stopwatch _cbSw = Stopwatch()..start();

  int lastCopyYUs = 0;
  int lastCopyUUs = 0;
  int lastCopyVUs = 0;
  int lastCopyTotalUs = 0;
  int lastPendingWriteUs = 0;
  int lastTransferableCreateUs = 0;
  int lastSendUs = 0;
  int lastCallbackPathUs = 0;

  int _cbDiagFrames = 0;
  int _cbSumCopyTotal = 0;
  int _cbSumPendingWrite = 0;
  int _cbSumTransferableCreate = 0;
  int _cbSumSend = 0;
  int _cbSumCallbackPath = 0;
  int _cbMaxCopyTotal = 0;
  int _cbMaxPendingWrite = 0;
  int _cbMaxTransferableCreate = 0;
  int _cbMaxSend = 0;
  int _cbMaxCallbackPath = 0;
  final List<int> _cbCopyTotalSamples = [];
  final List<int> _cbCallbackPathSamples = [];
  DateTime _cbLastSummaryTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Initializes the isolate. MUST be called on the UI thread once.
  Future<void> initialize({
    List<VectorIndexItem>? initialIndexItems,
    double similarityThreshold = 0.45,
  }) async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;

    try {
      // 1. Load detector model bytes on the UI isolate via rootBundle
      final detectorModelPath = kUseExperimentalScrfd
          ? ExperimentalSCRFDDetector.detectorModelPath
          : MobileFaceDetector.detectorModelPath;
      final rawDetectorData = await rootBundle.load(detectorModelPath);
      final detectorModelBytes = rawDetectorData.buffer.asUint8List(
        rawDetectorData.offsetInBytes,
        rawDetectorData.lengthInBytes,
      );

      // 2. Load embedding model bytes on the UI isolate via rootBundle
      const embeddingModelPath = 'assets/models/w600k_mbf.onnx';
      final rawEmbeddingData = await rootBundle.load(embeddingModelPath);
      final embeddingModelBytes = rawEmbeddingData.buffer.asUint8List(
        rawEmbeddingData.offsetInBytes,
        rawEmbeddingData.lengthInBytes,
      );

      final initPort = ReceivePort();

      _isolate = await Isolate.spawn(
        _workerEntrypoint,
        _WorkerInitData(
          sendPort: initPort.sendPort,
          detectorModelBytes: detectorModelBytes,
          embeddingModelBytes: embeddingModelBytes,
          initialVectorIndexItems: initialIndexItems ?? [],
          similarityThreshold: similarityThreshold,
          rootToken: RootIsolateToken.instance!,
        ),
        debugName: 'FaceVault_AI_Worker',
      );

      final workerSendPort = await initPort.first as SendPort;
      _sendPort = workerSendPort;

      // Listen for detection and recognition results from worker isolate
      _receivePort.listen((message) {
        if (message is AIWorkerResult) {
          final workerResult = message;
          workerResult.uiReceiveMicro = globalUiClock.elapsedMicroseconds;
          final int uiReceiveMs = DateTime.now().millisecondsSinceEpoch;
          _isBusy = false;
          latestResult = workerResult.detection;
          latestRecognitionResults = workerResult.recognitionResults;
          latestWorkerResult = workerResult;
          latestPipelineMs = workerResult.totalPipelineMs;
          latestYuvMs = workerResult.yuvConversionMs;
          latestScrfdMs = workerResult.scrfdMs;
          latestAlignMs = workerResult.alignMs;
          latestEmbedMs = workerResult.embedMs;
          latestSearchMs = workerResult.searchMs;
          latestTrackingMs = workerResult.trackingMs;
          
          if (kUseContinuousFrameLatch && _hasPendingFrame) {
            // Latch is armed: immediately send the newest frame to the background worker
            final request = AIWorkerFrameRequest(
              yBuffer: TransferableTypedData.fromList([_pendingY!]),
              uBuffer: TransferableTypedData.fromList([_pendingU!]),
              vBuffer: TransferableTypedData.fromList([_pendingV!]),
              yRowStride: _pendingYRowStride,
              uvRowStride: _pendingUvRowStride,
              uvPixelStride: _pendingUvPixelStride,
              width: _pendingWidth,
              height: _pendingHeight,
              sensorOrientation: _pendingSensorOrientation,
              frameId: _pendingFrameId,
              cameraEntryMs: _pendingCameraEntryMs,
              cameraEntryMicro: _pendingCameraEntryMicro,
            );
            request.dispatchMs = DateTime.now().millisecondsSinceEpoch;
            request.dispatchMicro = globalUiClock.elapsedMicroseconds;
            _sendPort!.send([_receivePort.sendPort, request]);
            _hasPendingFrame = false;
            latchProcessed++;
            _isBusy = true;
          } else {
            _isBusy = false;
          }
          
          final int nextDispatchMs = DateTime.now().millisecondsSinceEpoch;
          
          final int cameraToDispatch = message.dispatchMs - message.cameraEntryMs;
          final int dispatchToWorker = message.workerStartMs - message.dispatchMs;
          final int yuvDuration = (message.yuvEndMicro - message.yuvStartMicro) ~/ 1000;
          final int scrfdDuration = (message.scrfdEndMicro - message.scrfdStartMicro) ~/ 1000;
          final int workerProcessing = message.workerEndMs - message.workerStartMs;
          final int workerToUi = uiReceiveMs - message.workerEndMs;
          final int totalCycle = nextDispatchMs - message.workerStartMs;

          _diagFramesProcessed++;

          bool isStall = totalCycle > 200 || scrfdDuration > 200 || workerProcessing > 200 || cameraToDispatch > 100 || dispatchToWorker > 100 || workerToUi > 100;
          
          if (isStall) {
            _diagStallCycles++;
            if (message.frameId > _diagWorstStallFrameId) _diagWorstStallFrameId = message.frameId;
            debugPrint('[PIPELINE_STALL] frame_id=${message.frameId} '
                'camera_to_dispatch=${cameraToDispatch}ms '
                'dispatch_to_worker=${dispatchToWorker}ms '
                'yuv=${yuvDuration}ms '
                'scrfd=${scrfdDuration}ms '
                'worker_processing=${workerProcessing}ms '
                'worker_to_ui=${workerToUi}ms '
                'total_cycle=${totalCycle}ms');
          } else {
            _diagNormalCycles++;
            _diagSumNormalCycle += totalCycle;
            _diagSumNormalScrfd += scrfdDuration;
            _diagSumNormalYuv += yuvDuration;
          }

          if (totalCycle > _diagMaxTotalCycle) _diagMaxTotalCycle = totalCycle;
          if (cameraToDispatch > _diagMaxCameraToDispatch) _diagMaxCameraToDispatch = cameraToDispatch;
          if (dispatchToWorker > _diagMaxDispatchToWorker) _diagMaxDispatchToWorker = dispatchToWorker;
          if (yuvDuration > _diagMaxYuv) _diagMaxYuv = yuvDuration;
          if (scrfdDuration > _diagMaxScrfd) _diagMaxScrfd = scrfdDuration;
          if (workerProcessing > _diagMaxWorkerProcessing) _diagMaxWorkerProcessing = workerProcessing;
          if (workerToUi > _diagMaxWorkerToUi) _diagMaxWorkerToUi = workerToUi;

          final now = DateTime.now();
          if (now.difference(_lastDiagTime).inMilliseconds >= 2000 && _diagFramesProcessed > 0) {
            final avgCycle = _diagNormalCycles > 0 ? _diagSumNormalCycle ~/ _diagNormalCycles : 0;
            final avgScrfd = _diagNormalCycles > 0 ? _diagSumNormalScrfd ~/ _diagNormalCycles : 0;
            final avgYuv = _diagNormalCycles > 0 ? _diagSumNormalYuv ~/ _diagNormalCycles : 0;

            debugPrint('[PIPELINE_DIAG_V2] '
                'normal_cycles=$_diagNormalCycles stall_cycles=$_diagStallCycles '
                'avg_total_cycle=$avgCycle avg_scrfd=$avgScrfd avg_yuv=$avgYuv '
                'max_total_cycle=$_diagMaxTotalCycle max_camera_to_dispatch=$_diagMaxCameraToDispatch '
                'max_dispatch_to_worker=$_diagMaxDispatchToWorker max_yuv=$_diagMaxYuv '
                'max_scrfd=$_diagMaxScrfd max_worker_processing=$_diagMaxWorkerProcessing '
                'max_worker_to_ui=$_diagMaxWorkerToUi worst_stall_frame=$_diagWorstStallFrameId');

            _diagFramesReceived = 0;
            _diagFramesProcessed = 0;
            _diagFramesReplaced = 0;
            _diagNormalCycles = 0;
            _diagStallCycles = 0;
            _diagMaxTotalCycle = 0;
            _diagMaxCameraToDispatch = 0;
            _diagMaxDispatchToWorker = 0;
            _diagMaxYuv = 0;
            _diagMaxScrfd = 0;
            _diagMaxWorkerProcessing = 0;
            _diagMaxWorkerToUi = 0;
            _diagSumNormalCycle = 0;
            _diagSumNormalScrfd = 0;
            _diagSumNormalYuv = 0;
            _diagWorstStallFrameId = -1;
            _lastDiagTime = now;
          }

          // Worker Stage Accumulation
          _workerStageFrames++;
          _wsSumYuv += workerResult.yuvConversionMs;
          _wsSumScrfd += workerResult.scrfdMs;
          _wsSumAlign += workerResult.alignMs;
          _wsSumEmbed += workerResult.embedMs;
          _wsSumSearch += workerResult.searchMs;
          _wsSumTrack += workerResult.trackingMs;
          _wsSumTotal += workerResult.totalPipelineMs;

          if (workerResult.yuvConversionMs > _wsMaxYuv) _wsMaxYuv = workerResult.yuvConversionMs;
          if (workerResult.scrfdMs > _wsMaxScrfd) _wsMaxScrfd = workerResult.scrfdMs;
          if (workerResult.alignMs > _wsMaxAlign) _wsMaxAlign = workerResult.alignMs;
          if (workerResult.embedMs > _wsMaxEmbed) _wsMaxEmbed = workerResult.embedMs;
          if (workerResult.searchMs > _wsMaxSearch) _wsMaxSearch = workerResult.searchMs;
          if (workerResult.trackingMs > _wsMaxTrack) _wsMaxTrack = workerResult.trackingMs;
          if (workerResult.totalPipelineMs > _wsMaxTotal) {
            _wsMaxTotal = workerResult.totalPipelineMs;
            _wsWorstFrameId = workerResult.frameId;
          }

          if (now.difference(_lastWorkerStageDiagTime).inMilliseconds >= 2000 && _workerStageFrames > 0) {
            _lastWorkerStageDiagTime = now;
            
            final int avgYuv = _wsSumYuv ~/ _workerStageFrames;
            final int avgScrfd = _wsSumScrfd ~/ _workerStageFrames;
            final int avgAlign = _wsSumAlign ~/ _workerStageFrames;
            final int avgEmbed = _wsSumEmbed ~/ _workerStageFrames;
            final int avgSearch = _wsSumSearch ~/ _workerStageFrames;
            final int avgTrack = _wsSumTrack ~/ _workerStageFrames;
            final int avgTotal = _wsSumTotal ~/ _workerStageFrames;

            debugPrint('[WORKER_STAGE_SUMMARY] frames_processed=$_workerStageFrames '
                'avg: yuv=$avgYuv scrfd=$avgScrfd align=$avgAlign embed=$avgEmbed search=$avgSearch track=$avgTrack total=$avgTotal '
                'max: yuv=$_wsMaxYuv scrfd=$_wsMaxScrfd align=$_wsMaxAlign embed=$_wsMaxEmbed search=$_wsMaxSearch track=$_wsMaxTrack total=$_wsMaxTotal '
                'worst_frame=$_wsWorstFrameId');

            _workerStageFrames = 0;
            _wsSumYuv = 0;
            _wsSumScrfd = 0;
            _wsSumAlign = 0;
            _wsSumEmbed = 0;
            _wsSumSearch = 0;
            _wsSumTrack = 0;
            _wsSumTotal = 0;
            _wsMaxYuv = 0;
            _wsMaxScrfd = 0;
            _wsMaxAlign = 0;
            _wsMaxEmbed = 0;
            _wsMaxSearch = 0;
            _wsMaxTrack = 0;
            _wsMaxTotal = 0;
            _wsWorstFrameId = -1;
          }
        }
      });

      _isReady = true;
    } catch (e) {
      debugPrint('❌ [AI_WORKER] Failed to spawn isolate: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Synchronize updated vector index items into the worker isolate.
  void updateVectorIndex(List<VectorIndexItem> items) {
    if (!_isReady || _sendPort == null) return;
    _sendPort!.send([_receivePort.sendPort, AIWorkerUpdateVectorIndexMessage(items: items)]);
  }

  /// Reset the face tracker inside the worker isolate.
  void resetTracker() {
    if (!_isReady || _sendPort == null) return;
    _sendPort!.send([_receivePort.sendPort, AIWorkerResetTrackerMessage()]);
  }

  /// Pushes a camera frame to the worker.
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
    required int frameId,
    required int cameraEntryMs,
    required int cameraEntryMicro,
  }) {
    if (!_isReady || _sendPort == null) return;
    
    final int t0 = _cbSw.elapsedMicroseconds;

    latchReceived++;

    if (!kUseContinuousFrameLatch) {
      if (_isBusy) return;
      _isBusy = true;
      latchProcessed++;

      final int tTransStart = _cbSw.elapsedMicroseconds;
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
        frameId: frameId,
        cameraEntryMs: cameraEntryMs,
        cameraEntryMicro: cameraEntryMicro,
      );
      final int tTransEnd = _cbSw.elapsedMicroseconds;

      request.dispatchMs = DateTime.now().millisecondsSinceEpoch;
      request.dispatchMicro = globalUiClock.elapsedMicroseconds;

      final int tSendStart = _cbSw.elapsedMicroseconds;
      _sendPort!.send([_receivePort.sendPort, request]);
      final int tSendEnd = _cbSw.elapsedMicroseconds;

      lastCopyYUs = 0;
      lastCopyUUs = 0;
      lastCopyVUs = 0;
      lastCopyTotalUs = 0;
      lastPendingWriteUs = 0;
      lastTransferableCreateUs = tTransEnd - tTransStart;
      lastSendUs = tSendEnd - tSendStart;
      lastCallbackPathUs = tSendEnd - t0;
      _recordCallbackDiag();
      return;
    }

    // SINGLE-SLOT LATCH
    if (_isBusy) {
      if (_hasPendingFrame) {
        latchReplaced++;
      } else {
        latchReplaced++;
      }
      
      if (_pendingY == null || _pendingY!.length != yBytes.length) {
        _pendingY = Uint8List(yBytes.length);
      }
      if (_pendingU == null || _pendingU!.length != uBytes.length) {
        _pendingU = Uint8List(uBytes.length);
      }
      if (_pendingV == null || _pendingV!.length != vBytes.length) {
        _pendingV = Uint8List(vBytes.length);
      }
      
      final int tCopyYStart = _cbSw.elapsedMicroseconds;
      _pendingY!.setAll(0, yBytes);
      final int tCopyYEnd = _cbSw.elapsedMicroseconds;

      _pendingU!.setAll(0, uBytes);
      final int tCopyUEnd = _cbSw.elapsedMicroseconds;

      _pendingV!.setAll(0, vBytes);
      final int tCopyVEnd = _cbSw.elapsedMicroseconds;

      final int tPendStart = _cbSw.elapsedMicroseconds;
      _pendingYRowStride = yRowStride;
      _pendingUvRowStride = uvRowStride;
      _pendingUvPixelStride = uvPixelStride;
      _pendingWidth = width;
      _pendingHeight = height;
      _pendingSensorOrientation = sensorOrientation;
      _pendingFrameId = frameId;
      _pendingCameraEntryMs = cameraEntryMs;
      _pendingCameraEntryMicro = cameraEntryMicro;
      _hasPendingFrame = true;
      final int tPendEnd = _cbSw.elapsedMicroseconds;

      lastCopyYUs = tCopyYEnd - tCopyYStart;
      lastCopyUUs = tCopyUEnd - tCopyYEnd;
      lastCopyVUs = tCopyVEnd - tCopyUEnd;
      lastCopyTotalUs = tCopyVEnd - tCopyYStart;
      lastPendingWriteUs = tPendEnd - tPendStart;
      lastTransferableCreateUs = 0;
      lastSendUs = 0;
      lastCallbackPathUs = tPendEnd - t0;
      _recordCallbackDiag();
    } else {
      _isBusy = true;
      latchProcessed++;

      final int tTransStart = _cbSw.elapsedMicroseconds;
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
        frameId: frameId,
        cameraEntryMs: cameraEntryMs,
        cameraEntryMicro: cameraEntryMicro,
      );
      final int tTransEnd = _cbSw.elapsedMicroseconds;

      request.dispatchMs = DateTime.now().millisecondsSinceEpoch;
      request.dispatchMicro = globalUiClock.elapsedMicroseconds;

      final int tSendStart = _cbSw.elapsedMicroseconds;
      _sendPort!.send([_receivePort.sendPort, request]);
      final int tSendEnd = _cbSw.elapsedMicroseconds;

      lastCopyYUs = 0;
      lastCopyUUs = 0;
      lastCopyVUs = 0;
      lastCopyTotalUs = 0;
      lastPendingWriteUs = 0;
      lastTransferableCreateUs = tTransEnd - tTransStart;
      lastSendUs = tSendEnd - tSendStart;
      lastCallbackPathUs = tSendEnd - t0;
      _recordCallbackDiag();
    }
  }

  void _recordCallbackDiag() {
    final bool valid = lastCopyYUs >= 0 && lastCopyYUs < 1000000 &&
        lastCopyUUs >= 0 && lastCopyUUs < 1000000 &&
        lastCopyVUs >= 0 && lastCopyVUs < 1000000 &&
        lastCopyTotalUs >= 0 && lastCopyTotalUs < 1000000 &&
        lastPendingWriteUs >= 0 && lastPendingWriteUs < 1000000 &&
        lastTransferableCreateUs >= 0 && lastTransferableCreateUs < 1000000 &&
        lastSendUs >= 0 && lastSendUs < 1000000 &&
        lastCallbackPathUs >= 0 && lastCallbackPathUs < 1000000;

    if (!valid) {
      debugPrint('[CAMERA_CALLBACK_STAGE_INVALID] '
          'copy_y=${lastCopyYUs}us copy_u=${lastCopyUUs}us copy_v=${lastCopyVUs}us '
          'copy_total=${lastCopyTotalUs}us pending_write=${lastPendingWriteUs}us '
          'transferable_create=${lastTransferableCreateUs}us send=${lastSendUs}us '
          'callback_path=${lastCallbackPathUs}us');
      return;
    }

    _cbDiagFrames++;

    if (lastCallbackPathUs > 5000) {
      debugPrint('[CAMERA_CALLBACK_STAGE_DIAG] '
          'copy_y=${lastCopyYUs}us copy_u=${lastCopyUUs}us copy_v=${lastCopyVUs}us '
          'copy_total=${lastCopyTotalUs}us pending_write=${lastPendingWriteUs}us '
          'transferable_create=${lastTransferableCreateUs}us send=${lastSendUs}us '
          'callback_total=${lastCallbackPathUs}us');
    }
    _cbSumCopyTotal += lastCopyTotalUs;
    _cbSumPendingWrite += lastPendingWriteUs;
    _cbSumTransferableCreate += lastTransferableCreateUs;
    _cbSumSend += lastSendUs;
    _cbSumCallbackPath += lastCallbackPathUs;
    if (lastCopyTotalUs > _cbMaxCopyTotal) _cbMaxCopyTotal = lastCopyTotalUs;
    if (lastPendingWriteUs > _cbMaxPendingWrite) _cbMaxPendingWrite = lastPendingWriteUs;
    if (lastTransferableCreateUs > _cbMaxTransferableCreate) _cbMaxTransferableCreate = lastTransferableCreateUs;
    if (lastSendUs > _cbMaxSend) _cbMaxSend = lastSendUs;
    if (lastCallbackPathUs > _cbMaxCallbackPath) _cbMaxCallbackPath = lastCallbackPathUs;
    _cbCopyTotalSamples.add(lastCopyTotalUs);
    _cbCallbackPathSamples.add(lastCallbackPathUs);

    final now = DateTime.now();
    if (_cbLastSummaryTime.millisecondsSinceEpoch == 0) {
      _cbLastSummaryTime = now;
    } else if (now.difference(_cbLastSummaryTime).inMilliseconds >= 2000 && _cbDiagFrames > 0) {
      _cbCopyTotalSamples.sort();
      _cbCallbackPathSamples.sort();
      final int p95CopyTotal = _cbCopyTotalSamples[(_cbCopyTotalSamples.length * 0.95).floor()];
      final int p95CallbackPath = _cbCallbackPathSamples[(_cbCallbackPathSamples.length * 0.95).floor()];

      debugPrint('\n[CAMERA_CALLBACK_STAGE_SUMMARY]\n'
          'frames=$_cbDiagFrames\n'
          'avg_copy_total=${_cbSumCopyTotal ~/ _cbDiagFrames}us\n'
          'p95_copy_total=${p95CopyTotal}us\n'
          'max_copy_total=${_cbMaxCopyTotal}us\n'
          'avg_pending_write=${_cbSumPendingWrite ~/ _cbDiagFrames}us\n'
          'max_pending_write=${_cbMaxPendingWrite}us\n'
          'avg_transferable_create=${_cbSumTransferableCreate ~/ _cbDiagFrames}us\n'
          'max_transferable_create=${_cbMaxTransferableCreate}us\n'
          'avg_send=${_cbSumSend ~/ _cbDiagFrames}us\n'
          'max_send=${_cbMaxSend}us\n'
          'avg_callback_path=${_cbSumCallbackPath ~/ _cbDiagFrames}us\n'
          'p95_callback_path=${p95CallbackPath}us\n'
          'max_callback_path=${_cbMaxCallbackPath}us\n'
          'camera_fps=${latestCamFps.toStringAsFixed(1)}\n'
          'processing_fps=${latestProcFps.toStringAsFixed(1)}\n'
          'frames_received=$latchReceived\n'
          'frames_replaced=$latchReplaced\n'
          'worker_busy=$_isBusy\n');

      _cbDiagFrames = 0;
      _cbSumCopyTotal = 0;
      _cbSumPendingWrite = 0;
      _cbSumTransferableCreate = 0;
      _cbSumSend = 0;
      _cbSumCallbackPath = 0;
      _cbMaxCopyTotal = 0;
      _cbMaxPendingWrite = 0;
      _cbMaxTransferableCreate = 0;
      _cbMaxSend = 0;
      _cbMaxCallbackPath = 0;
      _cbCopyTotalSamples.clear();
      _cbCallbackPathSamples.clear();
      _cbLastSummaryTime = now;
    }
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
  final Uint8List detectorModelBytes;
  final Uint8List embeddingModelBytes;
  final List<VectorIndexItem> initialVectorIndexItems;
  final double similarityThreshold;
  final RootIsolateToken rootToken;

  _WorkerInitData({
    required this.sendPort,
    required this.detectorModelBytes,
    required this.embeddingModelBytes,
    required this.initialVectorIndexItems,
    this.similarityThreshold = 0.45,
    required this.rootToken,
  });
}

/// Entrypoint for the background isolate
Future<void> _workerEntrypoint(_WorkerInitData initData) async {
  final Stopwatch globalWorkerClock = Stopwatch()..start();
  
  debugPrint('✅ [AI_WORKER] Started on isolate: ${Isolate.current.debugName}');

  BackgroundIsolateBinaryMessenger.ensureInitialized(initData.rootToken);

  // 1. Initialize ONNX runtime environment
  OrtEnv.instance.init();
  
  // 2. Initialize Face Detector (SCRFD)
  dynamic detector = kUseExperimentalScrfd 
      ? ExperimentalSCRFDDetector() 
      : MobileFaceDetector();
  await detector.initializeFromBytes(initData.detectorModelBytes);
  debugPrint('✅ [AI_WORKER] SCRFD face detector initialized');

  // 3. Initialize Face Embedding Model (w600k_mbf.onnx) ONCE in worker isolate
    // PHASE 18 BASELINE: CPUExecutionProvider + ortEnableAll (No XNNPACK)
  final embedSessionOptions = OrtSessionOptions();
  embedSessionOptions.setIntraOpNumThreads(1);
  embedSessionOptions.setInterOpNumThreads(1);
  embedSessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
  
  final String selectedProvider = 'CPUExecutionProvider';
  final bool xnnpackActive = false;

  final OrtSession embedSession = OrtSession.fromBuffer(
    initData.embeddingModelBytes,
    embedSessionOptions,
  );
  embedSessionOptions.release();
  final OrtRunOptions embedRunOptions = OrtRunOptions();
  final String embedInputName = embedSession.inputNames.isNotEmpty
      ? embedSession.inputNames[0]
      : 'input.1';
  
  debugPrint('✅ [AI_WORKER] W600K_MBF session initialized (Phase 18 Baseline: CPU + ortEnableAll)');

  debugPrint('\n[EMBED_RUNTIME_CONFIG]\n'
      'execution_provider=$selectedProvider\n'
      'xnnpack_attach_result=$xnnpackActive\n'
      'selected_execution_provider=$selectedProvider\n'
      'intra_op_threads=1\n'
      'inter_op_threads=1\n'
      'graph_optimization=ortEnableAll\n');
  // Controlled startup benchmark (25 runs: 5 warmup + 20 benchmarked runs on clean model)
  final benchmarkTensor = Float32List(1 * 3 * 112 * 112);
  final benchInput = OrtValueTensor.createTensorWithDataList(benchmarkTensor, [1, 3, 112, 112]);
  final List<int> benchLatencies = [];
  for (int b = 0; b < 25; b++) {
    final bSw = Stopwatch()..start();
    final bOut = embedSession.run(embedRunOptions, {embedInputName: benchInput});
    bSw.stop();
    bOut[0]?.release();
    if (b >= 5) {
      benchLatencies.add(bSw.elapsedMicroseconds);
    }
  }
  benchInput.release();

  benchLatencies.sort();
  final int benchCount = benchLatencies.length;
  final double benchMinMs = (benchLatencies.first) / 1000.0;
  final double benchAvgMs = (benchLatencies.reduce((a, b) => a + b) / benchCount) / 1000.0;
  final double benchMedianMs = (benchLatencies[benchCount ~/ 2]) / 1000.0;
  final double benchP95Ms = (benchLatencies[(benchCount * 0.95).floor()]) / 1000.0;
  final double benchMaxMs = (benchLatencies.last) / 1000.0;

  debugPrint('\n[EMBED_RUNTIME_BENCHMARK]\n'
      'benchmark_type=controlled_isolated_startup\n'
      'samples=$benchCount\n'
      'min_ms=${benchMinMs.toStringAsFixed(2)}\n'
      'avg_ms=${benchAvgMs.toStringAsFixed(2)}\n'
      'median_ms=${benchMedianMs.toStringAsFixed(2)}\n'
      'p95_ms=${benchP95Ms.toStringAsFixed(2)}\n'
      'max_ms=${benchMaxMs.toStringAsFixed(2)}\n');

  // 4. Initialize isolate-local Vector Index and Multi-Face Tracker
  final vectorIndex = VectorIndexManager();
  vectorIndex.setIndexItems(initData.initialVectorIndexItems);
  final faceTracker = FaceTracker();
  final double similarityThreshold = initData.similarityThreshold;
  debugPrint('✅ [AI_WORKER] Vector index initialized with ${initData.initialVectorIndexItems.length} vectors in worker isolate');

  // 5. Create receive port and signal ready to UI isolate
  final port = ReceivePort();
  initData.sendPort.send(port.sendPort);

  // 6. Setup isolate-owned reusable buffers
  Float32List? reusableTensor;
  Uint8List? reusableRgb;

  // Embed Stage Detailed Profiling
  int embedDiagSamples = 0;
  int sumTensorCreateUs = 0;
  int maxTensorCreateUs = 0;
  int sumOnnxRunUs = 0;
  int maxOnnxRunUs = 0;
  int sumOutputExtractUs = 0;
  int maxOutputExtractUs = 0;
  int sumNormalizeUs = 0;
  int maxNormalizeUs = 0;
  int sumEmbedTotalUs = 0;
  int maxEmbedTotalUs = 0;
  final List<int> tensorCreateSamples = [];
  final List<int> onnxRunSamples = [];
  final List<int> outputExtractSamples = [];
  final List<int> normalizeSamples = [];
  final List<int> embedTotalSamples = [];
  DateTime lastEmbedSummaryTime = DateTime.fromMillisecondsSinceEpoch(0);

  // 7. Process incoming messages
  await for (final message in port) {
    if (message is List && message.length == 2) {
      final replyPort = message[0] as SendPort;
      final dynamic payload = message[1];

      // Handle Vector Index Dynamic Updates
      if (payload is AIWorkerUpdateVectorIndexMessage) {
        vectorIndex.setIndexItems(payload.items);
        debugPrint('⚡ [AI_WORKER] Vector index updated with ${payload.items.length} items in worker isolate');
        continue;
      }

      // Handle Tracker Reset
      if (payload is AIWorkerResetTrackerMessage) {
        faceTracker.reset();
        debugPrint('🧹 [AI_WORKER] Face tracker reset in worker isolate');
        continue;
      }

      // Handle Frame Inference Request
      if (payload is AIWorkerFrameRequest) {
        final req = payload;
        final sw = Stopwatch()..start();
        final workerStartMs = DateTime.now().millisecondsSinceEpoch;
        final int workerStartMicro = globalWorkerClock.elapsedMicroseconds;

        try {
          final yBuffer = req.yBuffer.materialize().asUint8List();
          final uBuffer = req.uBuffer.materialize().asUint8List();
          final vBuffer = req.vBuffer.materialize().asUint8List();

          // 1. Convert YUV to Tensor & RGB (320x320 target)
          final int targetSize = kUseExperimentalScrfd ? 320 : 640;
          final int yuvStartMicro = globalWorkerClock.elapsedMicroseconds;
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
            targetSize: targetSize,
            reuseTensor: reusableTensor,
            reuseRgbBytes: reusableRgb,
          );
          final int yuvEndMicro = globalWorkerClock.elapsedMicroseconds;
          reusableTensor = tensorResult.tensor;
          reusableRgb = tensorResult.rgbBytes;
          final int yuvTime = tensorResult.conversionTimeMs;

          // 2. Run SCRFD Inference in worker isolate
          final int scrfdStartMicro = globalWorkerClock.elapsedMicroseconds;
          final detection = await detector.detectFaces(
            detectorTensor: tensorResult.tensor,
            tensorSize: targetSize,
            scaleRatio: tensorResult.scaleRatio,
            padX: tensorResult.padX,
            padY: tensorResult.padY,
            originalWidth: tensorResult.originalWidth,
            originalHeight: tensorResult.originalHeight,
            frameId: req.frameId,
            workerDelayMicro: scrfdStartMicro - workerStartMicro,
          );
          final int scrfdEndMicro = globalWorkerClock.elapsedMicroseconds;
          final int scrfdTime = detection.processTimeMs;

          // 3. Run Recognition (Tracker-First Cache -> Alignment + W600K_MBF ONNX Embedding + Vector Search)
          int totalAlignMicro = 0;
          int totalEmbedMicro = 0;
          int totalSearchMicro = 0;
          int cachedFaces = 0;
          final rawResults = <LocalRecognitionResult>[];
          if (detection.faces.isNotEmpty) {
            for (int i = 0; i < detection.faces.length; i++) {
              final face = detection.faces[i];

              // --- PHASE 23: TRACKER-FIRST CACHING ---
              final cachedIdentity = faceTracker.getCachedIdentity(face.boundingBox);
              String? personId;
              String displayName = 'Unknown';
              double similarity = 0.0;
              bool isKnown = false;
              String state = 'unknown';

              if (cachedIdentity != null) {
                // SKIP Embedding & Search! Reuse cached identity.
                personId = cachedIdentity.personId;
                displayName = cachedIdentity.displayName;
                similarity = cachedIdentity.similarity;
                isKnown = cachedIdentity.isKnown;
                state = 'recognized';
                cachedFaces++;
              } else {
                // --- RUN FULL EMBEDDING PIPELINE ---
                
                // 3a. 5-Point Face Alignment to 112x112 NCHW FloatTensor
                final int alignStart = globalWorkerClock.elapsedMicroseconds;
                final List<List<double>> landmarks = face.landmarks ??
                    [
                      [face.boundingBox[0] * tensorResult.originalWidth, face.boundingBox[1] * tensorResult.originalHeight],
                      [face.boundingBox[2] * tensorResult.originalWidth, face.boundingBox[1] * tensorResult.originalHeight],
                      [(face.boundingBox[0] + face.boundingBox[2]) / 2 * tensorResult.originalWidth, (face.boundingBox[1] + face.boundingBox[3]) / 2 * tensorResult.originalHeight],
                      [face.boundingBox[0] * tensorResult.originalWidth, face.boundingBox[3] * tensorResult.originalHeight],
                      [face.boundingBox[2] * tensorResult.originalWidth, face.boundingBox[3] * tensorResult.originalHeight],
                    ];
                final Float32List alignedTensor = FaceAlignmentService.alignFaceToRgbTensor(
                  srcRgbBytes: tensorResult.rgbBytes,
                  srcWidth: tensorResult.originalWidth,
                  srcHeight: tensorResult.originalHeight,
                  landmarks: landmarks,
                );
                final int alignEnd = globalWorkerClock.elapsedMicroseconds;
                totalAlignMicro += (alignEnd - alignStart);
                
                // 3b. W600K_MBF ONNX Embedding Inference in worker isolate
                final int tTensorStart = globalWorkerClock.elapsedMicroseconds;
                final inputTensor = OrtValueTensor.createTensorWithDataList(
                  alignedTensor,
                  [1, 3, 112, 112],
                );
                final int tTensorEnd = globalWorkerClock.elapsedMicroseconds;
                final int tensorCreateUs = tTensorEnd - tTensorStart;
                final int tRunStart = globalWorkerClock.elapsedMicroseconds;
                final outputs = embedSession.run(embedRunOptions, {embedInputName: inputTensor});
                final int tRunEnd = globalWorkerClock.elapsedMicroseconds;
                final int onnxRunUs = tRunEnd - tRunStart;
                inputTensor.release();
                final int tExtractStart = globalWorkerClock.elapsedMicroseconds;
                Float32List? embedding;
                if (outputs.isNotEmpty && outputs[0] != null) {
                  final rawValue = outputs[0]!.value;
                  outputs[0]!.release();
                  List<double> rawFloats;
                  if (rawValue is List) {
                    rawFloats = rawValue.expand((e) => e is List ? e : [e]).cast<double>().toList();
                  } else if (rawValue is Float32List) {
                    rawFloats = rawValue.toList();
                  } else {
                    rawFloats = [];
                  }
                  if (rawFloats.isNotEmpty) {
                    final Float32List emb = Float32List(512);
                    for (int k = 0; k < math.min(512, rawFloats.length); k++) {
                      emb[k] = rawFloats[k];
                    }
                    embedding = emb;
                  }
                }
                final int tExtractEnd = globalWorkerClock.elapsedMicroseconds;
                final int outputExtractUs = tExtractEnd - tExtractStart;
                
                // L2 Normalization
                final int tNormStart = globalWorkerClock.elapsedMicroseconds;
                if (embedding != null) {
                  double normSq = 0.0;
                  for (int k = 0; k < 512; k++) {
                    normSq += embedding[k] * embedding[k];
                  }
                  final double norm = math.sqrt(normSq);
                  if (norm > 0 && !norm.isNaN) {
                    for (int k = 0; k < 512; k++) {
                      embedding[k] = embedding[k] / norm;
                    }
                  }
                }
                final int tNormEnd = globalWorkerClock.elapsedMicroseconds;
                final int normalizeUs = tNormEnd - tNormStart;
                final int embedTotalUs = tNormEnd - tTensorStart;
                totalEmbedMicro += embedTotalUs;
                
                // Accumulate embedding detailed telemetry
                embedDiagSamples++;
                sumTensorCreateUs += tensorCreateUs;
                sumOnnxRunUs += onnxRunUs;
                sumOutputExtractUs += outputExtractUs;
                sumNormalizeUs += normalizeUs;
                sumEmbedTotalUs += embedTotalUs;
                if (tensorCreateUs > maxTensorCreateUs) maxTensorCreateUs = tensorCreateUs;
                if (onnxRunUs > maxOnnxRunUs) maxOnnxRunUs = onnxRunUs;
                if (outputExtractUs > maxOutputExtractUs) maxOutputExtractUs = outputExtractUs;
                if (normalizeUs > maxNormalizeUs) maxNormalizeUs = normalizeUs;
                if (embedTotalUs > maxEmbedTotalUs) maxEmbedTotalUs = embedTotalUs;
                tensorCreateSamples.add(tensorCreateUs);
                onnxRunSamples.add(onnxRunUs);
                outputExtractSamples.add(outputExtractUs);
                normalizeSamples.add(normalizeUs);
                embedTotalSamples.add(embedTotalUs);
                
                // 3c. Vector Similarity Search against in-memory index
                final int searchStart = globalWorkerClock.elapsedMicroseconds;
                if (embedding != null) {
                  final matches = vectorIndex.search(embedding, topK: 1);
                  if (matches.isEmpty) {
                    debugPrint('[SEARCH_DIAG] matches=0 index_size=${vectorIndex.getIndexItems().length} (Database is empty or no match)');
                  } else {
                    final match = matches.first;
                    similarity = match.similarity;
                    debugPrint('[SEARCH_DIAG] top_similarity=${similarity.toStringAsFixed(4)} threshold=$similarityThreshold person=${match.personName}');
                    if (similarity >= similarityThreshold) {
                      personId = match.personId.toString();
                      displayName = match.personName;
                      isKnown = true;
                      state = 'recognized';
                    }
                  }
                }
                final int searchEnd = globalWorkerClock.elapsedMicroseconds;
                totalSearchMicro += (searchEnd - searchStart);
              }

              // Construct raw un-tracked recognition result for this face
              rawResults.add(LocalRecognitionResult(
                trackId: i,
                personId: personId,
                displayName: displayName,
                similarity: similarity,
                isKnown: isKnown,
                boundingBox: face.boundingBox,
                timestamp: detection.timestamp,
                state: state,
              ));
            }
          }
          // Optional: Log how many faces were cached this frame
          if (cachedFaces > 0) {
            debugPrint('[PHASE_23_CACHE] cached=$cachedFaces uncached=${detection.faces.length - cachedFaces}');
          }

          // 4. Update Face Tracker in worker isolate
          final int trackStart = globalWorkerClock.elapsedMicroseconds;
          final activeTracks = faceTracker.updateTracks(rawResults);
          final int trackEnd = globalWorkerClock.elapsedMicroseconds;
          final int trackingMicro = trackEnd - trackStart;

          sw.stop();
          final int workerEndMicro = globalWorkerClock.elapsedMicroseconds;
          final int workerEndMs = DateTime.now().millisecondsSinceEpoch;

          final int alignMs = totalAlignMicro ~/ 1000;
          final int embedMs = totalEmbedMicro ~/ 1000;
          final int searchMs = totalSearchMicro ~/ 1000;
          final int trackingMs = trackingMicro ~/ 1000;
          final int totalPipelineMs = sw.elapsedMilliseconds;

          // 5. Send compact results back to UI isolate (NO rgbBytes!)
          replyPort.send(AIWorkerResult(
            detection: detection,
            recognitionResults: activeTracks,
            totalPipelineMs: totalPipelineMs,
            yuvConversionMs: yuvTime,
            scrfdMs: scrfdTime,
            alignMs: alignMs,
            embedMs: embedMs,
            searchMs: searchMs,
            trackingMs: trackingMs,
            frameId: req.frameId,
            cameraEntryMs: req.cameraEntryMs,
            cameraEntryMicro: req.cameraEntryMicro,
            dispatchMs: req.dispatchMs,
            dispatchMicro: req.dispatchMicro,
            workerStartMs: workerStartMs,
            workerStartMicro: workerStartMicro,
            yuvStartMicro: yuvStartMicro,
            yuvEndMicro: yuvEndMicro,
            scrfdStartMicro: scrfdStartMicro,
            scrfdEndMicro: scrfdEndMicro,
            workerEndMs: workerEndMs,
            workerEndMicro: workerEndMicro,
            workerResultStartMicro: workerEndMicro,
            workerResultEndMicro: workerEndMicro,
          ));

          // Periodic Detailed Embedding Stage Telemetry
          final now = DateTime.now();
          if (embedDiagSamples >= 10 && now.difference(lastEmbedSummaryTime).inMilliseconds >= 2000) {
            tensorCreateSamples.sort();
            onnxRunSamples.sort();
            outputExtractSamples.sort();
            normalizeSamples.sort();
            embedTotalSamples.sort();

            final int p95TensorCreate = tensorCreateSamples[(tensorCreateSamples.length * 0.95).floor()];
            final int p95OnnxRun = onnxRunSamples[(onnxRunSamples.length * 0.95).floor()];
            final int p95OutputExtract = outputExtractSamples[(outputExtractSamples.length * 0.95).floor()];
            final int p95Normalize = normalizeSamples[(normalizeSamples.length * 0.95).floor()];
            final int p95EmbedTotal = embedTotalSamples[(embedTotalSamples.length * 0.95).floor()];

            final String avgTensorCreate = (sumTensorCreateUs / embedDiagSamples / 1000.0).toStringAsFixed(2);
            final String p95TensorCreateMs = (p95TensorCreate / 1000.0).toStringAsFixed(2);
            final String maxTensorCreateMs = (maxTensorCreateUs / 1000.0).toStringAsFixed(2);

            final String avgOnnxRun = (sumOnnxRunUs / embedDiagSamples / 1000.0).toStringAsFixed(2);
            final String p95OnnxRunMs = (p95OnnxRun / 1000.0).toStringAsFixed(2);
            final String maxOnnxRunMs = (maxOnnxRunUs / 1000.0).toStringAsFixed(2);

            final String avgOutputExtract = (sumOutputExtractUs / embedDiagSamples / 1000.0).toStringAsFixed(2);
            final String p95OutputExtractMs = (p95OutputExtract / 1000.0).toStringAsFixed(2);

            final String avgNormalize = (sumNormalizeUs / embedDiagSamples / 1000.0).toStringAsFixed(2);
            final String p95NormalizeMs = (p95Normalize / 1000.0).toStringAsFixed(2);

            final String avgEmbedTotal = (sumEmbedTotalUs / embedDiagSamples / 1000.0).toStringAsFixed(2);
            final String p95EmbedTotalMs = (p95EmbedTotal / 1000.0).toStringAsFixed(2);
            final String maxEmbedTotalMs = (maxEmbedTotalUs / 1000.0).toStringAsFixed(2);

            final double onnxRatio = sumEmbedTotalUs > 0 ? (sumOnnxRunUs / sumEmbedTotalUs) * 100.0 : 0.0;
            final bool isDominant = onnxRatio >= 80.0;

            debugPrint('\n[EMBED_STAGE_DETAILED_SUMMARY]\n'
                'samples=$embedDiagSamples\n'
                'tensor_create_avg=${avgTensorCreate}ms\n'
                'tensor_create_p95=${p95TensorCreateMs}ms\n'
                'tensor_create_max=${maxTensorCreateMs}ms\n'
                'onnx_run_avg=${avgOnnxRun}ms\n'
                'onnx_run_p95=${p95OnnxRunMs}ms\n'
                'onnx_run_max=${maxOnnxRunMs}ms\n'
                'output_extract_avg=${avgOutputExtract}ms\n'
                'output_extract_p95=${p95OutputExtractMs}ms\n'
                'normalize_avg=${avgNormalize}ms\n'
                'normalize_p95=${p95NormalizeMs}ms\n'
                'embed_total_avg=${avgEmbedTotal}ms\n'
                'embed_total_p95=${p95EmbedTotalMs}ms\n'
                'embed_total_max=${maxEmbedTotalMs}ms\n'
                'onnx_run_ratio=${onnxRatio.toStringAsFixed(1)}%\n'
                'onnx_is_dominant=$isDominant\n'
                '\n[EMBED_RUNTIME_BENCHMARK]\n'
                'samples=$embedDiagSamples\n'
                'avg_ms=$avgEmbedTotal\n'
                'median_ms=${(embedTotalSamples[embedTotalSamples.length ~/ 2] / 1000.0).toStringAsFixed(2)}\n'
                'p95_ms=$p95EmbedTotalMs\n'
                'max_ms=$maxEmbedTotalMs\n');

            embedDiagSamples = 0;
            sumTensorCreateUs = 0;
            maxTensorCreateUs = 0;
            sumOnnxRunUs = 0;
            maxOnnxRunUs = 0;
            sumOutputExtractUs = 0;
            maxOutputExtractUs = 0;
            sumNormalizeUs = 0;
            maxNormalizeUs = 0;
            sumEmbedTotalUs = 0;
            maxEmbedTotalUs = 0;
            tensorCreateSamples.clear();
            onnxRunSamples.clear();
            outputExtractSamples.clear();
            normalizeSamples.clear();
            embedTotalSamples.clear();
            lastEmbedSummaryTime = now;
          }
        } catch (e, st) {
          debugPrint('❌ [AI_WORKER] Frame processing error: $e\n$st');
        }
      }
    }
  }
}
