import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tugas_akhir/theme/app_styles.dart';
import 'package:tugas_akhir/view/widgets/app_drawer.dart';
import 'package:tugas_akhir/view/laporan/tabel_dokumen.dart';
import 'package:tugas_akhir/controller/dokumen_controller.dart';
import '../../theme/app_colors.dart';

/// Halaman Daftar Riwayat Arus Barang (Harian - Khusus Mutasi Stok/Non-Keuangan)
class DokumenStokPage extends StatefulWidget {
  const DokumenStokPage({super.key});

  @override
  State<DokumenStokPage> createState() => _DokumenStokPageState();
}

class _DokumenStokPageState extends State<DokumenStokPage> {
  final DokumenController _dokumenController = DokumenController();

  List<Map<String, dynamic>> _daftarTanggalSemua = [];
  List<Map<String, dynamic>> _daftarTanggalTerfilter = [];
  bool _sedangMemuat = true;
  bool _sedangMenghapus = false;

  final Set<String> _kumpulanTanggalTerpilih = {};
  bool _isModeSeleksi = false;

  DateTime _tanggalMulai = DateTime.now().subtract(const Duration(days: 30));
  DateTime _tanggalSelesai = DateTime.now();

  @override
  void initState() {
    super.initState();
    _muatDataTanggal();
  }

  Future<void> _muatDataTanggal() async {
    if (!mounted) return;
    setState(() => _sedangMemuat = true);
    try {
      final hasil = await _dokumenController.getPeriodeDokumen(onlyNonFinancial: true);
      if (!mounted) return;
      setState(() {
        _daftarTanggalSemua = hasil;
        _terapkanFilter();
        _sedangMemuat = false;
        _kumpulanTanggalTerpilih.clear();
        _isModeSeleksi = false;
      });
    } catch (e) {
      debugPrint('Error memuat data harian stok: $e');
      if (mounted) setState(() => _sedangMemuat = false);
    }
  }

  void _terapkanFilter() {
    setState(() {
      _daftarTanggalTerfilter = _daftarTanggalSemua.where((item) {
        try {
          final tglItem = DateTime.parse(item['tanggal'].toString());
          final start = DateTime(_tanggalMulai.year, _tanggalMulai.month, _tanggalMulai.day);
          final end = DateTime(_tanggalSelesai.year, _tanggalSelesai.month, _tanggalSelesai.day);
          final itemDate = DateTime(tglItem.year, tglItem.month, tglItem.day);

          return (itemDate.isAtSameMomentAs(start) || itemDate.isAfter(start)) &&
              (itemDate.isAtSameMomentAs(end) || itemDate.isBefore(end));
        } catch (_) {
          return false;
        }
      }).toList();
    });
  }

