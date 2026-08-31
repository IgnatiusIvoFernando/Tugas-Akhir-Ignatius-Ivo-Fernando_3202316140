// ==================== DAFTAR_TRANSAKSI_PAGE.dart ====================
// Halaman ini berfungsi untuk menampilkan ringkasan transaksi keuangan harian.
// Fitur utama: Filter rentang tanggal, pemilihan masal (multi-select), dan hapus data.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tugas_akhir/view/widgets/app_drawer.dart';
import '../../controller/dokumen_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import 'tabel_transaksi.dart';

class DaftarTransaksiPage extends StatefulWidget {
  const DaftarTransaksiPage({super.key});

  @override
  State<DaftarTransaksiPage> createState() => _DaftarTransaksiPageState();
}

class _DaftarTransaksiPageState extends State<DaftarTransaksiPage> {
  // Inisialisasi controller untuk menangani logika database dokumen/transaksi
  final DokumenController _dokumenController = DokumenController();

  // State Management Sederhana:
  List<Map<String, dynamic>> _daftarTanggalSemua = []; // Menampung semua data dari database
  List<Map<String, dynamic>> _daftarTerfilter = [];     // Menampung data yang sudah difilter tanggal
  bool _sedangMemuat = true;                           // Indikator loading
  final Set<String> _kumpulanTanggalTerpilih = {};     // Menyimpan ID (tanggal) yang dipilih saat mode seleksi
  bool _isModeSeleksi = false;                         // Status apakah sedang dalam mode pilih banyak

  // Default filter: 30 hari terakhir sampai hari ini
  DateTime _tanggalMulai = DateTime.now().subtract(const Duration(days: 30));
  DateTime _tanggalSelesai = DateTime.now();

  @override
  void initState() {
    super.initState();
    _muatDaftarTanggal(); // Memanggil data saat pertama kali halaman dibuka
  }

  /// Mengambil data dari database melalui controller
  Future<void> _muatDaftarTanggal() async {
    if (!mounted) return;
    setState(() => _sedangMemuat = true);

    try {
      // Mengambil daftar tanggal yang memiliki transaksi keuangan (onlyFinancial: true)
      final hasilQuery = await _dokumenController.getPeriodeDokumen(onlyFinancial: true);

      if (!mounted) return;
      setState(() {
        _daftarTanggalSemua = hasilQuery;
        _terapkanFilter(); // Setelah data dimuat, langsung terapkan filter tanggal yang aktif
        _sedangMemuat = false;
        _kumpulanTanggalTerpilih.clear();
        _isModeSeleksi = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat data tanggal: $e');
      if (mounted) setState(() => _sedangMemuat = false);
    }
  }

  /// Logika untuk memfilter list berdasarkan rentang tanggal yang dipilih user
  /// Optimasi performa dengan mendefinisikan batas waktu di luar loop
  void _terapkanFilter() {
    // Normalisasi waktu ke jam 00:00:00 untuk perbandingan tanggal yang akurat
    final start = DateTime(_tanggalMulai.year, _tanggalMulai.month, _tanggalMulai.day);
    final end = DateTime(_tanggalSelesai.year, _tanggalSelesai.month, _tanggalSelesai.day);

    setState(() {
      _daftarTerfilter = _daftarTanggalSemua.where((item) {
        try {
          final tglItem = DateTime.parse(item['tanggal'].toString());
          final itemDate = DateTime(tglItem.year, tglItem.month, tglItem.day);

          // Cek apakah itemDate berada di antara start dan end (inklusif)
          return (itemDate.isAtSameMomentAs(start) || itemDate.isAfter(start)) &&
              (itemDate.isAtSameMomentAs(end) || itemDate.isBefore(end));
        } catch (_) {
          return false;
        }
      }).toList();

      // Mengurutkan dari yang terbaru (Descending)
      _daftarTerfilter.sort((a, b) => b['tanggal'].toString().compareTo(a['tanggal'].toString()));
    });
  }

  /// Menampilkan dialog pemilih rentang tanggal bawaan Flutter
  Future<void> _pilihRentangTanggal() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _tanggalMulai, end: _tanggalSelesai),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'PILIH RENTANG TANGGAL LAPORAN',
    );

