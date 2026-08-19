// lib/services/local_recognition/face_tracker.dart

import 'dart:math' as math;
import 'local_recognition_result.dart';

enum TrackState {
  newTrack,
  active,
  confirmed,
  lost,
  removed,
}

/// Representation of an actively tracked face across consecutive video frames.
class TrackedFace {
  final int trackId;
  List<double> boundingBox; // [left, top, right, bottom] (0.0 to 1.0)
  List<double> center; // [cx, cy]
  DateTime lastSeenTime;
  TrackState state;
  int missedFrames;
  int hitCount;

  String? personId;
  String displayName;
  double similarity;
  bool isKnown;

  TrackedFace({
    required this.trackId,
    required this.boundingBox,
    required this.center,
    required this.lastSeenTime,
    this.state = TrackState.newTrack,
    this.missedFrames = 0,
    this.hitCount = 1,
    this.personId,
    this.displayName = 'Unknown',
    this.similarity = 0.0,
    this.isKnown = false,
  });

  void updatePosition(List<double> newBox) {
    // Apply exponential smoothing to prevent visual jitter
    const double alpha = 0.7; // Smooth factor
    boundingBox = [
      alpha * newBox[0] + (1 - alpha) * boundingBox[0],
      alpha * newBox[1] + (1 - alpha) * boundingBox[1],
      alpha * newBox[2] + (1 - alpha) * boundingBox[2],
      alpha * newBox[3] + (1 - alpha) * boundingBox[3],
    ];

    center = [
      (boundingBox[0] + boundingBox[2]) / 2,
      (boundingBox[1] + boundingBox[3]) / 2,
    ];
    lastSeenTime = DateTime.now();
    missedFrames = 0;
    hitCount++;

    if (hitCount >= 2 && state == TrackState.newTrack) {
      state = TrackState.active;
    }
  }

  void updateIdentity({
    required String? newPersonId,
    required String newName,
    required double newSimilarity,
    required bool newIsKnown,
  }) {
    if (newIsKnown && newSimilarity >= 0.45) {
      personId = newPersonId;
      displayName = newName;
      similarity = newSimilarity;
      isKnown = true;
      if (hitCount >= 2) {
        state = TrackState.confirmed;
      }
    } else if (state != TrackState.confirmed) {
      displayName = 'Unknown';
      similarity = newSimilarity;
      isKnown = false;
    }
  }
}

/// Lightweight Multi-Object Face Tracker using IoU + Center Distance matching.
class FaceTracker {
  int _nextTrackId = 1;
  final List<TrackedFace> _activeTracks = [];

  static const double maxCenterDistanceThreshold = 0.25;
  static const int maxMissedFramesAllowed = 5;

  List<TrackedFace> get activeTracks =>
      _activeTracks.where((t) => t.state != TrackState.removed).toList();

  /// PHASE 23: Checks if a detection matches an existing, recognized track.
  /// If so, returns the cached identity to skip ONNX embedding.
  LocalRecognitionResult? getCachedIdentity(List<double> detBox) {
    final detCenter = [
      (detBox[0] + detBox[2]) / 2,
      (detBox[1] + detBox[3]) / 2,
    ];

    int bestTrackIdx = -1;
    double minDistance = double.infinity;

    for (int t = 0; t < _activeTracks.length; t++) {
      final track = _activeTracks[t];
      // Only use cache if the track is already known and not lost
      if (!track.isKnown || track.state == TrackState.lost || track.state == TrackState.removed) {
        continue;
      }

      final double dist = math.sqrt(
        math.pow(detCenter[0] - track.center[0], 2) +
            math.pow(detCenter[1] - track.center[1], 2),
      );

      if (dist < maxCenterDistanceThreshold && dist < minDistance) {
        minDistance = dist;
        bestTrackIdx = t;
      }
    }

    if (bestTrackIdx != -1) {
      final track = _activeTracks[bestTrackIdx];
      return LocalRecognitionResult(
        trackId: track.trackId,
        personId: track.personId,
        displayName: track.displayName,
        similarity: track.similarity,
        isKnown: track.isKnown,
        boundingBox: detBox,
        timestamp: DateTime.now(),
        state: 'cached_recognized',
      );
    }
    return null;
  }

