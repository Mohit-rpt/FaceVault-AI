// lib/services/camera/frame_queue.dart

import 'dart:collection';
import 'package:camera/camera.dart';

/// Single item stored in FrameQueue with arrival metadata.
class FrameQueueItem {
  final CameraImage image;
  final DateTime arrivalTime;
  final int frameId;

  FrameQueueItem({
    required this.image,
    required this.arrivalTime,
    required this.frameId,
  });
}

/// Bounded Frame Queue prioritizing the newest frames and dropping stale frames.
///
/// Prevents memory leaks and latency lag when processing is slower than camera feed.
class FrameQueue {
  final int maxCapacity;
  final Queue<FrameQueueItem> _queue = Queue<FrameQueueItem>();

  int _enqueuedCount = 0;
  int _droppedCount = 0;
  int _processedCount = 0;
  bool _isProcessingLock = false;

  FrameQueue({this.maxCapacity = 2});

  int get currentSize => _queue.length;
  int get enqueuedCount => _enqueuedCount;
  int get droppedCount => _droppedCount;
  int get processedCount => _processedCount;
  bool get isProcessingLock => _isProcessingLock;

  /// Add new frame to queue.
  /// If queue exceeds maxCapacity, drop the oldest frame to prefer the newest.
  bool enqueue(CameraImage image) {
    _enqueuedCount++;
    final item = FrameQueueItem(
      image: image,
      arrivalTime: DateTime.now(),
      frameId: _enqueuedCount,
    );

    if (_queue.length >= maxCapacity) {
      _queue.removeFirst();
      _droppedCount++;
    }

    _queue.add(item);
    return true;
  }

  /// Pop newest frame for background processing with lock.
  FrameQueueItem? popForProcessing() {
    if (_isProcessingLock || _queue.isEmpty) {
      return null;
    }

    _isProcessingLock = true;
    _processedCount++;
    return _queue.removeFirst();
  }

  /// Release lock after processing completes.
  void releaseProcessingLock() {
    _isProcessingLock = false;
  }

  /// Clear all queued frames.
  void clear() {
    _queue.clear();
    _isProcessingLock = false;
  }

  /// Reset statistics counter.
  void resetStats() {
    _enqueuedCount = 0;
    _droppedCount = 0;
    _processedCount = 0;
  }
}
