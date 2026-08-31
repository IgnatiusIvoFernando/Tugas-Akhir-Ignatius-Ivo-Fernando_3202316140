import 'package:flutter/material.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

/// Halaman Manajemen Kategori Barang
class DaftarKategori extends StatefulWidget {
  const DaftarKategori({super.key});

  @override
  State<DaftarKategori> createState() => _DaftarKategoriState();
}

class _DaftarKategoriState extends State<DaftarKategori> {
  final _inputNamaController = TextEditingController();
  List<Map<String, dynamic>> _daftarKategori = [];
  final Set<int> _kumpulanIdTerpilih = {};
  bool _isModeSeleksi = false;

  @override
  void initState() {
    super.initState();
    _muatDataKategori();
  }

  @override
  void dispose() {
    _inputNamaController.dispose();
    super.dispose();
  }

  Future<void> _muatDataKategori() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('kategori');
    
    if (mounted) {
      setState(() {
        _daftarKategori = data;
        _kumpulanIdTerpilih.clear();
        _isModeSeleksi = false;
      });
    }
  }

  Future<void> _prosesSimpanKategori({int? id}) async {
    if (_inputNamaController.text.trim().isEmpty) return;
    
    final db = await DatabaseHelper().database;
    final dataMap = {'nama': _inputNamaController.text.trim()};
    
    if (id == null) {
      await db.insert('kategori', dataMap);
    } else {
      await db.update('kategori', dataMap, where: 'id = ?', whereArgs: [id]);
    }
    
    _inputNamaController.clear();
    if (mounted) Navigator.pop(context);
    _muatDataKategori();
  }

  Future<void> _prosesHapusMasal() async {
    if (_kumpulanIdTerpilih.isEmpty) return;
    final db = await DatabaseHelper().database;
    await db.delete(
      'kategori',
      where: 'id IN (${_kumpulanIdTerpilih.join(',')})',
    );
    _muatDataKategori();
  }

  void _tampilkanFormInput({int? id, String? namaAwal}) {
    _inputNamaController.text = namaAwal ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16,
          left: 16, right: 16, top: 16
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(id == null ? 'Tambah Kategori' : 'Edit Kategori', style: AppStyles.h2),
            const SizedBox(height: 16),
            TextField(
              controller: _inputNamaController, 
              autofocus: true,
              decoration: AppStyles.inputDecoration('Nama Kategori (Contoh: Sembako)')
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _prosesSimpanKategori(id: id),
                style: AppStyles.primaryButton,
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('SIMPAN DATA')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _pilihSemua() {
    setState(() {
      for (var item in _daftarKategori) {
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppStyles.selectionAppBar(
        isModeSeleksi: _isModeSeleksi,
        selectedCount: _kumpulanIdTerpilih.length,
        title: 'Daftar Kategori',
        onClose: _tutupModeSeleksi,
        actions: [
          if (_isModeSeleksi) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: "Pilih Semua",
              onPressed: _pilihSemua,
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: "Batal Pilih",
              onPressed: _bersihkanSeleksi,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _kumpulanIdTerpilih.isEmpty ? null : _konfirmasiHapus,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _tampilkanFormInput(),
            ),
        ],
      ),
      body: _daftarKategori.isEmpty 
        ? const Center(child: Text("Belum ada kategori. Klik (+) untuk menambah."))
        : ListView.builder(
            padding: AppStyles.listViewPadding.copyWith(
              bottom: AppStyles.listViewPadding.bottom + bottomPadding + 20,
            ),
            itemCount: _daftarKategori.length,
            itemBuilder: (ctx, index) => _buildBarisKategori(_daftarKategori[index]),
          ),
    );
  }

  Widget _buildBarisKategori(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final isTerpilih = _kumpulanIdTerpilih.contains(id);

    return Padding(
      padding: AppStyles.listItemPadding,
      child: ListTile(
        selected: isTerpilih,
        selectedTileColor: AppStyles.selectedTileColor,
        shape: AppStyles.selectionShape(isTerpilih),
        tileColor: AppStyles.tileBackgroundColor,
        leading: _isModeSeleksi
            ? Checkbox(
                value: isTerpilih,
                activeColor: AppColors.primary,
                onChanged: (_) => _ubahStatusSeleksi(id),
              )
            : const Icon(Icons.category_rounded, color: AppColors.secondary),
        title: Text(
          item['nama'] ?? '-', 
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onLongPress: () => _mulaiModeSeleksi(id),
        onTap: () {
          if (_isModeSeleksi) {
            _ubahStatusSeleksi(id);
          } else {
            _tampilkanFormInput(id: id, namaAwal: item['nama']);
          }
        },
      ),
    );
  }

  void _mulaiModeSeleksi(int id) {
    setState(() {
      _isModeSeleksi = true;
      _kumpulanIdTerpilih.add(id);
    });
  }

  void _ubahStatusSeleksi(int id) {
    setState(() {
      if (!_kumpulanIdTerpilih.remove(id)) {
        _kumpulanIdTerpilih.add(id);
      }
      if (_kumpulanIdTerpilih.isEmpty) {
        _isModeSeleksi = false;
      }
    });
  }

  void _konfirmasiHapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kategori?'),
        content: Text('Yakin ingin menghapus ${_kumpulanIdTerpilih.length} kategori terpilih?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _prosesHapusMasal(); }, 
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
