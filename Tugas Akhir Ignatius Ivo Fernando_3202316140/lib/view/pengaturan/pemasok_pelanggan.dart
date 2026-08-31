import 'package:flutter/material.dart';
import '../../theme/app_styles.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import 'riwayat_kontak_page.dart';

class PemasokPelangganPage extends StatefulWidget {
  const PemasokPelangganPage({super.key});

  @override
  State<PemasokPelangganPage> createState() => _PemasokPelangganPageState();
}

class _PemasokPelangganPageState extends State<PemasokPelangganPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _namaC = TextEditingController();
  final _teleponC = TextEditingController();
  final _alamatC = TextEditingController();
  final _searchC = TextEditingController();
  String _searchQuery = "";
  bool _isSearching = false;

  List<Map<String, dynamic>> _daftarPelanggan = [];
  List<Map<String, dynamic>> _daftarPemasok = [];
  final Set<int> _kumpulanIdTerpilih = {};
  bool _isModeSeleksi = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _muatSeluruhDataKontak();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _namaC.dispose();
    _teleponC.dispose();
    _alamatC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging && _kumpulanIdTerpilih.isNotEmpty) {
      setState(() {
        _kumpulanIdTerpilih.clear();
        _isModeSeleksi = false;
      });
    }
  }

  Future<void> _muatSeluruhDataKontak() async {
    final db = await DatabaseHelper().database;

    // Fetch Pelanggan (Pembeli)
    final dataPel = await db.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM dokumen_stok ds WHERE ds.pembeli_id = p.id AND ds.status = 'HUTANG') as jumlah_hutang
      FROM pembeli p WHERE p.is_deleted = 0
    ''');

    // Fetch Pemasok (Penyuplai)
    final dataPem = await db.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM dokumen_stok ds WHERE ds.penyuplai_id = p.id AND ds.status = 'HUTANG') as jumlah_hutang
      FROM penyuplai p WHERE p.is_deleted = 0
    ''');

    if (!mounted) return;
    setState(() {
      _daftarPelanggan = dataPel;
      _daftarPemasok = dataPem;
      _kumpulanIdTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  List<Map<String, dynamic>> _getFilteredList(List<Map<String, dynamic>> originalList) {
    if (_searchQuery.isEmpty) return originalList;
    return originalList.where((item) {
      final nama = (item['nama'] ?? item['nama_perusahaan'])?.toString().toLowerCase() ?? '';
      final telp = item['telepon']?.toString().toLowerCase() ?? '';
      return nama.contains(_searchQuery.toLowerCase()) || telp.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _pilihSemua() {
    final currentList = _tabController.index == 0 ? _daftarPelanggan : _daftarPemasok;
    final filteredList = _getFilteredList(currentList);
    setState(() {
      for (var item in filteredList) {
        _kumpulanIdTerpilih.add(item['id'] as int);
      }
      _isModeSeleksi = true;
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
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDaftarView(_daftarPelanggan, true),
          _buildDaftarView(_daftarPemasok, false),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppStyles.selectionAppBar(
      isModeSeleksi: _isModeSeleksi,
      selectedCount: _kumpulanIdTerpilih.length,
      title: 'Daftar Kontak',
      onClose: _tutupModeSeleksi,
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: AppColors.warning,
        tabs: const [
          Tab(text: 'PELANGGAN', icon: Icon(Icons.people)),
          Tab(text: 'PEMASOK', icon: Icon(Icons.local_shipping_rounded)),
        ],
      ),
      actions: [
        if (_isModeSeleksi) ...[
          IconButton(icon: const Icon(Icons.select_all), onPressed: _pilihSemua),
          IconButton(icon: const Icon(Icons.delete), onPressed: _kumpulanIdTerpilih.isEmpty ? null : _konfirmasiHapus),
        ] else ...[
          if (_isSearching)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: TextField(
                  controller: _searchC,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Cari nama...', border: InputBorder.none),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = "";
              _searchC.clear();
            }),
          ),
          if (!_isSearching)
            IconButton(icon: const Icon(Icons.add), onPressed: () => _bukaDialogForm()),
        ]
      ],
    );
  }

  Widget _buildDaftarView(List<Map<String, dynamic>> listData, bool isPelanggan) {
    final filtered = _getFilteredList(listData);
    if (filtered.isEmpty) {
      return Center(child: Text(_searchQuery.isEmpty ? 'Data belum tersedia' : 'Tidak ditemukan'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildItemKontak(filtered[index], isPelanggan),
    );
  }

  Widget _buildItemKontak(Map<String, dynamic> item, bool isPelanggan) {
    final int id = item['id'] as int;
    final bool isSelected = _kumpulanIdTerpilih.contains(id);
    final String nama = (item['nama'] ?? item['nama_perusahaan'])?.toString() ?? '';
    final String inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    return ListTile(
      selected: isSelected,
      leading: _isModeSeleksi
          ? Checkbox(value: isSelected, onChanged: (_) => _ubahStatusSeleksi(id))
          : CircleAvatar(
              backgroundColor: AppColors.blue100,
              child: Text(inisial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
      title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(item['telepon']?.toString() ?? '-'),
      trailing: (item['jumlah_hutang'] ?? 0) > 0
          ? _buildBadgeStatus(isPelanggan ? 'PELANGGAN' : 'PEMASOK')
          : null,
      onTap: () {
        if (_isModeSeleksi) {
          _ubahStatusSeleksi(id);
        } else {
          _bukaOpsiLanjutan(item, isPelanggan);
        }
      },
    );
  }

  Widget _buildBadgeStatus(String tipe) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
    child: Text(tipe == 'PELANGGAN' ? 'PIUTANG' : 'HUTANG', style: TextStyle(color: Colors.red.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  void _ubahStatusSeleksi(int id) {
    setState(() {
      if (!_kumpulanIdTerpilih.remove(id)) _kumpulanIdTerpilih.add(id);
      if (_kumpulanIdTerpilih.isEmpty) _isModeSeleksi = false;
    });
  }

  Future<void> _prosesSimpanKontak({int? id, required bool isPelanggan}) async {
    if (_namaC.text.trim().isEmpty) return;
    final db = await DatabaseHelper().database;
    final tableName = isPelanggan ? 'pembeli' : 'penyuplai';

    final dataMap = {
      isPelanggan ? 'nama' : 'nama_perusahaan': _namaC.text.trim(),
      'telepon': _teleponC.text.trim(),
      'alamat': _alamatC.text.trim(),
    };

    if (id == null) {
      await db.insert(tableName, dataMap);
    } else {
      await db.update(tableName, dataMap, where: 'id = ?', whereArgs: [id]);
    }
    Navigator.pop(context);
    _muatSeluruhDataKontak();
  }

  void _konfirmasiHapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data?'),
        content: Text('Hapus ${_kumpulanIdTerpilih.length} item terpilih?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _prosesHapusMasal();
          }, child: const Text('HAPUS', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _prosesHapusMasal() async {
    final db = await DatabaseHelper().database;
    final tableName = _tabController.index == 0 ? 'pembeli' : 'penyuplai';
    final placeholders = List.filled(_kumpulanIdTerpilih.length, '?').join(',');
    await db.update(tableName, {'is_deleted': 1}, where: 'id IN ($placeholders)', whereArgs: _kumpulanIdTerpilih.toList());
    _muatSeluruhDataKontak();
  }

  void _bukaOpsiLanjutan(Map<String, dynamic> item, bool isPelanggan) {
    final String nama = (item['nama'] ?? item['nama_perusahaan'])?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text('Riwayat Transaksi $nama'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RiwayatKontakPage(
                  kontakId: item['id'],
                  namaKontak: nama,
                  tipe: isPelanggan ? 'pelanggan' : 'pemasok'
                ))).then((_) => _muatSeluruhDataKontak());
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.secondary),
              title: const Text('Edit Informasi'),
              onTap: () {
                Navigator.pop(ctx);
                _bukaDialogForm(id: item['id'], dataAwal: item, isPelanggan: isPelanggan);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _bukaDialogForm({int? id, Map<String, dynamic>? dataAwal, bool? isPelanggan}) {
    final isPel = isPelanggan ?? (_tabController.index == 0);
    _namaC.text = (dataAwal?['nama'] ?? dataAwal?['nama_perusahaan']) ?? '';
    _teleponC.text = dataAwal?['telepon'] ?? '';
    _alamatC.text = dataAwal?['alamat'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(id == null ? 'Tambah' : 'Ubah', style: AppStyles.h2),
            const SizedBox(height: 16),
            TextField(controller: _namaC, decoration: AppStyles.inputDecoration("Nama")),
            const SizedBox(height: 12),
            TextField(controller: _teleponC, keyboardType: TextInputType.phone, decoration: AppStyles.inputDecoration("Telepon")),
            const SizedBox(height: 12),
            TextField(controller: _alamatC, decoration: AppStyles.inputDecoration("Alamat")),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _prosesSimpanKontak(id: id, isPelanggan: isPel), style: AppStyles.primaryButton, child: const Text('SIMPAN'))),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