  /// Match newly detected frame results against existing active tracks.
  List<LocalRecognitionResult> updateTracks(
    List<LocalRecognitionResult> frameDetections,
  ) {
    final now = DateTime.now();

    // 1. Mark existing tracks as unvisited for this frame
    final matchedTrackIndices = <int>{};
    final matchedDetectionIndices = <int>{};

    // 2. Perform greedy matching between tracks and detections based on IoU & distance
    for (int d = 0; d < frameDetections.length; d++) {
      final det = frameDetections[d];
      final detBox = det.boundingBox;
      final detCenter = [
        (detBox[0] + detBox[2]) / 2,
        (detBox[1] + detBox[3]) / 2,
      ];

      int bestTrackIdx = -1;
      double minDistance = double.infinity;

      for (int t = 0; t < _activeTracks.length; t++) {
        if (matchedTrackIndices.contains(t)) continue;
        final track = _activeTracks[t];

        // Compute Euclidean distance between center points
        final double dist = math.sqrt(
          math.pow(detCenter[0] - track.center[0], 2) +
              math.pow(detCenter[1] - track.center[1], 2),
        );

        if (dist < maxCenterDistanceThreshold && dist < minDistance) {
          minDistance = dist;
          bestTrackIdx = t;
        }
      }

      if (bestTrackIdx != -1) {
        // Matched existing track
        matchedTrackIndices.add(bestTrackIdx);
        matchedDetectionIndices.add(d);

        final track = _activeTracks[bestTrackIdx];
        track.updatePosition(detBox);
        track.updateIdentity(
          newPersonId: det.personId,
          newName: det.displayName,
          newSimilarity: det.similarity,
          newIsKnown: det.isKnown,
        );
      }
    }

    // 3. Create new tracks for unmatched detections
    for (int d = 0; d < frameDetections.length; d++) {
      if (!matchedDetectionIndices.contains(d)) {
        final det = frameDetections[d];
        final detBox = det.boundingBox;
        final detCenter = [
          (detBox[0] + detBox[2]) / 2,
          (detBox[1] + detBox[3]) / 2,
        ];

        final newTrack = TrackedFace(
          trackId: _nextTrackId++,
          boundingBox: detBox,
          center: detCenter,
          lastSeenTime: now,
          state: TrackState.newTrack,
          personId: det.personId,
          displayName: det.displayName,
          similarity: det.similarity,
          isKnown: det.isKnown,
        );
        _activeTracks.add(newTrack);
      }
    }

    // 4. Update unmatched tracks (increment missed frame counter, expire stale tracks)
    for (int t = 0; t < _activeTracks.length; t++) {
      if (!matchedTrackIndices.contains(t)) {
        final track = _activeTracks[t];
        track.missedFrames++;
        if (track.missedFrames > 1) {
          track.state = TrackState.lost;
        }
        if (track.missedFrames > maxMissedFramesAllowed) {
          track.state = TrackState.removed;
        }
      }
    }

    // Remove expired tracks
    _activeTracks.removeWhere((t) => t.state == TrackState.removed);

    // 5. Convert active tracks to LocalRecognitionResult list
    return _activeTracks
        .where((t) => t.state != TrackState.removed)
        .map((t) => LocalRecognitionResult(
              trackId: t.trackId,
              personId: t.personId,
              displayName: t.displayName,
              similarity: t.similarity,
              isKnown: t.isKnown,
              boundingBox: t.boundingBox,
              timestamp: t.lastSeenTime,
              state: t.state.name,
            ))
        .toList();
  }

  void reset() {
    _activeTracks.clear();
    _nextTrackId = 1;
  }
}
