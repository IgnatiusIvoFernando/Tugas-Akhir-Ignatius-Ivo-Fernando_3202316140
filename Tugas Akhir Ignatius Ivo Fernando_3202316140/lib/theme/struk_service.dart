import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tugas_akhir/controller/profil_controller.dart';
import 'package:tugas_akhir/models/profil_perusahaan.dart';
import '../controller/database_helper.dart';

/// Service untuk menangani proses pembuatan dan pencetakan struk penjualan dalam bentuk PDF.
/// Struk ini dirancang khusus untuk printer thermal (lebar 80mm).
class StrukService {
  // Formatter untuk mata uang Rupiah
  static final _formatRupiah = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Fungsi untuk mencetak ulang struk berdasarkan ID dokumen.
  /// Fungsi ini mengambil data lengkap dari database sehingga formatnya konsisten.
  static Future<void> cetakLagi(int id) async {
    final db = await DatabaseHelper().database;

    // 1. Ambil Data Header & Pembeli
    final hasilDoc = await db.rawQuery('''
      SELECT ds.*, p.nama as pembeli_nama
      FROM dokumen_stok ds
      LEFT JOIN pembeli p ON ds.pembeli_id = p.id
      WHERE ds.id = ?
    ''', [id]);

    if (hasilDoc.isEmpty) throw Exception("Data transaksi tidak ditemukan");
    final item = hasilDoc.first;

    // 2. Ambil Data Item Barang
    final itemsRaw = await db.rawQuery('''
      SELECT b.nama, di.qty, di.harga
      FROM dokumen_item di
      JOIN barang b ON di.barang_id = b.id
      WHERE di.dokumen_id = ?
    ''', [id]);

    // 3. Rekonstruksi Data
    double totalKotor = 0;
    final List<Map<String, dynamic>> itemsList = [];

    for (var i in itemsRaw) {
      final double qty = (i['qty'] as num).toDouble();
      final double harga = (i['harga'] as num).toDouble();
      final double subtotal = qty * harga;
      totalKotor += subtotal;

      itemsList.add({
        'nama': i['nama'],
        'qty': qty,
        'harga': harga,
        'subtotal': subtotal,
      });
    }

    final double diskonPersen = (item['diskon_persen'] as num?)?.toDouble() ?? 0;
    final double pajakPersen = (item['pajak_persen'] as num?)?.toDouble() ?? 0;
    final double nominalDiskon = totalKotor * (diskonPersen / 100);
    final double setelahDiskon = totalKotor - nominalDiskon;
    final double nominalPajak = setelahDiskon * (pajakPersen / 100);

    final data = {
      'id': item['id'],
      'tanggal': item['tanggal'],
      'pembeli': (item['pembeli_nama'] == null || item['pembeli_nama'].toString().isEmpty)
          ? 'Pelanggan Umum'
          : item['pembeli_nama'],
      'status': item['status'],
      'total_kotor': totalKotor,
      'nominal_diskon': nominalDiskon,
      'nominal_pajak': nominalPajak,
      'total_akhir': (item['total_akhir'] as num?)?.toDouble() ?? 0,
      'nominal_bayar': (item['nominal_bayar'] as num?)?.toDouble() ?? 0,
      'diskon_persen': diskonPersen,
      'pajak_persen': pajakPersen,
      'items': itemsList,
    };

    // 4. Jalankan perintah cetak
    await cetakStrukPenjualan(transaksi: data, items: itemsList);
  }

