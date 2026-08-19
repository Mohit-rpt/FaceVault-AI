import 'package:flutter/foundation.dart';
import 'ai_worker.dart';
import 'frame_processor.dart' show globalUiClock;

class PipelineProfiler {
  static final PipelineProfiler instance = PipelineProfiler._();
  PipelineProfiler._();

  int framesReceived = 0;
  int framesDispatched = 0;
  int framesProcessed = 0;
  int framesReplaced = 0;
  int framesDropped = 0;
  
  int validSamples = 0;
  int invalidSamples = 0;

  // Sums (in microseconds)
  int _sumCameraToDispatch = 0;
  int _sumDispatchToWorker = 0;
  int _sumScrfdToEmbedding = 0;
  int _sumScrfd = 0;
  int _sumAlign = 0;
  int _sumEmbed = 0;
  int _sumSearch = 0;
  int _sumResultDelivery = 0;
  int _sumTotal = 0;

  // Maxes (in microseconds)
  int _maxScrfd = 0;
  int _maxEmbed = 0;
  int _maxTotal = 0;

  DateTime _lastSummaryTime = DateTime.fromMillisecondsSinceEpoch(0);

  void recordPipelineEnd({
    required AIWorkerResult workerResult,
    required int recogStartMicro,
    required int recogEndMicro,
    required int maxAlignMicro,
    required int maxEmbedMicro,
    required int totalSearchMicro,
    required int totalConstructMicro,
  }) {
    framesProcessed++;

    // 1. Common monotonic origin for main isolate measurements
    final int cameraEntryMicro = workerResult.cameraEntryMicro;
    final int dispatchMicro = workerResult.dispatchMicro;
    final int uiReceiveMicro = workerResult.uiReceiveMicro ?? dispatchMicro;
    final int recogEndNowMicro = globalUiClock.elapsedMicroseconds;

    // 2. Common monotonic origin for worker isolate measurements
    final int workerStartMicro = workerResult.workerStartMicro;
    final int scrfdStartMicro = workerResult.scrfdStartMicro;
    final int scrfdEndMicro = workerResult.scrfdEndMicro;
    final int workerEndMicro = workerResult.workerResultEndMicro;

    // Calculate main isolate durations (using globalUiClock)
    final int cameraToDispatch = dispatchMicro - cameraEntryMicro;
    final int scrfdToEmbedding = recogStartMicro - uiReceiveMicro;
    final int recogToUi = recogEndNowMicro - recogEndMicro;
    final int total = recogEndNowMicro - cameraEntryMicro;

    // Calculate worker isolate durations (using globalWorkerClock)
    final int scrfd = scrfdEndMicro - scrfdStartMicro;
    final int workerTotal = workerEndMicro - workerStartMicro;

    // Estimate cross-isolate dispatch delay (assume symmetrical transit overhead)
    final int mainToWorkerToMain = uiReceiveMicro - dispatchMicro;
    int transitOverhead = mainToWorkerToMain - workerTotal;
    if (transitOverhead < 0) transitOverhead = 0;
    final int dispatchToWorker = transitOverhead ~/ 2;

    // Calculate exact inner stage durations
    final int align = maxAlignMicro;
    final int embed = maxEmbedMicro;
    final int search = totalSearchMicro;
    
    // Validate boundaries (0 to 5000 ms)
    bool isValid = true;
    void validate(String stage, int micro) {
      final int ms = micro ~/ 1000;
      if (ms < 0 || ms >= 5000) {
        isValid = false;
        debugPrint('[PIPELINE_PROFILER_INVALID] stage=$stage raw_value=$ms unit=ms reason="Out of bounds (0-4999)"');
      }
    }

    validate('camera_to_dispatch', cameraToDispatch);
    validate('dispatch_to_worker', dispatchToWorker);
    validate('scrfd', scrfd);
    validate('scrfd_to_embedding', scrfdToEmbedding);
    validate('alignment', align);
    validate('embedding', embed);
    validate('search', search);
    validate('result_delivery', recogToUi);
    validate('total', total);

    if (!isValid) {
      invalidSamples++;
      return; // Do not contaminate averages
    }

    validSamples++;

    // Add to sums
    _sumCameraToDispatch += cameraToDispatch;
    _sumDispatchToWorker += dispatchToWorker;
    _sumScrfdToEmbedding += scrfdToEmbedding;
    _sumScrfd += scrfd;
    _sumAlign += align;
    _sumEmbed += embed;
    _sumSearch += search;
    _sumResultDelivery += recogToUi;
    _sumTotal += total;

    // Update maxes
    if (scrfd > _maxScrfd) _maxScrfd = scrfd;
    if (embed > _maxEmbed) _maxEmbed = embed;
    if (total > _maxTotal) _maxTotal = total;

    // Log summary every 2 seconds
    final now = DateTime.now();
    if (now.difference(_lastSummaryTime).inMilliseconds >= 2000 && validSamples > 0) {
      final avgCameraToDispatch = (_sumCameraToDispatch / validSamples / 1000.0).toStringAsFixed(1);
      final avgDispatchToWorker = (_sumDispatchToWorker / validSamples / 1000.0).toStringAsFixed(1);
      final avgScrfdToEmbed = (_sumScrfdToEmbedding / validSamples / 1000.0).toStringAsFixed(1);
      
      final avgScrfd = (_sumScrfd / validSamples / 1000.0).toStringAsFixed(1);
      final avgAlign = (_sumAlign / validSamples / 1000.0).toStringAsFixed(1);
      final avgEmbed = (_sumEmbed / validSamples / 1000.0).toStringAsFixed(1);
      final avgSearch = (_sumSearch / validSamples / 1000.0).toStringAsFixed(1);
      final avgResultDelivery = (_sumResultDelivery / validSamples / 1000.0).toStringAsFixed(1);
      final avgTotal = (_sumTotal / validSamples / 1000.0).toStringAsFixed(1);

      debugPrint('\n[PIPELINE_THROUGHPUT_SUMMARY]\n'
          'frames_received=$framesReceived\n'
          'frames_processed=$framesProcessed\n'
          'frames_replaced=$framesReplaced\n'
          'frames_dropped=$framesDropped\n'
          'valid_samples=$validSamples\n'
          'invalid_samples=$invalidSamples\n'
          'avg_camera_to_dispatch=$avgCameraToDispatch\n'
          'avg_dispatch_to_worker=$avgDispatchToWorker\n'
          'avg_scrfd_to_embedding=$avgScrfdToEmbed\n'
          'avg_scrfd=$avgScrfd\n'
          'avg_alignment=$avgAlign\n'
          'avg_embedding=$avgEmbed\n'
          'avg_search=$avgSearch\n'
          'avg_result_delivery=$avgResultDelivery\n'
          'avg_total=$avgTotal\n'
          'max_scrfd=${_maxScrfd ~/ 1000}\n'
          'max_embedding=${_maxEmbed ~/ 1000}\n'
          'max_total=${_maxTotal ~/ 1000}\n');

      _resetSums();
      _lastSummaryTime = now;
    }
  }

  void _resetSums() {
    framesReceived = 0;
    framesDispatched = 0;
    framesProcessed = 0;
    framesReplaced = 0;
    framesDropped = 0;
    
    validSamples = 0;
    invalidSamples = 0;

    _sumCameraToDispatch = 0;
    _sumDispatchToWorker = 0;
    _sumScrfdToEmbedding = 0;
    _sumScrfd = 0;
    _sumAlign = 0;
    _sumEmbed = 0;
    _sumSearch = 0;
    _sumResultDelivery = 0;
    _sumTotal = 0;
    
    _maxScrfd = 0;
    _maxEmbed = 0;
    _maxTotal = 0;
  }
}
