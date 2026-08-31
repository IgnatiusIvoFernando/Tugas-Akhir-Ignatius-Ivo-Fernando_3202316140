enum JenisDokumen { masuk, keluar }

class DokumenStok {
  final int? id;
  final int? profilId; // Tambahkan profilId
  final JenisDokumen jenis;
  final String judul;
  final DateTime tanggal;
  final String? keterangan;
  final int? pembeliId;    // Ganti dari pembeli (String)
  final int? penyuplaiId; // Tambahkan penyuplaiId
  final double totalAkhir;
  final double nominalBayar;
  final double pajakPersen;
  final double diskonPersen;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Flag Visibilitas Independen
  final bool tampilDiStruk;
  final bool tampilDiLaporan; // Untuk Laporan Keuangan
  final bool tampilDiStok;    // Untuk Laporan Arus Barang

  DokumenStok({
    this.id,
    this.profilId,
    required this.jenis,
    required this.judul,
    required this.tanggal,
    this.keterangan,
    this.pembeliId,
    this.penyuplaiId,
    this.totalAkhir = 0.0,
    this.nominalBayar = 0.0,
    double? kembalian,
    this.pajakPersen = 0.0,
    this.diskonPersen = 0.0,
    String? status,
    this.createdAt,
    this.updatedAt,
    this.tampilDiStruk = true,
    this.tampilDiLaporan = true,
    this.tampilDiStok = true,
  })  : status = status ?? _defaultStatus(jenis);

  static String _defaultStatus(JenisDokumen jenis) => 'DIBAYAR';

  static double _hitungKembalian(double nominalBayar, double totalAkhir) {
    if (nominalBayar > totalAkhir) return nominalBayar - totalAkhir;
    return 0.0;
  }

  double get kembalian => _hitungKembalian(nominalBayar, totalAkhir);

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'profil_id': profilId,
      'jenis': jenis.name,
      'judul': judul,
      'tanggal': tanggal.toIso8601String(),
      'keterangan': keterangan,
      'pembeli_id': pembeliId,
      'penyuplai_id': penyuplaiId,
      'total_akhir': totalAkhir,
      'nominal_bayar': nominalBayar,
      // 'kembalian': kembalian, // Biasanya kembalian dihitung runtime atau disimpan jika perlu, di DB helper ada kolomnya
      'status': status,
      'tampil_di_struk': tampilDiStruk ? 1 : 0,
      'tampil_di_laporan': tampilDiLaporan ? 1 : 0,
      'tampil_di_stok': tampilDiStok ? 1 : 0,
      // created_at dan updated_at biasanya dikelola DB atau manual
    };
  }

  factory DokumenStok.fromMap(Map<String, dynamic> map) {
    return DokumenStok(
      id: map['id'] as int?,
      profilId: map['profil_id'] as int?,
      jenis: map['jenis'] == 'keluar' || map['jenis'] == 'JenisDokumen.keluar' ? JenisDokumen.keluar : JenisDokumen.masuk,
      judul: map['judul'] as String? ?? '',
      tanggal: DateTime.parse(map['tanggal'] as String),
      keterangan: map['keterangan'] as String?,
      pembeliId: map['pembeli_id'] as int?,
      penyuplaiId: map['penyuplai_id'] as int?,
      totalAkhir: (map['total_akhir'] as num?)?.toDouble() ?? 0.0,
      nominalBayar: (map['nominal_bayar'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'DIBAYAR',
      tampilDiStruk: (map['tampil_di_struk'] ?? 1) == 1,
      tampilDiLaporan: (map['tampil_di_laporan'] ?? 1) == 1,
      tampilDiStok: (map['tampil_di_stok'] ?? 1) == 1,
    );
  }
}
