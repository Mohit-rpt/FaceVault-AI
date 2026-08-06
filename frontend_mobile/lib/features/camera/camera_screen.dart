// lib/features/camera/camera_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import 'widgets/camera_status_card.dart';
import 'widgets/camera_preview_card.dart';
import 'widgets/camera_list_card.dart';
import 'widgets/camera_controls.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
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
  }

  void _selectCamera(int index) {
    setState(() {
      _selectedIndex = index;
      _activeCamera = Map.from(_cameras[index]);
    });
  }

  void _toggleConnection() {
    setState(() {
      final currentStatus = _activeCamera['status'];
      _activeCamera['status'] =
          currentStatus == 'Connected' ? 'Disconnected' : 'Connected';
      _cameras[_selectedIndex]['status'] = _activeCamera['status'];
    });
  }

  void _addCamera(Map<String, dynamic> newCamera) {
    setState(() {
      _cameras.add(newCamera);
      _selectedIndex = _cameras.length - 1;
      _activeCamera = Map.from(newCamera);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FuturisticAppBar(title: 'CAMERA CONTROL'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CameraStatusCard(camera: _activeCamera),
              const SizedBox(height: 16),
              CameraPreviewCard(camera: _activeCamera),
              const SizedBox(height: 16),
              CameraListCard(
                cameras: _cameras,
                selectedIndex: _selectedIndex,
                onSelect: _selectCamera,
                onAdd: () => _showAddCameraDialog(context),
              ),
              const SizedBox(height: 16),
              CameraControls(
                isConnected: _activeCamera['status'] == 'Connected',
                onToggle: _toggleConnection,
                onTest: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Test connection successful'),
                      backgroundColor: AppTheme.neonGreen.withOpacity(0.8),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
                  labelStyle: TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
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
                  labelStyle: TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
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
                  labelText: 'Stream URL',
                  labelStyle: TextStyle(color: AppTheme.neonCyan.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
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
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                _addCamera({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameCtrl.text,
                  'type': cameraType,
                  'status': 'Disconnected',
                  'resolution': 'Unknown',
                  'fps': 0,
                  'url': urlCtrl.text,
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }
}