class Barang {
  final int? id;
  final int? profilId; // Tambahkan profilId
  final String nama;
  final double hargaBeli;
  final double hargaJual;
  final double stok;
  final String? fotoPath;
  final String deskripsi;
  final int? kategoriId;
  final int? merekId;
  final String satuan;
  final DateTime? tanggalKadaluarsa;
  final int isDeleted;

  Barang({
    this.id,
    this.profilId,
    required this.nama,
    this.hargaBeli = 0,
    this.hargaJual = 0,
    this.stok = 0,
    this.deskripsi = '',
    this.fotoPath,
    this.kategoriId,
    this.merekId,
    this.satuan = 'Pcs',
    this.tanggalKadaluarsa,
    this.isDeleted = 0,
  });

  factory Barang.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    
    // 1. Coba baca dari string ISO8601
    if (map['tanggal_kadaluarsa'] != null && map['tanggal_kadaluarsa'].toString().isNotEmpty) {
      try {
        parsedDate = DateTime.parse(map['tanggal_kadaluarsa']);
      } catch (_) {
        parsedDate = null;
      }
    }

    // 2. Jika gagal/null, coba baca dari timestamp integer
    if (parsedDate == null && map['tanggal_kadaluarsa_int'] != null) {
      try {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(map['tanggal_kadaluarsa_int'] as int);
      } catch (_) {
        parsedDate = null;
      }
    }

    return Barang(
      id: map['id'] as int?,
      profilId: map['profil_id'] as int?,
      nama: map['nama'] as String? ?? '',
      hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0,
      hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0,
      stok: (map['stok'] as num?)?.toDouble() ?? 0,
      deskripsi: map['deskripsi'] as String? ?? '',
      fotoPath: map['foto_path'] as String?,
      kategoriId: map['kategori_id'] as int?,
      merekId: map['merek_id'] as int?,
      satuan: map['satuan'] as String? ?? 'Pcs',
      tanggalKadaluarsa: parsedDate,
      isDeleted: map['is_deleted'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profil_id': profilId,
      'nama': nama,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': stok,
      'deskripsi': deskripsi,
      'foto_path': fotoPath,
      'kategori_id': kategoriId,
      'merek_id': merekId,
      'satuan': satuan,
      'tanggal_kadaluarsa': tanggalKadaluarsa?.toIso8601String(),
      'tanggal_kadaluarsa_int': tanggalKadaluarsa?.millisecondsSinceEpoch,
      'is_deleted': isDeleted,
    };
  }

  Barang copyWith({
    int? id,
    int? profilId,
    String? nama,
    double? hargaBeli,
    double? hargaJual,
    double? stok,
    String? fotoPath,
    String? deskripsi,
    int? kategoriId,
    int? merekId,
    String? satuan,
    DateTime? tanggalKadaluarsa,
    int? isDeleted,
  }) {
    return Barang(
      id: id ?? this.id,
      profilId: profilId ?? this.profilId,
      nama: nama ?? this.nama,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stok: stok ?? this.stok,
      deskripsi: deskripsi ?? this.deskripsi,
      fotoPath: fotoPath ?? this.fotoPath,
      kategoriId: kategoriId ?? this.kategoriId,
      merekId: merekId ?? this.merekId,
      satuan: satuan ?? this.satuan,
      tanggalKadaluarsa: tanggalKadaluarsa ?? this.tanggalKadaluarsa,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // ================= GETTER =================

  bool get isDeletedBarang => isDeleted == 1;
  bool get isLowStock => stok > 0 && stok <= 5;
  bool get isOutOfStock => stok <= 0;

  double get untung => hargaJual - hargaBeli;
  
  double get marginPersen => (hargaJual > 0 && untung > 0) ? (untung / hargaJual) * 100 : 0;

  bool get isExpired {
    if (tanggalKadaluarsa == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final compareDate = DateTime(
      tanggalKadaluarsa!.year, 
      tanggalKadaluarsa!.month, 
      tanggalKadaluarsa!.day
    );
    
    return compareDate.isBefore(today);
  }

  bool isExpiringSoon(int days) {
    if (tanggalKadaluarsa == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = today.add(Duration(days: days));

    final compareDate = DateTime(
      tanggalKadaluarsa!.year, 
      tanggalKadaluarsa!.month, 
      tanggalKadaluarsa!.day
    );

    return (compareDate.isAtSameMomentAs(today) || compareDate.isAfter(today)) && 
           (compareDate.isAtSameMomentAs(targetDate) || compareDate.isBefore(targetDate));
  }

  DateTime? get effectiveDate => tanggalKadaluarsa;
}
