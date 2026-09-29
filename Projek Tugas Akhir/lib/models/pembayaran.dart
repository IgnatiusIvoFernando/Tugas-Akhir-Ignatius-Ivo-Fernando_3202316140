import 'package:intl/intl.dart';

class RiwayatPembayaran {
  final int? id;
  final int dokumenId;
  final double nominal;
  final DateTime tanggal;
  final String? keterangan;

  RiwayatPembayaran({
    this.id,
    required this.dokumenId,
    required this.nominal,
    DateTime? tanggal,
    this.keterangan,
  })  : assert(dokumenId > 0, 'Dokumen ID harus lebih dari 0'),
        assert(nominal != 0, 'Nominal tidak boleh 0'),
        tanggal = tanggal ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dokumen_id': dokumenId,
      'nominal': nominal,
      'tanggal': tanggal.toIso8601String(),
      'keterangan': keterangan,
    };
  }

  factory RiwayatPembayaran.fromMap(Map<String, dynamic> map) {
    // Parse id
    final id = map['id'] as int?;

    // Parse dokumenId
    final dokumenId = map['dokumen_id'] as int? ?? 0;

    // Parse nominal
    final nominal = (map['nominal'] as num?)?.toDouble() ?? 0.0;

    // Parse tanggal
    DateTime tanggal;
    final tanggalRaw = map['tanggal'];
    if (tanggalRaw is String && tanggalRaw.isNotEmpty && tanggalRaw != 'null') {
      try {
        tanggal = DateTime.parse(tanggalRaw);
      } catch (_) {
        tanggal = DateTime.now();
      }
    } else {
      tanggal = DateTime.now();
    }

    // Parse keterangan
    final keterangan = map['keterangan'] as String?;

    return RiwayatPembayaran(
      id: id,
      dokumenId: dokumenId,
      nominal: nominal,
      tanggal: tanggal,
      keterangan: keterangan,
    );
  }

  // ================= GETTER =================

  bool get isPembayaran => nominal > 0;
  bool get isPengembalian => nominal < 0;

  String get nominalFormatted {
    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(nominal.abs());
  }

  String get statusText {
    if (nominal > 0) return 'Pembayaran';
    if (nominal < 0) return 'Pengembalian';
    return 'Unknown';
  }

  // ================= HELPER =================

  RiwayatPembayaran copyWith({
    int? id,
    int? dokumenId,
    double? nominal,
    DateTime? tanggal,
    String? keterangan,
  }) {
    return RiwayatPembayaran(
      id: id ?? this.id,
      dokumenId: dokumenId ?? this.dokumenId,
      nominal: nominal ?? this.nominal,
      tanggal: tanggal ?? this.tanggal,
      keterangan: keterangan ?? this.keterangan,
    );
  }

  // ================= VALIDASI =================

  bool get isValid {
    return dokumenId > 0 &&
        nominal != 0;
  }

  Map<String, String> get validationErrors {
    final errors = <String, String>{};
    if (dokumenId <= 0) {
      errors['dokumenId'] = 'Dokumen ID harus lebih dari 0';
    }
    if (nominal == 0) {
      errors['nominal'] = 'Nominal tidak boleh 0';
    }
    return errors;
  }
}