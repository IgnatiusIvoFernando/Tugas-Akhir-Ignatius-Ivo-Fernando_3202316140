import 'database_helper.dart';
import '../models/profil_perusahaan.dart';

class ProfilController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ================= SAVE =================
  /// Menyimpan atau memperbarui profil perusahaan.
  /// Mengembalikan ID dari profil yang disimpan.
  Future<int> simpanProfil(ProfilPerusahaan profil) async {
    // Validasi data
    if (profil.namaPerusahaan.trim().isEmpty) {
      throw Exception('Nama perusahaan tidak boleh kosong');
    }

    final db = await _dbHelper.database;

    final result = await db.query(
      'profil_perusahaan',
      orderBy: 'id ASC',
      limit: 1,
    );

    if (result.isEmpty) {
      return await db.insert('profil_perusahaan', profil.toMap());
    } else {
      int idExisting = result.first['id'] as int;

      Map<String, dynamic> dataUpdate = profil.toMap();
      dataUpdate.remove('id');

      await db.update(
        'profil_perusahaan',
        dataUpdate,
        where: 'id = ?',
        whereArgs: [idExisting],
      );
      return idExisting;
    }
  }

  // ================= READ =================
  Future<ProfilPerusahaan?> getProfil() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'profil_perusahaan',
      orderBy: 'id ASC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return ProfilPerusahaan.fromMap(result.first);
  }

  // ================= DELETE =================
  Future<bool> hapusProfil() async {
    final db = await _dbHelper.database;

    try {
      // Cek apakah ada data
      final result = await db.query(
        'profil_perusahaan',
        limit: 1,
      );

      if (result.isEmpty) {
        return false;
      }

      final profilId = result.first['id'] as int;

      // Hapus dengan transaction agar atomic
      await db.transaction((txn) async {
        // FIX: Menggunakan kolom 'profil_id' sesuai skema di DatabaseHelper
        final kategoriCount = await txn.rawQuery(
          'SELECT COUNT(*) as total FROM kategori WHERE profil_id = ?',
          [profilId],
        );
        final totalKategori = kategoriCount.first['total'] as int? ?? 0;

        if (totalKategori > 0) {
          throw Exception(
            'Tidak bisa menghapus profil karena masih ada $totalKategori data kategori yang terhubung',
          );
        }

        await txn.delete('profil_perusahaan', where: 'id = ?', whereArgs: [profilId]);
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  // ================= CEK EKSISTENSI =================
  Future<bool> profilExists() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'profil_perusahaan',
      columns: ['id'],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
