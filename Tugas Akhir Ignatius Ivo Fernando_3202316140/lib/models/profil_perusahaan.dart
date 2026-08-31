class ProfilPerusahaan {
  final int? id;
  final String namaPerusahaan;
  final String jenisIndustri;
  final String negara;
  final String provinsi;
  final String kota;
  final String alamat;
  final String? fotoPath;
  final String? headerStruk; // Tambahan
  final String? footerStruk; // Tambahan
  final bool notifikasiAktif; // Tambahan

  ProfilPerusahaan({
    this.id,
    required this.namaPerusahaan,
    required this.jenisIndustri,
    required this.negara,
    required this.provinsi,
    required this.kota,
    required this.alamat,
    this.fotoPath,
    this.headerStruk,
    this.footerStruk,
    this.notifikasiAktif = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_perusahaan': namaPerusahaan,
      'jenis_industri': jenisIndustri,
      'negara': negara,
      'provinsi': provinsi,
      'kota': kota,
      'alamat': alamat,
      'foto_path': fotoPath,
      'header_struk': headerStruk,
      'footer_struk': footerStruk,
      'notifikasi_aktif': notifikasiAktif ? 1 : 0,
    };
  }

  factory ProfilPerusahaan.fromMap(Map<String, dynamic> map) {
    return ProfilPerusahaan(
      id: map['id'] as int?,
      namaPerusahaan: map['nama_perusahaan'] ?? '',
      jenisIndustri: map['jenis_industri'] ?? '',
      negara: map['negara'] ?? '',
      provinsi: map['provinsi'] ?? '',
      kota: map['kota'] ?? '',
      alamat: map['alamat'] ?? '',
      fotoPath: map['foto_path'],
      headerStruk: map['header_struk'],
      footerStruk: map['footer_struk'],
      notifikasiAktif: (map['notifikasi_aktif'] ?? 1) == 1,
    );
  }
}