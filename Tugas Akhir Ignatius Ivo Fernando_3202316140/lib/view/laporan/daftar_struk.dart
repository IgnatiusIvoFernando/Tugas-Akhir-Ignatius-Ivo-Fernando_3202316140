import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tugas_akhir/theme/app_styles.dart';
import 'package:tugas_akhir/theme/struk_service.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_drawer.dart';

/// Halaman Riwayat Struk (Khusus Penjualan/Keluar)
class DaftarStrukPage extends StatefulWidget {
  const DaftarStrukPage({super.key});

  @override
  State<DaftarStrukPage> createState() => _DaftarStrukPageState();
}

class _DaftarStrukPageState extends State<DaftarStrukPage> {
  List<Map<String, dynamic>> _daftarStruk = [];
  
  // Menggunakan rentang tanggal seperti di daftar_transaksi.dart
  DateTime _tanggalMulai = DateTime.now().subtract(const Duration(days: 30));
  DateTime _tanggalSelesai = DateTime.now();

  final Set<int> _kumpulanIdTerpilih = {};
  bool _isModeSeleksi = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _muatDataStruk();
  }

  Future<void> _muatDataStruk() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final db = await DatabaseHelper().database;
      
      // Format tanggal ke yyyy-MM-dd untuk kueri SQL
      final startStr = DateFormat('yyyy-MM-dd').format(_tanggalMulai);
      // Tambah 1 hari untuk batas atas agar mencakup seluruh hari terakhir (sampai 23:59:59)
      final endStr = DateFormat('yyyy-MM-dd').format(_tanggalSelesai.add(const Duration(days: 1)));

      final hasil = await db.rawQuery('''
      SELECT 
        ds.*, 
        p.nama as pembeli_nama,
        GROUP_CONCAT(b.nama, ', ') as nama_barang,
        COUNT(di.id) as total_item
      FROM dokumen_stok ds
      LEFT JOIN pembeli p ON ds.pembeli_id = p.id
      JOIN dokumen_item di ON ds.id = di.dokumen_id
      JOIN barang b ON di.barang_id = b.id
      WHERE ds.tanggal >= ? AND ds.tanggal < ? 
        AND ds.status != 'BATAL'
        AND ds.jenis = 'keluar'
        AND ds.tampil_di_struk = 1
      GROUP BY ds.id
      ORDER BY ds.tanggal DESC
    ''', [startStr, endStr]);

      if (!mounted) return;
      setState(() {
        _daftarStruk = hasil;
        _kumpulanIdTerpilih.clear();
        _isModeSeleksi = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error muat data struk: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
      }
    }
  }

  Future<void> _pilihRentangTanggal() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _tanggalMulai, end: _tanggalSelesai),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'PILIH RENTANG TANGGAL STRUK',
    );

    if (picked != null) {
      setState(() {
        _tanggalMulai = picked.start;
        _tanggalSelesai = picked.end;
      });
      _muatDataStruk();
    }
  }

  void _pilihSemuaTampil() {
    setState(() {
      for (var item in _daftarStruk) {
        _kumpulanIdTerpilih.add(item['id'] as int);
      }
      _isModeSeleksi = true;
    });
  }

  void _bersihkanSeleksi() {
    setState(() {
      _kumpulanIdTerpilih.clear();
    });
  }

  void _tutupModeSeleksi() {
    setState(() {
      _kumpulanIdTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _isModeSeleksi ? null : const AppDrawer(selectedMenu: 'struk'),
      appBar: AppStyles.selectionAppBar(
        isModeSeleksi: _isModeSeleksi,
        selectedCount: _kumpulanIdTerpilih.length,
        title: 'Struk Penjualan',
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
              onPressed: _kumpulanIdTerpilih.isEmpty ? null : _konfirmasiHapusMasal,
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _daftarStruk.isEmpty
                ? const Center(child: Text('Tidak ada riwayat struk pada periode ini'))
                : ListView.builder(
                    padding: AppStyles.listViewPadding,
                    itemCount: _daftarStruk.length,
                    itemBuilder: (context, index) => _buildItemStruk(_daftarStruk[index]),
                  ),
          ),
        ],
      ),
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

  Widget _buildItemStruk(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final isSelected = _kumpulanIdTerpilih.contains(id);
    final isHutang = item['status'] == 'HUTANG';

    final namaPembeli = (item['pembeli_nama'] == null || item['pembeli_nama'].toString().isEmpty)
        ? 'Pelanggan Umum'
        : item['pembeli_nama'].toString();
    final namaBarang = item['nama_barang']?.toString() ?? 'Produk';

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
                onChanged: (_) => _ubahStatusSeleksi(id)
              )
            : CircleAvatar(
                backgroundColor: AppColors.blue50,
                child: const Icon(Icons.receipt_long, color: AppColors.primary)
              ),
        title: Text(
          namaPembeli,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
        ),
        subtitle: Text(
          "$namaBarang • ${DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(item['tanggal']))}",
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: !_isModeSeleksi
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHutang) _buildBadgeHutang(),
            IconButton(
              icon: const Icon(Icons.print, color: AppColors.primary),
              onPressed: () async {
                await StrukService.cetakLagi(id);
              },
            ),
          ],
        )
            : null,
        onTap: () async {
          if (_isModeSeleksi) {
            _ubahStatusSeleksi(id);
          } else {
            await StrukService.cetakLagi(id);
          }
        },
        onLongPress: () => _mulaiModeSeleksi(id),
      ),
    );
  }

  Widget _buildBadgeHutang() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
    child: const Text("HUTANG", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
  );

  void _mulaiModeSeleksi(int id) => setState(() { _isModeSeleksi = true; _kumpulanIdTerpilih.add(id); });

  void _ubahStatusSeleksi(int id) => setState(() {
    if (!_kumpulanIdTerpilih.remove(id)) _kumpulanIdTerpilih.add(id);
    _isModeSeleksi = _kumpulanIdTerpilih.isNotEmpty;
  });

  void _konfirmasiHapusMasal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Struk?'),
        content: Text('Hapus ${_kumpulanIdTerpilih.length} struk dari daftar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
          TextButton(onPressed: () { Navigator.pop(ctx); _prosesHapusMasal(); }, child: const Text('HAPUS', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _prosesHapusMasal() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      for (int id in _kumpulanIdTerpilih) {
        await db.update(
          'dokumen_stok',
          {'tampil_di_struk': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      _muatDataStruk();
    } catch (e) {
      if (mounted) {
        AppStyles.showErrorSnackBar(context, 'Gagal: $e');
        setState(() => _isLoading = false);
      }
    }
  }
}
