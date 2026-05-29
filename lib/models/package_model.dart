class PackageModel {
  final int? id;
  final String namaPaket;
  final int harga;
  final int kuotaDisk;
  final int maxDomain;
  final String? deskripsi;
  final int? jumlahUser; // Populated from left join query if present

  PackageModel({
    this.id,
    required this.namaPaket,
    required this.harga,
    required this.kuotaDisk,
    required this.maxDomain,
    this.deskripsi,
    this.jumlahUser,
  });

  factory PackageModel.fromMap(Map<String, dynamic> map) {
    return PackageModel(
      id: map['id'] as int?,
      namaPaket: map['nama_paket'] as String,
      harga: map['harga'] as int,
      kuotaDisk: map['kuota_disk'] as int,
      maxDomain: map['max_domain'] as int,
      deskripsi: map['deskripsi'] as String?,
      jumlahUser: map['jumlah_user'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nama_paket': namaPaket,
      'harga': harga,
      'kuota_disk': kuotaDisk,
      'max_domain': maxDomain,
      'deskripsi': deskripsi,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  PackageModel copyWith({
    int? id,
    String? namaPaket,
    int? harga,
    int? kuotaDisk,
    int? maxDomain,
    String? deskripsi,
    int? jumlahUser,
  }) {
    return PackageModel(
      id: id ?? this.id,
      namaPaket: namaPaket ?? this.namaPaket,
      harga: harga ?? this.harga,
      kuotaDisk: kuotaDisk ?? this.kuotaDisk,
      maxDomain: maxDomain ?? this.maxDomain,
      deskripsi: deskripsi ?? this.deskripsi,
      jumlahUser: jumlahUser ?? this.jumlahUser,
    );
  }
}
