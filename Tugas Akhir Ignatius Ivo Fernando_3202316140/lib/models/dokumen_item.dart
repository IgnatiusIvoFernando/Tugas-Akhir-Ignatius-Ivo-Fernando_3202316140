class DokumenItem {
  final int? id;
  final int dokumenId;
  final int barangId;
  final double qty;
  final double harga;
  final double diskon;
  final double subtotal;

  DokumenItem({
    this.id,
    required this.dokumenId,
    required this.barangId,
    required this.qty,
    required this.harga,
    this.diskon = 0.0,
  })  : assert(qty >= 0, 'Qty tidak boleh negatif'),
        assert(harga >= 0, 'Harga tidak boleh negatif'),
        assert(diskon >= 0 && diskon <= 100, 'Diskon harus antara 0-100%'),
        subtotal = _hitungSubtotal(harga, qty, diskon);

  // Constructor untuk reconstruct dari database dengan subtotal yang sudah ada
  DokumenItem.fromDatabase({
    this.id,
    required this.dokumenId,
    required this.barangId,
    required this.qty,
    required this.harga,
    this.diskon = 0.0,
    required this.subtotal,
  });

  static double _hitungSubtotal(double harga, double qty, double diskon) {
    final hargaTotal = harga * qty;
    final diskonValue = hargaTotal * (diskon / 100);
    return hargaTotal - diskonValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dokumen_id': dokumenId,
      'barang_id': barangId,
      'qty': qty,
      'harga': harga,
      'diskon': diskon,
      'subtotal': subtotal,
    };
  }

  factory DokumenItem.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as int?;
    final dokumenId = map['dokumen_id'] as int? ?? 0;
    final barangId = map['barang_id'] as int? ?? 0;
    final qty = (map['qty'] as num?)?.toDouble() ?? 0.0;
    final harga = (map['harga'] as num?)?.toDouble() ?? 0.0;
    final diskon = (map['diskon'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (map['subtotal'] as num?)?.toDouble();

    if (subtotal != null) {
      return DokumenItem.fromDatabase(
        id: id,
        dokumenId: dokumenId,
        barangId: barangId,
        qty: qty,
        harga: harga,
        diskon: diskon,
        subtotal: subtotal,
      );
    } else {
      return DokumenItem(
        id: id,
        dokumenId: dokumenId,
        barangId: barangId,
        qty: qty,
        harga: harga,
        diskon: diskon,
      );
    }
  }

  // ================= GETTER =================
  double get hargaTotal => harga * qty;
  double get diskonValue => hargaTotal * (diskon / 100);
  double get hargaSetelahDiskon => hargaTotal - diskonValue;

  // ================= HELPER =================
  DokumenItem copyWith({
    int? id,
    int? dokumenId,
    int? barangId,
    double? qty,
    double? harga,
    double? diskon,
  }) {
    return DokumenItem(
      id: id ?? this.id,
      dokumenId: dokumenId ?? this.dokumenId,
      barangId: barangId ?? this.barangId,
      qty: qty ?? this.qty,
      harga: harga ?? this.harga,
      diskon: diskon ?? this.diskon,
    );
  }

  // ================= VALIDASI =================
  bool get isValid {
    return qty >= 0 &&
        harga >= 0 &&
        diskon >= 0 &&
        diskon <= 100 &&
        barangId > 0 &&
        dokumenId > 0;
  }

  Map<String, String> get validationErrors {
    final errors = <String, String>{};
    if (qty < 0) errors['qty'] = 'Qty tidak boleh negatif';
    if (harga < 0) errors['harga'] = 'Harga tidak boleh negatif';
    if (diskon < 0 || diskon > 100) {
      errors['diskon'] = 'Diskon harus antara 0-100%';
    }
    if (barangId <= 0) errors['barangId'] = 'Barang ID tidak valid';
    if (dokumenId <= 0) errors['dokumenId'] = 'Dokumen ID tidak valid';
    return errors;
  }
}