  Future<void> _pilihRentangTanggal() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _tanggalMulai, end: _tanggalSelesai),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'PILIH RENTANG TANGGAL ARUS BARANG',
    );

    if (picked != null) {
      setState(() {
        _tanggalMulai = picked.start;
        _tanggalSelesai = picked.end;
      });
      _terapkanFilter();
    }
  }

  Future<void> _prosesHapusMasal() async {
    if (_kumpulanTanggalTerpilih.isEmpty) return;

    setState(() => _sedangMenghapus = true);
    int berhasil = 0;
    int gagal = 0;

    try {
      for (String tgl in _kumpulanTanggalTerpilih) {
        try {
          await _dokumenController.deleteDokumenByTanggal(tgl, onlyNonFinancial: true);
          berhasil++;
        } catch (e) {
          gagal++;
          debugPrint('Gagal hapus mutasi tanggal $tgl: $e');
        }
      }

      if (!mounted) return;
      if (gagal > 0) {
        AppStyles.showWarningSnackBar(context, 'Berhasil hapus $berhasil tanggal mutasi, gagal $gagal');
      } else {
        AppStyles.showSuccessSnackBar(context, 'Berhasil hapus $berhasil tanggal mutasi');
      }

      _muatDataTanggal();
    } catch (e) {
      if (mounted) {
        AppStyles.showErrorSnackBar(context, 'Gagal menghapus: $e');
      }
    } finally {
      if (mounted) setState(() => _sedangMenghapus = false);
    }
  }

  void _pilihSemuaTampil() {
    setState(() {
      for (var item in _daftarTanggalTerfilter) {
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
      drawer: _isModeSeleksi ? null : const AppDrawer(selectedMenu: 'dokumen'),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _sedangMemuat
                ? const Center(child: CircularProgressIndicator())
                : _sedangMenghapus
                ? _buildLoadingHapus()
                : _daftarTanggalTerfilter.isEmpty
                ? _buildEmptyState()
                : _buildListPeriode(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppStyles.selectionAppBar(
      isModeSeleksi: _isModeSeleksi,
      selectedCount: _kumpulanTanggalTerpilih.length,
      title: 'Laporan Stok',
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
            onPressed: _kumpulanTanggalTerpilih.isEmpty ? null : _tampilkanKonfirmasiHapus,
          ),
        ],
      ],
    );
  }

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
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${formatTgl.format(_tanggalMulai)}  s/d  ${formatTgl.format(_tanggalSelesai)}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.black87),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingHapus() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Menghapus data mutasi...'),
        ],
      ),
    );
  }

  Widget _buildListPeriode() {
    final sortedList = List<Map<String, dynamic>>.from(_daftarTanggalTerfilter);
    sortedList.sort((a, b) => b['tanggal'].toString().compareTo(a['tanggal'].toString()));

    return ListView.builder(
      padding: AppStyles.listViewPadding,
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final item = sortedList[index];
        final tglMentah = item['tanggal'].toString();
        final isSelected = _kumpulanTanggalTerpilih.contains(tglMentah);

        return Padding(
          padding: AppStyles.listItemPadding,
          child: ListTile(
            tileColor: AppStyles.tileBackgroundColor,
            selected: isSelected,
            selectedTileColor: AppStyles.selectedTileColor,
            shape: AppStyles.selectionShape(isSelected),
            leading: _isModeSeleksi
                ? Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (_) => _toggleSeleksi(tglMentah),
            )
                : const Icon(Icons.inventory_2, color: AppColors.tertiary),
            title: Text(
              _formatTanggalDisplay(tglMentah),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${item['jumlah_transaksi'] ?? 0} Mutasi Stok', maxLines: 1, overflow: TextOverflow.ellipsis),
            onLongPress: () => _mulaiModeSeleksi(tglMentah),
            onTap: () {
              if (_isModeSeleksi) {
                _toggleSeleksi(tglMentah);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TabelDokumenStokPage(
                      tanggal: tglMentah,
                      bulanNama: _getBulanName(tglMentah),
                      tahun: _getTahun(tglMentah),
                    ),
                  ),
                ).then((_) => _muatDataTanggal());
              }
            },
          ),
        );
      },
    );
  }

  String _formatTanggalDisplay(String tglMentah) {
    try {
      final tglObjek = DateTime.parse(tglMentah);
      return DateFormat('EEEE, dd MMMM yyyy', 'id').format(tglObjek);
    } catch (_) { return tglMentah; }
  }

  String _getBulanName(String tglMentah) {
    try {
      return DateFormat('MMMM', 'id').format(DateTime.parse(tglMentah));
    } catch (_) { return ''; }
  }

  String _getTahun(String tglMentah) {
    try {
      return DateFormat('yyyy').format(DateTime.parse(tglMentah));
    } catch (_) { return ''; }
  }

  void _mulaiModeSeleksi(String tgl) {
    setState(() { _isModeSeleksi = true; _kumpulanTanggalTerpilih.add(tgl); });
  }

  void _toggleSeleksi(String tgl) {
    setState(() {
      if (!_kumpulanTanggalTerpilih.remove(tgl)) {
        _kumpulanTanggalTerpilih.add(tgl);
      }
    });
  }

  void _tampilkanKonfirmasiHapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Mutasi?'),
        content: Text('Hapus ${_kumpulanTanggalTerpilih.length} tanggal mutasi? Data penjualan/pembelian tidak akan ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _prosesHapusMasal(); },
            child: const Text('HAPUS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: AppColors.disabled),
          SizedBox(height: 12),
          Text('Tidak ada riwayat mutasi stok'),
        ],
      ),
    );
  }
}
