class DomainModel {
  final int? id;
  final String namaDomain;
  final int clientId;
  final String tanggalDaftar;
  final String tanggalExpired;
  final String status;

  DomainModel({
    this.id,
    required this.namaDomain,
    required this.clientId,
    required this.tanggalDaftar,
    required this.tanggalExpired,
    required this.status,
  });

  factory DomainModel.fromMap(Map<String, dynamic> map) {
    return DomainModel(
      id: map['id'] as int?,
      namaDomain: map['nama_domain'] as String,
      clientId: map['client_id'] as int,
      tanggalDaftar: map['tanggal_daftar'] as String,
      tanggalExpired: map['tanggal_expired'] as String,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nama_domain': namaDomain,
      'client_id': clientId,
      'tanggal_daftar': tanggalDaftar,
      'tanggal_expired': tanggalExpired,
      'status': status,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  DomainModel copyWith({
    int? id,
    String? namaDomain,
    int? clientId,
    String? tanggalDaftar,
    String? tanggalExpired,
    String? status,
  }) {
    return DomainModel(
      id: id ?? this.id,
      namaDomain: namaDomain ?? this.namaDomain,
      clientId: clientId ?? this.clientId,
      tanggalDaftar: tanggalDaftar ?? this.tanggalDaftar,
      tanggalExpired: tanggalExpired ?? this.tanggalExpired,
      status: status ?? this.status,
    );
  }
}