    if (picked != null) {
      setState(() {
        _tanggalMulai = picked.start;
        _tanggalSelesai = picked.end;
      });
      _terapkanFilter();
    }
  }

  /// Menghapus data secara masal berdasarkan tanggal yang dipilih
  Future<void> _prosesHapusMasal() async {
    if (_kumpulanTanggalTerpilih.isEmpty) return;
    setState(() => _sedangMemuat = true);

    int berhasil = 0;
    int gagal = 0;

    try {
      // Melakukan iterasi penghapusan untuk setiap tanggal yang dicentang
      for (String tgl in _kumpulanTanggalTerpilih) {
        try {
          await _dokumenController.deleteDokumenByTanggal(tgl, onlyFinancial: true);
          berhasil++;
        } catch (e) {
          gagal++;
          debugPrint('Gagal hapus transaksi tanggal $tgl: $e');
        }
      }

      if (mounted) {
        if (gagal > 0) {
          AppStyles.showWarningSnackBar(context, 'Berhasil hapus $berhasil tanggal, gagal $gagal');
        } else {
          AppStyles.showSuccessSnackBar(context, 'Berhasil hapus $berhasil tanggal');
        }
      }
      _muatDaftarTanggal(); // Refresh data setelah penghapusan selesai
    } catch (e) {
      if (mounted) {
        AppStyles.showErrorSnackBar(context, 'Gagal memproses penghapusan: $e');
        setState(() => _sedangMemuat = false);
      }
    }
  }

  // --- Fungsi-fungsi Pembantu Mode Seleksi ---

  void _pilihSemuaTampil() {
    setState(() {
      for (var item in _daftarTerfilter) {
        _kumpulanTanggalTerpilih.add(item['tanggal'].toString());
      }
      _isModeSeleksi = true;
    });
  }

  void _bersihkanSeleksi() {
    setState(() {
      _kumpulanTanggalTerpilih.clear();
    });
  }

  void _tutupModeSeleksi() {
    setState(() {
      _kumpulanTanggalTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sembunyikan Drawer jika sedang dalam mode seleksi agar user fokus
      drawer: _isModeSeleksi ? null : const AppDrawer(selectedMenu: 'laporan_transaksi'),
      appBar: AppStyles.selectionAppBar(
        isModeSeleksi: _isModeSeleksi,
        selectedCount: _kumpulanTanggalTerpilih.length,
        title: 'Laporan Keuangan',
        onClose: _tutupModeSeleksi,
        actions: [
          if (_isModeSeleksi) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: "Pilih Semua",
              onPressed: _pilihSemuaTampil,
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: "Batal Pilih",
              onPressed: _bersihkanSeleksi,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              // Tombol hapus nonaktif jika tidak ada yang dipilih
              onPressed: _kumpulanTanggalTerpilih.isEmpty ? null : _konfirmasiHapus,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(), // Barisan filter tanggal di bagian atas
          Expanded(
            child: _sedangMemuat
                ? const Center(child: CircularProgressIndicator())
                : _daftarTerfilter.isEmpty
                ? _buildEmptyState() // Tampilan jika data kosong
                : _buildListView(),  // Daftar transaksi
          ),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan bar filter tanggal yang bisa diklik
  Widget _buildFilterBar() {
    final formatTgl = DateFormat('dd MMM yyyy', 'id');
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.blue50,
      child: InkWell(
        onTap: _pilihRentangTanggal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.disabled),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatTgl.format(_tanggalMulai)}  s/d  ${formatTgl.format(_tanggalSelesai)}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.black87),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget utama untuk menampilkan daftar data dalam bentuk List
  Widget _buildListView() {
    return ListView.builder(
      padding: AppStyles.listViewPadding,
      itemCount: _daftarTerfilter.length,
      itemBuilder: (context, index) {
        final item = _daftarTerfilter[index];
        final tglMentah = item['tanggal'].toString();
        final DateTime tglObjek = DateTime.parse(tglMentah);

        // Format tanggal Indonesia: Senin, 01 Januari 2024
        final formatHariDanTanggal = DateFormat('EEEE, dd MMMM yyyy', 'id').format(tglObjek);
        final isDipilih = _kumpulanTanggalTerpilih.contains(tglMentah);

        return Padding(
          padding: AppStyles.listItemPadding,
          child: ListTile(
            tileColor: AppStyles.tileBackgroundColor,
            selected: isDipilih,
            selectedTileColor: AppStyles.selectedTileColor,
            shape: AppStyles.selectionShape(isDipilih),
            leading: _isModeSeleksi
                ? Checkbox(
              value: isDipilih,
              activeColor: AppColors.primary,
              onChanged: (v) => _ubahStatusSeleksi(tglMentah),
            )
                : const Icon(Icons.date_range_rounded, color: AppColors.primary),
            title: Text(
              formatHariDanTanggal, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item['jumlah_transaksi'] ?? 0} Transaksi Keuangan', 
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Tekan lama untuk mengaktifkan mode seleksi
            onLongPress: () => _mulaiModeSeleksi(tglMentah),
            onTap: () {
              if (_isModeSeleksi) {
                _ubahStatusSeleksi(tglMentah);
              } else {
                // Jika tidak mode seleksi, masuk ke detail transaksi di tanggal tersebut
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TabelTransaksiKeuanganPage(tanggal: tglMentah))
                ).then((_) => _muatDaftarTanggal()); // Refresh data saat kembali dari halaman detail
              }
            },
          ),
        );
      },
    );
  }

  void _mulaiModeSeleksi(String tgl) {
    setState(() { _isModeSeleksi = true; _kumpulanTanggalTerpilih.add(tgl); });
  }

  void _ubahStatusSeleksi(String tgl) {
    setState(() {
      if (!_kumpulanTanggalTerpilih.remove(tgl)) {
        _kumpulanTanggalTerpilih.add(tgl);
      }
      // Matikan mode seleksi otomatis jika tidak ada item yang terpilih
      _isModeSeleksi = _kumpulanTanggalTerpilih.isNotEmpty;
    });
  }

  /// Menampilkan dialog konfirmasi sebelum benar-benar menghapus data
  void _konfirmasiHapus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Transaksi Harian?'),
        content: Text('Hapus ${_kumpulanTanggalTerpilih.length} tanggal terpilih? Semua transaksi pada tanggal tersebut akan hilang selamanya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _prosesHapusMasal();
              },
              child: const Text('HAPUS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  /// Tampilan placeholder jika tidak ada data yang ditemukan
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 60, color: AppColors.disabled),
          SizedBox(height: 12),
          Text('Tidak ada laporan keuangan pada periode ini'),
        ],
      ),
    );
  }
}
