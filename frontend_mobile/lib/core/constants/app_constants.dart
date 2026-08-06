class AppConstants {
  static const String appName = 'FACEVAULT AI';
  static const String systemOnline = 'SYSTEM ONLINE';
  static const String aiActive = 'AI ACTIVE';
  static const String cameraConnected = 'CAMERA CONNECTED';

  // Mock statistics
  static const int totalPersons = 1247;
  static const int todayRecognitions = 89;
  static const int activeCameras = 12;
  static const int unknownFaces = 7;

  // Mock recent activities
  static final List<Map<String, dynamic>> recentActivities = [
    {
      'name': 'Mohit Rajput',
      'confidence': 98,
      'time': '2 minutes ago',
      'location': 'Main Gate',
    },
    {
      'name': 'Priya Sharma',
      'confidence': 95,
      'time': '12 minutes ago',
      'location': 'Lobby',
    },
    {
      'name': 'Alex Chen',
      'confidence': 88,
      'time': '35 minutes ago',
      'location': 'Server Room',
    },
    {
      'name': 'Sarah Wilson',
      'confidence': 99,
      'time': '1 hour ago',
      'location': 'R&D Lab',
    },
  ];

  // Camera mock
  static const double cameraFps = 30.0;
  static const String cameraStatus = 'ONLINE';
}