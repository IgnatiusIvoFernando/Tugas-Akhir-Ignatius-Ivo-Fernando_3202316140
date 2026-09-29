import 'package:flutter/material.dart';
import 'package:tugas_akhir/controller/database_helper.dart';
import 'package:tugas_akhir/theme/app_colors.dart';
import 'package:tugas_akhir/theme/app_styles.dart';

/// Halaman Daftar Kontak (Pemasok & Pelanggan)
/// Mahasiswa dapat menjelaskan ini sebagai implementasi Manajemen Entitas (Entity Management) 
/// yang mendukung multi-tipe (Pelanggan/Pemasok) dalam satu tabel database ('kontak').
class DaftarKontak extends StatefulWidget {
  const DaftarKontak({super.key});

  @override
  State<DaftarKontak> createState() => _DaftarKontakState();
}

class _DaftarKontakState extends State<DaftarKontak> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controller untuk input field pada form kontak
  final _namaController = TextEditingController();
  final _teleponController = TextEditingController();
  final _alamatController = TextEditingController();

  // List data untuk menampung hasil query database
  List<Map<String, dynamic>> _listPelanggan = [];
  List<Map<String, dynamic>> _listPemasok = [];
  
  // State untuk fitur seleksi masal (Hapus Banyak Data)
  final Set<int> _kumpulanIdTerpilih = {};
  bool _isModeSeleksi = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi TabBar (0: Pelanggan, 1: Pemasok)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Membersihkan status seleksi jika user berpindah tab
      if (!_tabController.indexIsChanging) {
        setState(() {
          _kumpulanIdTerpilih.clear();
          _isModeSeleksi = false;
        });
      }
    });
    _muatDataDariDatabase();
  }

  /// Fungsi untuk mengambil data kontak secara asinkron dari SQLite.
  Future<void> _muatDataDariDatabase() async {
    final db = await DatabaseHelper().database;
    final dataPel = await db.query('kontak', where: 'tipe = ?', whereArgs: ['Pelanggan']);
    final dataPem = await db.query('kontak', where: 'tipe = ?', whereArgs: ['Pemasok']);
    
    setState(() {
      _listPelanggan = dataPel;
      _listPemasok = dataPem;
      _kumpulanIdTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  /// Logika Simpan: Menentukan apakah akan melakukan INSERT atau UPDATE berdasarkan keberadaan ID.
  Future<void> _prosesSimpanKontak({int? id, required String tipeKontak}) async {
    if (_namaController.text.isEmpty) return;
    
    final db = await DatabaseHelper().database;
    final dataMap = {
      'nama': _namaController.text.trim(),
      'telepon': _teleponController.text.trim(),
      'alamat': _alamatController.text.trim(),
      'tipe': tipeKontak,
    };

    if (id == null) {
      await db.insert('kontak', dataMap); // Menambah kontak baru
    } else {
      await db.update('kontak', dataMap, where: 'id = ?', whereArgs: [id]); // Memperbarui kontak
    }

    if (mounted) Navigator.pop(context); // Tutup dialog/bottom sheet
    _muatDataDariDatabase(); // Refresh tampilan
  }

  /// Logika Hapus: Menghapus satu atau banyak baris sekaligus menggunakan klausa 'IN' pada SQL.
  Future<void> _prosesHapusMasal() async {
    if (_kumpulanIdTerpilih.isEmpty) return;
    final db = await DatabaseHelper().database;
    await db.delete('kontak', where: 'id IN (${_kumpulanIdTerpilih.join(',')})');
    _muatDataDariDatabase();
  }

  /// Membangun Form Input menggunakan BottomSheet.
  void _bukaFormDialog({int? id, Map<String, dynamic>? dataLama}) {
    final tipeSekarang = _tabController.index == 0 ? 'Pelanggan' : 'Pemasok';
    _namaController.text = dataLama?['nama'] ?? '';
    _teleponController.text = dataLama?['telepon'] ?? '';
    _alamatController.text = dataLama?['alamat'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(id == null ? 'Tambah $tipeSekarang' : 'Ubah $tipeSekarang', style: AppStyles.h2),
            const SizedBox(height: 16),
            TextField(controller: _namaController, decoration: AppStyles.inputDecoration('Nama Lengkap')),
            const SizedBox(height: 12),
            TextField(controller: _teleponController, decoration: AppStyles.inputDecoration('No. Telepon'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: _alamatController, decoration: AppStyles.inputDecoration('Alamat')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _prosesSimpanKontak(id: id, tipeKontak: tipeSekarang),
                style: AppStyles.primaryButton,
                child: const Text('SIMPAN DATA'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isModeSeleksi ? '${_kumpulanIdTerpilih.length} Dipilih' : 'Daftar Kontak',
            style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          if (_isModeSeleksi)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _prosesHapusMasal)
          else
            IconButton(icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: () => _bukaFormDialog()),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.warning,
          tabs: const [
            Tab(text: 'PELANGGAN', icon: Icon(Icons.people_rounded)),
            Tab(text: 'PEMASOK', icon: Icon(Icons.local_shipping_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDaftarKontak(_listPelanggan),
          _buildDaftarKontak(_listPemasok),
        ],
      ),
    );
  }

  Widget _buildDaftarKontak(List<Map<String, dynamic>> listData) {
    if (listData.isEmpty) {
      return const Center(child: Text('Data belum tersedia.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: listData.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = listData[index];
        final id = item['id'] as int;
        final isSelected = _kumpulanIdTerpilih.contains(id);
        final alamat = item['alamat']?.toString() ?? '';
        final isAlamatEmpty = alamat.trim().isEmpty;
        final telepon = item['telepon']?.toString() ?? '-';

        return ListTile(
          selected: isSelected,
          isThreeLine: true, // ✅ TAMBAHKAN INI
          leading: _isModeSeleksi
              ? Checkbox(value: isSelected, onChanged: (_) => _ubahSeleksi(id))
              : CircleAvatar(
            backgroundColor: AppColors.blue100,
            child: Text(
              item['nama'][0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          title: Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(telepon, style: const TextStyle(fontSize: 13)),
              if (!isAlamatEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  alamat,
                  style: AppStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          onLongPress: () => _aktifkanSeleksi(id),
          onTap: () {
            if (_isModeSeleksi) {
              _ubahSeleksi(id);
            } else {
              _bukaFormDialog(id: id, dataLama: item);
            }
          },
        );
      },
    );
  }

  void _aktifkanSeleksi(int id) {
    setState(() {
      _isModeSeleksi = true;
      _kumpulanIdTerpilih.add(id);
    });
  }

  void _ubahSeleksi(int id) {
    setState(() {
      if (!_kumpulanIdTerpilih.remove(id)) _kumpulanIdTerpilih.add(id);
      _isModeSeleksi = _kumpulanIdTerpilih.isNotEmpty;
    });
  }
}