  /// Fungsi utama untuk mencetak struk penjualan.
  /// [transaksi] berisi data header transaksi.
  /// [items] berisi daftar barang yang dibeli.
  static Future<void> cetakStrukPenjualan({
    required Map<String, dynamic> transaksi,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final pdf = pw.Document();
      // Mengambil data profil perusahaan (nama toko, alamat, dll)
      final ProfilPerusahaan? profil = await ProfilController().getProfil();
      // Cek status pembayaran
      final bool statusLunas = transaksi['status'] == 'DIBAYAR';
      // Gabungkan items dari parameter atau dari data transaksi
      final itemsList = items ?? transaksi['items'] ?? [];

      // Menambahkan halaman ke dokumen PDF
      pdf.addPage(
        pw.Page(
          // Menggunakan pw.Page biasa untuk roll80 karena roll80 memiliki tinggi tak terhingga (infinite).
          pageFormat: PdfPageFormat.roll80.copyWith(
            marginLeft: 4,
            marginRight: 4,
            marginTop: 8,
            marginBottom: 8,
          ),
          // Membangun konten struk
          build: (pw.Context context) {
            // Gunakan pw.Align di sini untuk memastikan konten tetap di kiri (TopLeft)
            // karena pw.Page tidak memiliki parameter alignment.
            return pw.Align(
              alignment: pw.Alignment.topLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // 1. Header: Informasi Toko
                  pw.Center(child: _buildHeader(profil)),
                  pw.SizedBox(height: 4),
                  // Judul Struk
                  pw.Center(
                    child: pw.Text(
                      'STRUK PENJUALAN',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                  // 2. Info Transaksi: No Struk, Tanggal, Pelanggan
                  _buildInfo(transaksi, statusLunas),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                  // 3. Daftar Barang
                  if (itemsList.isNotEmpty) ..._buildItems(itemsList),

                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                  // 4. Ringkasan: Total, Pajak, Diskon, Bayar, Kembali
                  _buildSummary(transaksi, statusLunas),

                  pw.SizedBox(height: 16),

                  // 5. Footer: Ucapan terima kasih dan pesan tambahan
                  pw.Center(
                    child: pw.Text(
                      'Terima Kasih',
                      style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (profil?.footerStruk != null &&
                      profil!.footerStruk!.isNotEmpty)
                    pw.Center(
                      child: pw.Text(
                        profil.footerStruk!,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

      // Menampilkan dialog print atau langsung cetak ke printer yang terhubung
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            "Struk_${transaksi['id']}_${DateTime.now().millisecondsSinceEpoch}",
        format: PdfPageFormat.roll80,
      );
    } catch (e) {
      throw Exception('Gagal mencetak struk penjualan: $e');
    }
  }

  /// Membangun bagian atas struk (Nama Toko, Alamat, Header Kustom)
  static pw.Widget _buildHeader(ProfilPerusahaan? p) {
    if (p == null) return pw.SizedBox();

    return pw.Column(
      children: [
        pw.Text(
          p.namaPerusahaan.toUpperCase(),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        if (p.alamat.isNotEmpty)
          pw.Text(
            p.alamat,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        if (p.headerStruk != null && p.headerStruk!.isNotEmpty)
          pw.Text(
            p.headerStruk!,
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
      ],
    );
  }

  /// Membangun informasi detail transaksi
  static pw.Widget _buildInfo(Map<String, dynamic> d, bool lunas) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('No: ${d['id']}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            'Tgl: ${_formatTanggal(d['tanggal'])}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Pelanggan: ${d['pembeli'] ?? "Umum"}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Status: ${d['status']}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: lunas ? null : PdfColors.red, // Beri warna merah jika belum lunas
            ),
          ),
        ],
      ),
    );
  }

  /// Membangun daftar item belanja.
  static List<pw.Widget> _buildItems(List<dynamic> items) {
    List<pw.Widget> flatWidgets = [];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final double qty = (item['qty'] as num?)?.toDouble() ?? 0;
      final double harga = (item['harga'] as num?)?.toDouble() ?? 0;
      final double subtotal =
          (item['subtotal'] as num?)?.toDouble() ?? (qty * harga);
      final String nama =
          (item['nama'] ?? item['nama_barang'] ?? "Produk").toString();

      // Baris 1: Nama Barang di kiri (bisa turun baris jika panjang), Subtotal di kanan
      flatWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                nama,
                style: const pw.TextStyle(fontSize: 9),
                softWrap: true,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              _formatRupiah.format(subtotal),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      // Baris 2: Detail perhitungan (Qty x Harga satuan) diletakkan di bawah nama
      flatWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '${_formatQty(qty)} x ${_formatRupiah.format(harga)}',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      );

      // Beri jarak antar item kecuali item terakhir
      if (i < items.length - 1) {
        flatWidgets.add(pw.SizedBox(height: 2));
      }
    }

    return flatWidgets;
  }

  /// Membangun ringkasan pembayaran (Subtotal, Pajak, Diskon, Total Akhir, Bayar, Kembali)
  static pw.Widget _buildSummary(Map<String, dynamic> d, bool lunas) {
    final double totalAkhir = (d['total_akhir'] as num?)?.toDouble() ?? 0;
    final double bayar = (d['nominal_bayar'] as num?)?.toDouble() ?? 0;
    final double diskonPersen = (d['diskon_persen'] as num?)?.toDouble() ?? 0;
    final double pajakPersen = (d['pajak_persen'] as num?)?.toDouble() ?? 0;

    final double nominalDiskon = (d['nominal_diskon'] as num?)?.toDouble() ?? 0;
    final double nominalPajak = (d['nominal_pajak'] as num?)?.toDouble() ?? 0;
    final double subtotal = (d['total_kotor'] as num?)?.toDouble() ?? (totalAkhir + nominalDiskon - nominalPajak);

    final double kembalian = bayar > totalAkhir ? bayar - totalAkhir : 0;
    final double sisaHutang = totalAkhir > bayar ? totalAkhir - bayar : 0;

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _buildRowPdf('SUBTOTAL', _formatRupiah.format(subtotal)),
        if (diskonPersen > 0)
          _buildRowPdf(
            'Diskon ($diskonPersen%)',
            '- ${_formatRupiah.format(nominalDiskon)}',
          ),
        if (pajakPersen > 0)
          _buildRowPdf(
            'Pajak ($pajakPersen%)',
            '+ ${_formatRupiah.format(nominalPajak)}',
          ),
        _buildRowPdf('TOTAL', _formatRupiah.format(totalAkhir), isBold: true),
        _buildRowPdf('BAYAR', _formatRupiah.format(bayar), isBold: true),
        _buildRowPdf(
          lunas ? 'KEMBALIAN' : 'SISA HUTANG',
          _formatRupiah.format(lunas ? kembalian : sisaHutang),
          isBold: !lunas,
        ),
      ],
    );
  }

  /// Helper untuk membuat baris teks Kiri-Kanan (Label: Value)
  static pw.Widget _buildRowPdf(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 11 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBold ? 11 : 9,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper untuk format Quantity (menghilangkan .0 jika bulat)
  static String _formatQty(double value) {
    if (value == 0) return '0';
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    final String str = value.toString();
    final int dotIndex = str.indexOf('.');
    if (dotIndex == -1) return str;
    final String decimals = str.substring(dotIndex + 1);
    if (decimals.length <= 2) return str;
    return value.toStringAsFixed(2);
  }

  /// Helper untuk format tanggal dari berbagai tipe input
  static String _formatTanggal(dynamic tanggal) {
    if (tanggal == null) return '-';
    try {
      if (tanggal is String) {
        return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(tanggal));
      } else if (tanggal is DateTime) {
        return DateFormat('dd/MM/yyyy HH:mm').format(tanggal);
      }
      return '-';
    } catch (_) {
      return '-';
    }
  }
}
