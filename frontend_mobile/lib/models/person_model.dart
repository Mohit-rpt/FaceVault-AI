// lib/models/person_model.dart

class CustomFieldModel {
  final int? fieldId;
  final int? personId;
  final String fieldName;
  final String? fieldValue;

  CustomFieldModel({
    this.fieldId,
    this.personId,
    required this.fieldName,
    this.fieldValue,
  });

  factory CustomFieldModel.fromJson(Map<String, dynamic> json) {
    return CustomFieldModel(
      fieldId: json['field_id'] as int?,
      personId: json['person_id'] as int?,
      fieldName: json['field_name'] ?? '',
      fieldValue: json['field_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      if (fieldValue != null) 'field_value': fieldValue,
    };
  }
}

class PersonDetailModel {
  final int? detailsId;
  final int? personId;
  final String? gender;
  final String? department;
  final String? employeeId;
  final String? phone;
  final String? email;
  final String? college;
  final String? company;
  final String? designation;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? birthday;
  final String? remarks;

  PersonDetailModel({
    this.detailsId,
    this.personId,
    this.gender,
    this.department,
    this.employeeId,
    this.phone,
    this.email,
    this.college,
    this.company,
    this.designation,
    this.address,
    this.city,
    this.state,
    this.country,
    this.birthday,
    this.remarks,
  });

  factory PersonDetailModel.fromJson(Map<String, dynamic> json) {
    return PersonDetailModel(
      detailsId: json['details_id'] as int?,
      personId: json['person_id'] as int?,
      gender: json['gender'] as String?,
      department: json['department'] as String?,
      employeeId: json['employee_id'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      college: json['college'] as String?,
      company: json['company'] as String?,
      designation: json['designation'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      birthday: json['birthday'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (gender != null) 'gender': gender,
      if (department != null) 'department': department,
      if (employeeId != null) 'employee_id': employeeId,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (college != null) 'college': college,
      if (company != null) 'company': company,
      if (designation != null) 'designation': designation,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (birthday != null) 'birthday': birthday,
      if (remarks != null) 'remarks': remarks,
    };
  }
}

class FaceImageModel {
  final int? imageId;
  final int? personId;
  final String imagePath;
  final String? captureSource;
  final double? qualityScore;
  final String? createdAt;

  FaceImageModel({
    this.imageId,
    this.personId,
    required this.imagePath,
    this.captureSource,
    this.qualityScore,
    this.createdAt,
  });

  factory FaceImageModel.fromJson(Map<String, dynamic> json) {
    return FaceImageModel(
      imageId: json['image_id'] as int?,
      personId: json['person_id'] as int?,
      imagePath: json['image_path'] ?? json['url'] ?? '',
      captureSource: json['capture_source'] as String?,
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }
}

class PersonModel {
  final int personId;
  final String name;
  final String? nickname;
  final String? relationship;
  final String? createdAt;
  final String? updatedAt;
  final PersonDetailModel? details;
  final List<FaceImageModel> images;
  final List<CustomFieldModel> customFields;
  final int embeddingsCount;
  final String? lastSeen;

  PersonModel({
    required this.personId,
    required this.name,
    this.nickname,
    this.relationship,
    this.createdAt,
    this.updatedAt,
    this.details,
    this.images = const [],
    this.customFields = const [],
    this.embeddingsCount = 0,
    this.lastSeen,
  });

  String get id => personId.toString();
  String get fullName => name;
  String? get company => details?.company;
  String? get email => details?.email;
  String? get phone => details?.phone;
  String? get address => details?.address;
  String? get jobRole => details?.designation;

  List<String> get tags {
    final List<String> list = [];
    if (relationship != null && relationship!.isNotEmpty) {
      list.add(relationship!);
    }
    if (details?.company != null && details!.company!.isNotEmpty) {
      list.add(details!.company!);
    }
    return list.isEmpty ? ['Registered'] : list;
  }

  List<String> get faceImagePaths => images.map((e) => e.imagePath).toList();

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    final imagesList = (json['images'] as List<dynamic>?)
            ?.map((e) => FaceImageModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final customFieldsList = (json['custom_fields'] as List<dynamic>?)
            ?.map((e) => CustomFieldModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final int embeddingsCount =
        json['embeddings_count'] ?? json['embeddings']?.length ?? json['face_embeddings'] ?? 0;

    return PersonModel(
      personId: json['person_id'] is int
          ? json['person_id']
          : int.tryParse(json['person_id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? json['full_name'] ?? 'Unknown',
      nickname: json['nickname'] as String?,
      relationship: json['relationship'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      details: json['details'] != null
          ? PersonDetailModel.fromJson(json['details'] as Map<String, dynamic>)
          : null,
      images: imagesList,
      customFields: customFieldsList,
      embeddingsCount: embeddingsCount,
      lastSeen: json['last_seen'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person_id': personId,
      'name': name,
      'nickname': nickname,
      'relationship': relationship,
      if (details != null) 'details': details!.toJson(),
      'custom_fields': customFields.map((f) => f.toJson()).toList(),
    };
  }
}

class PersonCreateReq {
  final String name;
  final String? nickname;
  final String? relationship;
  final PersonDetailModel? details;
  final List<CustomFieldModel> customFields;

  PersonCreateReq({
    required this.name,
    this.nickname,
    this.relationship,
    this.details,
    this.customFields = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (nickname != null && nickname!.isNotEmpty) 'nickname': nickname,
      if (relationship != null && relationship!.isNotEmpty)
        'relationship': relationship,
      if (details != null) 'details': details!.toJson(),
      if (customFields.isNotEmpty)
        'custom_fields': customFields.map((f) => f.toJson()).toList(),
    };
  }
}
