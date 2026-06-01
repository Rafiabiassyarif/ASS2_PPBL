class HostingRecord {
  final int? id;
  final String featureKey;
  final String title;
  final String primaryValue;
  final String secondaryValue;
  final String tertiaryValue;
  final String description;
  final String status;
  final bool isEnabled;
  final String createdAt;
  final String updatedAt;

  const HostingRecord({
    this.id,
    required this.featureKey,
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    required this.tertiaryValue,
    required this.description,
    required this.status,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostingRecord.fromMap(Map<String, dynamic> map) {
    return HostingRecord(
      id: map['id'] as int?,
      featureKey: map['feature_key'] as String,
      title: map['title'] as String,
      primaryValue: map['primary_value'] as String? ?? '',
      secondaryValue: map['secondary_value'] as String? ?? '',
      tertiaryValue: map['tertiary_value'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'feature_key': featureKey,
      'title': title,
      'primary_value': primaryValue,
      'secondary_value': secondaryValue,
      'tertiary_value': tertiaryValue,
      'description': description,
      'status': status,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  HostingRecord copyWith({
    int? id,
    String? featureKey,
    String? title,
    String? primaryValue,
    String? secondaryValue,
    String? tertiaryValue,
    String? description,
    String? status,
    bool? isEnabled,
    String? createdAt,
    String? updatedAt,
  }) {
    return HostingRecord(
      id: id ?? this.id,
      featureKey: featureKey ?? this.featureKey,
      title: title ?? this.title,
      primaryValue: primaryValue ?? this.primaryValue,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      tertiaryValue: tertiaryValue ?? this.tertiaryValue,
      description: description ?? this.description,
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
