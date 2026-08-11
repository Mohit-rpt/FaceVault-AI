// lib/services/camera/frame_queue.dart
// NOTE: FrameProcessor no longer uses FrameQueue directly.
// Kept for backward compatibility with any other references.

import 'dart:collection';
import 'package:camera/camera.dart';

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

class FrameQueue {
  final int maxCapacity;
  final Queue<FrameQueueItem> _queue = Queue<FrameQueueItem>();

  int _enqueuedCount = 0;
  int _droppedCount = 0;
  int _processedCount = 0;
  bool _isProcessingLock = false;

  FrameQueue({this.maxCapacity = 1});

  int get currentSize => _queue.length;
  int get enqueuedCount => _enqueuedCount;
  int get droppedCount => _droppedCount;
  int get processedCount => _processedCount;
  bool get isProcessingLock => _isProcessingLock;

  bool enqueue(CameraImage image) {
    _enqueuedCount++;
    final item = FrameQueueItem(
      image: image,
      arrivalTime: DateTime.now(),
      frameId: _enqueuedCount,
    );

    // Drop all older frames, keep only the newest
    while (_queue.length >= maxCapacity) {
      _queue.removeFirst();
      _droppedCount++;
    }
    _queue.add(item);
    return true;
  }

  /// Pop NEWEST frame for processing.
  FrameQueueItem? popForProcessing() {
    if (_isProcessingLock || _queue.isEmpty) return null;
    _isProcessingLock = true;
    _processedCount++;

    // Take the newest frame, discard older ones
    final newest = _queue.removeLast();
    while (_queue.isNotEmpty) {
      _queue.removeFirst();
      _droppedCount++;
    }
    return newest;
  }

  void releaseProcessingLock() {
    _isProcessingLock = false;
  }

  void clear() {
    _queue.clear();
    _isProcessingLock = false;
  }

  void resetStats() {
    _enqueuedCount = 0;
    _droppedCount = 0;
    _processedCount = 0;
  }
}
