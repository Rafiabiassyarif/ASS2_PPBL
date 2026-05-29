class UserModel {
  final int? id;
  final String nama;
  final String email;
  final int paketId;
  final String status;
  final String tanggalDaftar;
  final String? namaPaket; // Populated from join query if present

  UserModel({
    this.id,
    required this.nama,
    required this.email,
    required this.paketId,
    required this.status,
    required this.tanggalDaftar,
    this.namaPaket,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      nama: map['nama'] as String,
      email: map['email'] as String,
      paketId: map['paket_id'] as int,
      status: map['status'] as String,
      tanggalDaftar: map['tanggal_daftar'] as String,
      namaPaket: map['nama_paket'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nama': nama,
      'email': email,
      'paket_id': paketId,
      'status': status,
      'tanggal_daftar': tanggalDaftar,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  UserModel copyWith({
    int? id,
    String? nama,
    String? email,
    int? paketId,
    String? status,
    String? tanggalDaftar,
    String? namaPaket,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      paketId: paketId ?? this.paketId,
      status: status ?? this.status,
      tanggalDaftar: tanggalDaftar ?? this.tanggalDaftar,
      namaPaket: namaPaket ?? this.namaPaket,
    );
  }
}
