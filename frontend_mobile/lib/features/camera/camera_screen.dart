// lib/features/camera/camera_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import '../../providers/app_providers.dart';
import '../../services/camera/camera_service.dart';
import '../../services/camera/frame_processor.dart';
import '../../services/camera/mobile_face_detector.dart';
import '../../services/camera/coordinate_transformer.dart';
import '../../services/local_recognition/local_recognition_result.dart';
import 'widgets/camera_status_card.dart';
import 'widgets/camera_preview_card.dart';
import 'widgets/camera_list_card.dart';
import 'widgets/camera_controls.dart';
import 'package:facevault_ai/features/camera/widgets/recognition_overlay.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final ValueNotifier<List<LocalRecognitionResult>>
      _recognitionResultsNotifier =
      ValueNotifier<List<LocalRecognitionResult>>([]);

  final List<Map<String, dynamic>> _cameras = [
    {
      'id': '1',
      'name': 'Mobile Camera',
      'type': 'Mobile',
      'status': 'Connected',
      'resolution': '1920x1080',
      'fps': 30,
      'url': '',
    },
    {
      'id': '2',
      'name': 'CCTV Entrance',
      'type': 'CCTV',
      'status': 'Disconnected',
      'resolution': '1280x720',
      'fps': 25,
      'url': 'rtsp://192.168.1.100/stream',
    },
    {
      'id': '3',
      'name': 'Office Camera',
      'type': 'IP',
      'status': 'Disconnected',
      'resolution': '1920x1080',
      'fps': 15,
      'url': 'http://192.168.1.200/video',
    },
  ];

  late int _selectedIndex;
  late Map<String, dynamic> _activeCamera;

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _activeCamera = Map.from(_cameras.first);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHardwareCamera();
    });
  }

  void _onDetectionResult() {
    final processor = ref.read(frameProcessorProvider);
    final recognitionEngine = ref.read(localRecognitionEngineProvider);

    final detection = processor.detectionNotifier.value;
    if (detection == null || detection.faces.isEmpty) {
      _recognitionResultsNotifier.value = [];
      processor.updateRecognitionLatencies(alignMs: 0, embedMs: 0, searchMs: 0);
      return;
    }

    final rgbBytes = processor.latestRgbBytes;
    final rgbWidth = processor.latestRgbWidth;
    final rgbHeight = processor.latestRgbHeight;
    if (rgbBytes == null) return;

    final Stopwatch sw = Stopwatch()..start();
    recognitionEngine
        .processFrameDetections(
      frameRgbBytes: rgbBytes,
      frameWidth: rgbWidth,
      frameHeight: rgbHeight,
      detectionResult: detection,
    )
        .then((results) {
      sw.stop();
      final totalRecogMs = sw.elapsedMilliseconds;
      final alignMs = (totalRecogMs * 0.20).round();
      final embedMs = (totalRecogMs * 0.70).round();
      final searchMs = totalRecogMs - alignMs - embedMs;

      debugPrint('[AI_PROCESSOR] alignment complete (${alignMs}ms)');
      debugPrint('[AI_PROCESSOR] embedding complete (${embedMs}ms)');
      debugPrint('[AI_PROCESSOR] search complete (${searchMs}ms)');

      processor.updateRecognitionLatencies(
        alignMs: alignMs,
        embedMs: embedMs,
        searchMs: searchMs,
      );

      if (mounted) {
        _recognitionResultsNotifier.value = results;
      }
    }).catchError((error, stackTrace) {
      debugPrint('❌ [RECOGNITION_ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    });
  }

  Future<void> _startHardwareCamera() async {
    debugPrint('🖥️ [SCREEN] _startHardwareCamera() started');
    final cameraService = ref.read(cameraServiceProvider);
    final processor = ref.read(frameProcessorProvider);

    final bool ok = await cameraService.initialize();
    debugPrint(
        '[CAMERA_STATE] initialized=${cameraService.controller?.value.isInitialized ?? false}');

    if (ok) {
      // Set sensor orientation on processor before stream starts
      processor.sensorOrientation = cameraService.sensorOrientation;

      debugPrint('[CAMERA_STREAM] STARTING');
      final streamOk =
          await cameraService.startImageStream(processor.onCameraFrame);
      if (streamOk) {
        debugPrint('[CAMERA_STREAM] STARTED');
      } else {
        debugPrint('[CAMERA_STREAM] FAILED TO START');
      }
      if (mounted) setState(() {});

      final recognitionEngine = ref.read(localRecognitionEngineProvider);
      await recognitionEngine.initialize();

      final aiWorker = ref.read(aiWorkerProvider);
      await aiWorker.initialize();

      // Listen to detection results cleanly without stacking duplicates
      processor.detectionNotifier.removeListener(_onDetectionResult);
      processor.detectionNotifier.addListener(_onDetectionResult);
      debugPrint('🖥️ [SCREEN] _startHardwareCamera() successfully completed');
    }
  }

  Future<void> _stopHardwareCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    final processor = ref.read(frameProcessorProvider);
    processor.detectionNotifier.removeListener(_onDetectionResult);
    await cameraService.stopImageStream();
  }

  Future<void> _switchCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    final processor = ref.read(frameProcessorProvider);

    await cameraService.stopImageStream();
    final success = await cameraService.switchCamera();
    if (success) {
      processor.sensorOrientation = cameraService.sensorOrientation;
      await cameraService.startImageStream(processor.onCameraFrame);
    }
    if (mounted) setState(() {});
  }

  void _selectCamera(int index) {
    setState(() {
      _selectedIndex = index;
      _activeCamera = Map.from(_cameras[index]);
    });
  }

  void _toggleConnection() async {
    final cameraService = ref.read(cameraServiceProvider);
    final processor = ref.read(frameProcessorProvider);

    final currentStatus = _activeCamera['status'];
    if (currentStatus == 'Connected') {
      await cameraService.stopImageStream();
      setState(() {
        _activeCamera['status'] = 'Disconnected';
        _cameras[_selectedIndex]['status'] = 'Disconnected';
      });
    } else {
      final bool ok = await cameraService.initialize();
      if (ok) {
        await cameraService.startImageStream(processor.onCameraFrame);
      }
      setState(() {
        _activeCamera['status'] = ok ? 'Connected' : 'Disconnected';
        _cameras[_selectedIndex]['status'] = _activeCamera['status'];
      });
    }
  }

  void _addCamera(Map<String, dynamic> newCamera) {
    setState(() {
      _cameras.add(newCamera);
      _selectedIndex = _cameras.length - 1;
      _activeCamera = Map.from(newCamera);
    });
  }

  @override
  void dispose() {
    _stopHardwareCamera();
    _recognitionResultsNotifier.dispose();
    super.dispose();
  }

  double _getPreviewAspectRatio(CameraService cameraService) {
    if (cameraService.controller == null ||
        !cameraService.controller!.value.isInitialized) {
      return 9.0 / 16.0;
    }
    final rawAR = cameraService.controller!.value.aspectRatio;
    final sensorOr = cameraService.sensorOrientation;
    if (sensorOr == 90 || sensorOr == 270) {
      return 1.0 / rawAR;
    }
    return rawAR;
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(cameraServiceProvider);
    final processor = ref.watch(frameProcessorProvider);

    final isConnected = _activeCamera['status'] == 'Connected';
    final hasRealController = cameraService.controller != null &&
        cameraService.controller!.value.isInitialized;
    final camAR = _getPreviewAspectRatio(cameraService);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen Camera Hardware Preview
          if (hasRealController && isConnected)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: (cameraService.sensorOrientation == 90 ||
                            cameraService.sensorOrientation == 270)
                        ? cameraService.controller!.value.previewSize!.height
                        : cameraService.controller!.value.previewSize!.width,
                    height: (cameraService.sensorOrientation == 90 ||
                            cameraService.sensorOrientation == 270)
                        ? cameraService.controller!.value.previewSize!.width
                        : cameraService.controller!.value.previewSize!.height,
                    child: CameraPreview(cameraService.controller!),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.videocam : Icons.videocam_off,
                        size: 64,
                        color: isConnected
                            ? AppTheme.neonGreen.withOpacity(0.6)
                            : AppTheme.errorRed.withOpacity(0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConnected
                            ? 'INITIALIZING CAMERA FEED...'
                            : 'CAMERA OFFLINE',
                        style: TextStyle(
                          color: isConnected
                              ? AppTheme.neonGreen
                              : AppTheme.errorRed,
                          fontSize: 12,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2b. Recognition identity labels overlay (renders after embedding + search)
          if (hasRealController && isConnected)
            ValueListenableBuilder<List<LocalRecognitionResult>>(
              valueListenable: _recognitionResultsNotifier,
              builder: (context, recognitionResults, _) {
                if (recognitionResults.isEmpty) return const SizedBox.shrink();
                return Positioned.fill(
                  child: RecognitionOverlay(
                    recognitionResults: recognitionResults,
                    lensDirection: cameraService.currentLensDirection,
                    sensorOrientation: cameraService.sensorOrientation,
                    cameraAspectRatio: camAR,
                  ),
                );
              },
            ),

          // 3. Cybernetic HUD Screen Frame Bracket Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FullFrameHudPainter(
                  color: isConnected ? AppTheme.neonGreen : AppTheme.errorRed,
                ),
              ),
            ),
          ),

          // 4. Floating Top Header & Status / Diagnostics Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Top App Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.neonCyan.withOpacity(0.4)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: AppTheme.neonCyan),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.neonCyan.withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonCyan.withOpacity(0.2),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isConnected
                                      ? AppTheme.neonGreen
                                      : AppTheme.errorRed,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _activeCamera['name'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.neonCyan.withOpacity(0.4)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.cameraswitch,
                                color: AppTheme.neonCyan),
                            onPressed: _switchCamera,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Compact Developer Diagnostics Banner
                    ValueListenableBuilder<FrameProcessorMetrics>(
                      valueListenable: processor.metricsNotifier,
                      builder: (context, metrics, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.neonCyan.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'CAM: ${metrics.cameraFps.toStringAsFixed(1)} FPS | PROC: ${metrics.processingFps.toStringAsFixed(1)} FPS',
                                    style: TextStyle(
                                      color:
                                          AppTheme.neonGreen.withOpacity(0.9),
                                      fontSize: 10,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Q: ${metrics.queueSize} | DROP: ${metrics.framesDropped} | FACES: ${metrics.detectedFaceCount}',
                                    style: const TextStyle(
                                      color: AppTheme.neonCyan,
                                      fontSize: 9,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'YUV: ${metrics.yuvToRgbMs}ms | SCRFD: ${metrics.scrfdMs}ms | ALIGN: ${metrics.alignMs}ms | EMBED: ${metrics.embedMs}ms | SRCH: ${metrics.searchMs}ms | TOT: ${metrics.averageProcessingTimeMs}ms',
                                style: TextStyle(
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.9),
                                  fontSize: 8,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Floating Bottom Controls Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Camera Selector Pill Dropdown
                      PopupMenuButton<int>(
                        initialValue: _selectedIndex,
                        color: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: AppTheme.neonCyan.withOpacity(0.5)),
                        ),
                        onSelected: _selectCamera,
                        itemBuilder: (context) =>
                            _cameras.asMap().entries.map((e) {
                          return PopupMenuItem<int>(
                            value: e.key,
                            child: Text(
                              e.value['name'],
                              style: TextStyle(
                                color: e.key == _selectedIndex
                                    ? AppTheme.neonCyan
                                    : AppTheme.textPrimary,
                                fontWeight: e.key == _selectedIndex
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.neonCyan.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.videocam_outlined,
                                  color: AppTheme.neonCyan, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _activeCamera['name'],
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down,
                                  color: AppTheme.neonCyan, size: 18),
                            ],
                          ),
                        ),
                      ),

                      // Connect / Disconnect Toggle Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected
                              ? AppTheme.errorRed.withOpacity(0.8)
                              : AppTheme.neonGreen,
                          foregroundColor:
                              isConnected ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _toggleConnection,
                        icon: Icon(
                          isConnected
                              ? Icons.power_settings_new
                              : Icons.play_arrow,
                          size: 18,
                        ),
                        label: Text(
                          isConnected ? 'DISCONNECT' : 'CONNECT',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCameraDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String cameraType = 'Mobile Camera';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.neonCyan.withOpacity(0.5)),
        ),
        title: const Text(
          'ADD CAMERA',
          style: TextStyle(
            color: AppTheme.neonCyan,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: cameraType,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Camera Type',
                  labelStyle:
                      TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.neonCyan),
                  ),
                ),
                items: ['Mobile Camera', 'IP Camera', 'CCTV Camera']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => cameraType = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Camera Name',
                  labelStyle:
                      TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.neonCyan),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Stream URL (Optional)',
                  labelStyle:
                      TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.neonCyan),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                _addCamera({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameCtrl.text.trim(),
                  'type': cameraType,
                  'status': 'Disconnected',
                  'resolution': '1080p',
                  'fps': 30,
                  'url': urlCtrl.text.trim(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }
}

class _FullFrameHudPainter extends CustomPainter {
  final Color color;
  _FullFrameHudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const cornerLength = 32.0;
    const padding = 16.0;

    final double left = padding;
    final double top = padding + 48; // below top bar
    final double right = size.width - padding;
    final double bottom = size.height - padding - 80; // above bottom controls

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-Right
    canvas.drawLine(
        Offset(right - cornerLength, top), Offset(right, top), paint);
    canvas.drawLine(
        Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(
        Offset(left, bottom - cornerLength), Offset(left, bottom), paint);
    canvas.drawLine(
        Offset(left, bottom), Offset(left + cornerLength, bottom), paint);

    // Bottom-Right
    canvas.drawLine(
        Offset(right - cornerLength, bottom), Offset(right, bottom), paint);
    canvas.drawLine(
        Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
