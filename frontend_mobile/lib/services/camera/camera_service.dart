// lib/services/camera/camera_service.dart

import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter/foundation.dart';

enum CameraServiceState {
  uninitialized,
  initializing,
  ready,
  streaming,
  error,
}

/// Production Camera Service encapsulating hardware lifecycle, stream handling, and state management.
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  camera_pkg.CameraController? _controller;
  List<camera_pkg.CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  CameraServiceState _state = CameraServiceState.uninitialized;
  String? _lastError;

  final ValueNotifier<CameraServiceState> stateNotifier =
      ValueNotifier<CameraServiceState>(CameraServiceState.uninitialized);

  camera_pkg.CameraController? get controller => _controller;
  CameraServiceState get state => _state;
  bool get isReady => _state == CameraServiceState.ready || _state == CameraServiceState.streaming;
  bool get isStreaming => _state == CameraServiceState.streaming;
  String? get lastError => _lastError;
  int get selectedCameraIndex => _selectedCameraIndex;
  List<camera_pkg.CameraDescription> get availableCameras => _availableCameras;

  camera_pkg.CameraLensDirection get currentLensDirection =>
      (_availableCameras.isNotEmpty && _selectedCameraIndex < _availableCameras.length)
          ? _availableCameras[_selectedCameraIndex].lensDirection
          : camera_pkg.CameraLensDirection.front;

  int get sensorOrientation =>
      (_availableCameras.isNotEmpty && _selectedCameraIndex < _availableCameras.length)
          ? _availableCameras[_selectedCameraIndex].sensorOrientation
          : 90;

  void _updateState(CameraServiceState newState, [String? error]) {
    _state = newState;
    _lastError = error;
    stateNotifier.value = newState;
    debugPrint('🎥 [CameraService] State: $newState ${error != null ? "- $error" : ""}');
  }

  /// Discover available cameras and initialize controller.
  Future<bool> initialize({
    camera_pkg.CameraLensDirection preferredLens = camera_pkg.CameraLensDirection.front,
    camera_pkg.ResolutionPreset resolution = camera_pkg.ResolutionPreset.high,
  }) async {
    if (_state == CameraServiceState.ready || _state == CameraServiceState.streaming) {
      return true;
    }
    if (_state == CameraServiceState.initializing) return false;

    _updateState(CameraServiceState.initializing);

    try {
      _availableCameras = await availableCamerasFunc();
      if (_availableCameras.isEmpty) {
        throw Exception('No cameras discovered on device');
      }

      // Select camera matching preferred lens
      _selectedCameraIndex = 0;
      for (int i = 0; i < _availableCameras.length; i++) {
        if (_availableCameras[i].lensDirection == preferredLens) {
          _selectedCameraIndex = i;
          break;
        }
      }

      final cameraDesc = _availableCameras[_selectedCameraIndex];
      _controller = camera_pkg.CameraController(
        cameraDesc,
        resolution,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? camera_pkg.ImageFormatGroup.yuv420
            : camera_pkg.ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      _updateState(CameraServiceState.ready);
      return true;
    } catch (e) {
      _updateState(CameraServiceState.error, 'Camera initialization failed: $e');
      return false;
    }
  }

  /// Fallback test method for getting available cameras.
  Future<List<camera_pkg.CameraDescription>> availableCamerasFunc() async {
    try {
      return await camera_pkg.availableCameras();
    } catch (_) {
      return [];
    }
  }

  /// Switch between Front and Back camera.
  Future<bool> switchCamera({camera_pkg.ResolutionPreset resolution = camera_pkg.ResolutionPreset.high}) async {
    if (_availableCameras.length <= 1) return false;

    final wasStreaming = isStreaming;
    if (wasStreaming) {
      await stopImageStream();
    }

    await disposeController();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;

    final success = await initialize(
      preferredLens: _availableCameras[_selectedCameraIndex].lensDirection,
      resolution: resolution,
    );

    return success;
  }

  /// Start receiving frame stream from camera hardware.
  Future<bool> startImageStream(void Function(camera_pkg.CameraImage image) onFrame) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _updateState(CameraServiceState.error, 'Cannot start stream: Controller not initialized');
      return false;
    }

    if (isStreaming) return true;

    try {
      await _controller!.startImageStream(onFrame);
      _updateState(CameraServiceState.streaming);
      return true;
    } catch (e) {
      _updateState(CameraServiceState.error, 'Failed to start image stream: $e');
      return false;
    }
  }

  /// Stop image stream cleanly.
  Future<void> stopImageStream() async {
    if (_controller == null || !isStreaming) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      _updateState(CameraServiceState.ready);
    } catch (e) {
      debugPrint('⚠️ [CameraService] Stop stream error: $e');
    }
  }

  /// Safely dispose controller instance.
  Future<void> disposeController() async {
    try {
      await stopImageStream();
      await _controller?.dispose();
      _controller = null;
      _updateState(CameraServiceState.uninitialized);
    } catch (e) {
      debugPrint('⚠️ [CameraService] Dispose error: $e');
    }
  }

  void dispose() {
    disposeController();
    stateNotifier.dispose();
  }
}
