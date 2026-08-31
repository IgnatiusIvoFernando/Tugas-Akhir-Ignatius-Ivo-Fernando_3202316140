import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controller/dokumen_controller.dart';
import '../../models/barang.dart';
import '../../models/dokumen_stok.dart';
import '../../models/dokumen_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

/// Halaman untuk melakukan penyesuaian (koreksi) stok barang secara manual.
/// Bisa digunakan untuk satu barang maupun banyak barang sekaligus (masal).
class AdjustmentStokPage extends StatefulWidget {
  final List<Barang> items;
  const AdjustmentStokPage({super.key, required this.items});

  /// Shortcut untuk membuka halaman koreksi khusus satu barang.
  factory AdjustmentStokPage.single({required Barang barang}) =>
      AdjustmentStokPage(items: [barang]);

  @override
  State<AdjustmentStokPage> createState() => _AdjustmentStokPageState();
}

class _AdjustmentStokPageState extends State<AdjustmentStokPage> {
  // Map untuk menampung TextEditingController input Qty berdasarkan ID barang.
  final Map<int, TextEditingController> _mapQtyController = {};
  late TextEditingController _alasanController;

  // Variabel penentu apakah operasi yang dilakukan adalah Penambahan (+) atau Pengurangan (-).
  bool _isOperasiTambah = true;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller Qty untuk setiap barang yang ada di daftar.
    for (var barang in widget.items) {
      _mapQtyController[barang.id!] = TextEditingController();
    }

    // Default teks alasan koreksi.
    _alasanController = TextEditingController(
        text: widget.items.length > 1 ? "Koreksi Stok Masal" : "Koreksi Stok");
  }

  @override
  void dispose() {
    // Memastikan semua controller dibersihkan dari memori saat halaman ditutup.
    for (var controller in _mapQtyController.values) {
      controller.dispose();
    }
    _alasanController.dispose();
    super.dispose();
  }

  /// Memformat angka stok agar tampilan desimalnya rapi (menghilangkan .0 jika bulat).
  String _formatStok(double stok, String satuan) {
    if (stok % 1 == 0) {
      return '${AppStyles.formatNumber(stok)} $satuan';
    } else {
      final int decimals = stok.toString().split('.').length > 1
          ? stok.toString().split('.')[1].length
          : 1;
      return '${stok.toStringAsFixed(decimals)} $satuan';
    }
  }

  /// Logika utama untuk memvalidasi input dan menyimpan perubahan stok ke database.
  Future<void> _simpanProsesKoreksi() async {
    final alasan = _alasanController.text.trim();
    if (alasan.isEmpty) {
      return _tampilkanPesan("Alasan koreksi harus diisi");
    }

    List<DokumenItem> itemsToProcess = [];
    for (var barang in widget.items) {
      final inputTeks = _mapQtyController[barang.id!]!.text;
      if (inputTeks.isNotEmpty) {
        final jumlahInput = AppStyles.parseNumber(inputTeks);
        if (jumlahInput > 0) {
          // Validasi stok jika operasi pengurangan agar tidak menjadi negatif (di bawah nol).
          if (!_isOperasiTambah && barang.stok < jumlahInput) {
            return AppStyles.showWarningSnackBar(context, "Stok ${barang.nama} tidak cukup untuk dikurangi");
          }

          // Menyusun item untuk dimasukkan ke dalam dokumen transaksi.
          itemsToProcess.add(DokumenItem(
            dokumenId: 0,
            barangId: barang.id!,
            qty: jumlahInput,
            harga: _isOperasiTambah ? barang.hargaBeli : barang.hargaJual,
          ));
        }
      }
    }

    if (itemsToProcess.isEmpty) {
      return AppStyles.showWarningSnackBar(context, "Masukkan jumlah koreksi");
    }

    // Dialog konfirmasi sebelum benar-benar menyimpan ke database.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Koreksi Stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda akan ${_isOperasiTambah ? "menambahkan" : "mengurangi"} stok untuk ${itemsToProcess.length} barang.'),
            const SizedBox(height: 8),
            Text('Alasan: $alasan', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'KONFIRMASI',
              style: TextStyle(color: _isOperasiTambah ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final controller = DokumenController();
      // Membuat objek DokumenStok sebagai catatan riwayat koreksi.
      final dokumen = DokumenStok(
        jenis: _isOperasiTambah ? JenisDokumen.masuk : JenisDokumen.keluar,
        judul: alasan,
        tanggal: DateTime.now(),
        keterangan: alasan,
        status: 'NON-KEUANGAN',
        tampilDiLaporan: false,
        tampilDiStok: true,
        tampilDiStruk: false,
      );

      // Eksekusi penyimpanan transaksi lengkap (dokumen + item + update stok barang).
      await controller.simpanTransaksiLengkap(
        dokumen: dokumen,
        items: itemsToProcess,
      );

      if (mounted) {
        AppStyles.showSuccessSnackBar(context, "Stok berhasil diperbarui");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, "Gagal menyimpan: ${e.toString()}");
    }
  }

  /// Helper untuk memunculkan SnackBar di bagian bawah layar.
  void _tampilkanPesan(String pesan) {
    AppStyles.showSnackBar(context, pesan);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
            widget.items.length > 1 ? 'Koreksi Masal' : 'Koreksi Stok Manual',
            style: AppStyles.appBarTitle
        ),
        backgroundColor: AppColors.primary,
        iconTheme: AppStyles.appBarIconTheme,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                for (var controller in _mapQtyController.values) {
                  controller.clear();
              }
              });
            }, icon: const Icon(Icons.rotate_right_outlined),
          )
        ]
      ),
      body: Column(
        children: [
          // Widget untuk memilih Tambah/Kurang dan input Alasan.
          _buildPanelPilihanOperasi(),
          // Daftar barang yang bisa diinput jumlah koreksinya.
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) => _buildBarisInputBarang(widget.items[index]),
            ),
          ),
          // Tombol aksi simpan di bagian bawah.
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomPadding),
            child: ElevatedButton(
                onPressed: _simpanProsesKoreksi,
                style: AppStyles.primaryButton,
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text("SIMPAN PERUBAHAN STOK"))
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian panel atas: Pilihan operasi (+/-) dan TextField Alasan.
  Widget _buildPanelPilihanOperasi() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text("TAMBAH (+)")),
                selected: _isOperasiTambah,
                onSelected: (_) => setState(() => _isOperasiTambah = true),
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(color: _isOperasiTambah ? Colors.green.shade900 : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text("KURANG (-)")),
                selected: !_isOperasiTambah,
                onSelected: (_) => setState(() => _isOperasiTambah = false),
                selectedColor: Colors.red.shade100,
                labelStyle: TextStyle(color: !_isOperasiTambah ? Colors.red.shade900 : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _alasanController,
          decoration: AppStyles.inputDecoration("Alasan Koreksi (Contoh: Barang Rusak)", icon: Icons.comment_bank_rounded),
        ),
      ],
    ),
  );

  /// Widget baris untuk setiap barang yang menampilkan nama, stok saat ini, dan input Qty koreksi.
  Widget _buildBarisInputBarang(Barang barang) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(barang.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Stok Saat Ini: ${_formatStok(barang.stok, barang.satuan)}',
                style: barang.stok < 5 ? TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700) : AppStyles.caption,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Input jumlah yang akan disesuaikan.
        SizedBox(
          width: 100,
          child: TextField(
            controller: _mapQtyController[barang.id],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+[.,]?[0-9]*$'))
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    ),
  );
}
