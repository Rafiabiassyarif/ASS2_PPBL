class TicketModel {
  final int? id;
  final int userId;
  final String subjek;
  final String pesan;
  final String status; // 'open' | 'in_progress' | 'closed'
  final String prioritas; // 'low' | 'medium' | 'high'
  final String tanggalBuat;
  final String tanggalUpdate;
  final String? namaUser; // Populated from join query if present

  TicketModel({
    this.id,
    required this.userId,
    required this.subjek,
    required this.pesan,
    required this.status,
    required this.prioritas,
    required this.tanggalBuat,
    required this.tanggalUpdate,
    this.namaUser,
  });

  factory TicketModel.fromMap(Map<String, dynamic> map) {
    return TicketModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      subjek: map['subjek'] as String,
      pesan: map['pesan'] as String,
      status: map['status'] as String,
      prioritas: map['prioritas'] as String,
      tanggalBuat: map['tanggal_buat'] as String,
      tanggalUpdate: map['tanggal_update'] as String,
      namaUser: map['nama'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'subjek': subjek,
      'pesan': pesan,
      'status': status,
      'prioritas': prioritas,
      'tanggal_buat': tanggalBuat,
      'tanggal_update': tanggalUpdate,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  TicketModel copyWith({
    int? id,
    int? userId,
    String? subjek,
    String? pesan,
    String? status,
    String? prioritas,
    String? tanggalBuat,
    String? tanggalUpdate,
    String? namaUser,
  }) {
    return TicketModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subjek: subjek ?? this.subjek,
      pesan: pesan ?? this.pesan,
      status: status ?? this.status,
      prioritas: prioritas ?? this.prioritas,
      tanggalBuat: tanggalBuat ?? this.tanggalBuat,
      tanggalUpdate: tanggalUpdate ?? this.tanggalUpdate,
      namaUser: namaUser ?? this.namaUser,
    );
  }
}
