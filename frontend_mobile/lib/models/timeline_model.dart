// lib/models/timeline_model.dart

class TimelineModel {
  final int timelineId;
  final int personId;
  final String interactionDate;
  final String title;
  final String? description;
  final String? location;
  final String? tags;
  final String? createdAt;

  TimelineModel({
    required this.timelineId,
    required this.personId,
    required this.interactionDate,
    required this.title,
    this.description,
    this.location,
    this.tags,
    this.createdAt,
  });

  factory TimelineModel.fromJson(Map<String, dynamic> json) {
    return TimelineModel(
      timelineId: json['timeline_id'] ?? json['id'] ?? 0,
      personId: json['person_id'] ?? 0,
      interactionDate: json['interaction_date'] ?? DateTime.now().toIso8601String(),
      title: json['title'] ?? 'Interaction',
      description: json['description'] as String?,
      location: json['location'] as String?,
      tags: json['tags'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'interaction_date': interactionDate,
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (tags != null) 'tags': tags,
    };
  }
}

class TimelineCreateReq {
  final String interactionDate;
  final String title;
  final String? description;
  final String? location;
  final String? tags;

  TimelineCreateReq({
    required this.interactionDate,
    required this.title,
    this.description,
    this.location,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'interaction_date': interactionDate,
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (tags != null) 'tags': tags,
    };
  }
}
