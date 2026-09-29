import 'package:flutter/material.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

/// Halaman Manajemen Merek (Brand) Barang
class DaftarMerek extends StatefulWidget {
  const DaftarMerek({super.key});

  @override
  State<DaftarMerek> createState() => _DaftarMerekState();
}

class _DaftarMerekState extends State<DaftarMerek> {
  final _namaMerekC = TextEditingController();
  List<Map<String, dynamic>> _daftarMerek = [];
  final Set<int> _setIDTerpilih = {};
  bool _isModeSeleksi = false;

  @override
  void initState() {
    super.initState();
    _ambilDataMerek();
  }

  @override
  void dispose() {
    _namaMerekC.dispose();
    super.dispose();
  }

  Future<void> _ambilDataMerek() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('merek');
    if (mounted) {
      setState(() {
        _daftarMerek = data;
        _setIDTerpilih.clear();
        _isModeSeleksi = false;
      });
    }
  }

  Future<void> _prosesSimpan({int? id}) async {
    if (_namaMerekC.text.trim().isEmpty) return;
    
    final db = await DatabaseHelper().database;
    final mapData = {'nama': _namaMerekC.text.trim()};
    
    if (id == null) {
      await db.insert('merek', mapData);
    } else {
      await db.update('merek', mapData, where: 'id = ?', whereArgs: [id]);
    }
    
    _namaMerekC.clear();
    if (mounted) Navigator.pop(context);
    _ambilDataMerek();
  }

  Future<void> _prosesHapus() async {
    if (_setIDTerpilih.isEmpty) return;
    final db = await DatabaseHelper().database;
    await db.delete(
      'merek',
      where: 'id IN (${_setIDTerpilih.join(',')})',
    );
    _ambilDataMerek();
  }

  void _bukaDialogInput({int? id, String? namaLama}) {
    _namaMerekC.text = namaLama ?? '';
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
            Text(id == null ? 'Tambah Merek' : 'Edit Merek', style: AppStyles.h2),
            const SizedBox(height: 16),
            TextField(
              controller: _namaMerekC, 
              autofocus: true,
              decoration: AppStyles.inputDecoration('Nama Brand (Contoh: Samsung / Indofood)')
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _prosesSimpan(id: id),
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
      for (var item in _daftarMerek) {
        _setIDTerpilih.add(item['id'] as int);
      }
      _isModeSeleksi = true;
    });
  }

  void _bersihkanSeleksi() {
    setState(() {
      _setIDTerpilih.clear();
    });
  }

  void _tutupModeSeleksi() {
    setState(() {
      _setIDTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppStyles.selectionAppBar(
        isModeSeleksi: _isModeSeleksi,
        selectedCount: _setIDTerpilih.length,
        title: 'Manajemen Merek',
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
              onPressed: _setIDTerpilih.isEmpty ? null : _konfirmasiHapus,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _bukaDialogInput(),
            ),
        ],
      ),
      body: _daftarMerek.isEmpty 
        ? const Center(child: Text("Data merek masih kosong"))
        : ListView.builder(
            padding: AppStyles.listViewPadding.copyWith(
              bottom: AppStyles.listViewPadding.bottom + bottomPadding + 20,
            ),
            itemCount: _daftarMerek.length,
            itemBuilder: (ctx, index) => _buildBarisMerek(_daftarMerek[index]),
          ),
    );
  }

  Widget _buildBarisMerek(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final isTerpilih = _setIDTerpilih.contains(id);

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
                onChanged: (_) => _kelolaSeleksi(id),
              )
            : const Icon(Icons.branding_watermark_outlined, color: AppColors.secondary),
        title: Text(
          item['nama'] ?? '-', 
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onLongPress: () => _aktifkanModeSeleksi(id),
        onTap: () {
          if (_isModeSeleksi) {
            _kelolaSeleksi(id);
          } else {
            _bukaDialogInput(id: id, namaLama: item['nama']);
          }
        },
      ),
    );
  }

  void _aktifkanModeSeleksi(int id) {
    setState(() {
      _isModeSeleksi = true;
      _setIDTerpilih.add(id);
    });
  }

  void _kelolaSeleksi(int id) {
    setState(() {
      if (!_setIDTerpilih.remove(id)) _setIDTerpilih.add(id);
      if (_setIDTerpilih.isEmpty) {
        _isModeSeleksi = false;
      }
    });
  }

  void _konfirmasiHapus() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Merek?'),
        content: Text('Yakin ingin menghapus ${_setIDTerpilih.length} merek terpilih?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _prosesHapus(); }, 
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
