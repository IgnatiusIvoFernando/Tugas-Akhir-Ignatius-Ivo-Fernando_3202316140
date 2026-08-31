import 'package:sqflite/sqflite.dart';
import 'dart:async';
import '../models/barang.dart';
import 'database_helper.dart';
import 'notification_util.dart';
import 'profil_controller.dart';

class BarangController {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProfilController _profilController = ProfilController();

  static final Map<int, _AsyncLock> _locks = {};

  /// Nilai konstanta untuk stok tak terbatas
  static const double UNLIMITED_STOCK = 999999.0;

  // ================= CREATE =================

  Future<int> insert(Barang barang) async {
    _validateBarang(barang);

    if (await checkNamaExist(barang.nama)) {
      throw Exception('Nama ${barang.nama} sudah ada');
    }

    final db = await _dbHelper.database;
    
    // Ambil profil ID jika belum ada di objek barang
    int? pId = barang.profilId;
    if (pId == null) {
      final profil = await _profilController.getProfil();
      pId = profil?.id;
    }

    final map = barang.copyWith(profilId: pId).toMap();
    map['is_deleted'] = 0;
    map['created_at'] = DateTime.now().toIso8601String();

    final id = await db.insert('barang', map);

    // Trigger notifikasi setelah data masuk
    triggerNotificationChecks();

    return id;
  }

  // ================= ANALYTICS =================

  Future<double> hitungTotalPotensiKeuntungan() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM((harga_jual - harga_beli) * stok), 0) as total '
      'FROM barang '
      'WHERE is_deleted = 0 AND stok < ?',
      [UNLIMITED_STOCK],
    );
    return (result.first['total'] as num).toDouble();
  }

  // ================= OPTIMIZED READ =================

  Future<List<Barang>> getFilteredPaginated({
    String query = '',
    int? kategoriId,
    int? merekId,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;

    List<String> whereClauses = ['is_deleted = 0'];
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      if (query.contains(',')) {
        List<String> keywords = query.split(',').where((k) => k.trim().isNotEmpty).toList();
        List<String> subClauses = [];
        for (var k in keywords) {
          subClauses.add('nama LIKE ?');
          whereArgs.add('%${k.trim()}%');
        }
        if (subClauses.isNotEmpty) {
          whereClauses.add('(${subClauses.join(' OR ')})');
        }
      } else {
        whereClauses.add('nama LIKE ?');
        whereArgs.add('%$query%');
      }
    }

    if (kategoriId != null) {
      whereClauses.add('kategori_id = ?');
      whereArgs.add(kategoriId);
    }

    if (merekId != null) {
      whereClauses.add('merek_id = ?');
      whereArgs.add(merekId);
    }

    final result = await db.query(
      'barang',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'nama ASC',
      limit: limit,
      offset: offset,
    );

    return result.map((e) => Barang.fromMap(e)).toList();
  }

  // ================= READ ALL =================

  Future<List<Barang>> getAll() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'barang',
      where: 'is_deleted = 0',
      orderBy: 'nama ASC',
    );
    return result.map((e) => Barang.fromMap(e)).toList();
  }

  // ================= SEARCH =================

  Future<List<Barang>> search(String query) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'barang',
      where: 'nama LIKE ? AND is_deleted = 0',
      whereArgs: ['%$query%'],
      limit: 10,
    );
    return result.map((e) => Barang.fromMap(e)).toList();
  }

  // ================= READ BY ID =================

  Future<Barang?> getById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'barang',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Barang.fromMap(result.first);
  }

  // ================= ALERTS =================

  Future<Map<String, List<Barang>>> getAlertSummary() async {
    final all = await getAll();
    return {
      'habis': all.where((b) => b.isOutOfStock).toList(),
      'menipis': all.where((b) => b.isLowStock).toList(),
      'expired': all.where((b) => b.isExpired).toList(),
    };
  }

  // ================= UPDATE =================

  Future<int> update(Barang barang) async {
    _validateBarang(barang);

    if (await checkNamaExist(barang.nama, excludeId: barang.id)) {
      throw Exception('Nama ${barang.nama} sudah digunakan oleh barang lain');
    }

    final dataLama = await getById(barang.id!);

    final db = await _dbHelper.database;
    final map = barang.toMap();
    map.remove('is_deleted');
    map['updated_at'] = DateTime.now().toIso8601String();

    final result = await db.update(
      'barang',
      map,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [barang.id],
    );

    if (result == 0) {
      throw Exception('Barang dengan ID ${barang.id} tidak ditemukan atau sudah dihapus');
    }

    if (dataLama != null) {
      bool stokBerubah = dataLama.stok != barang.stok;
      bool kadaluarsaBerubah = dataLama.tanggalKadaluarsa != barang.tanggalKadaluarsa;

      if (stokBerubah || kadaluarsaBerubah) {
        triggerNotificationChecks();
      }
    }

    return result;
  }

  // ================= DELETE =================

  Future<bool> deleteSafe(int id) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        final relasi = await txn.query(
          'dokumen_item',
          where: 'barang_id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (relasi.isNotEmpty) {
          await txn.update(
            'barang',
            {'is_deleted': 1, 'stok': 0, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.delete('log_stok', where: 'barang_id = ?', whereArgs: [id]);
          await txn.delete('barang', where: 'id = ?', whereArgs: [id]);
        }
      });

      triggerNotificationChecks();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ================= STOK MANAGEMENT =================

  Future<void> tambahStok(int id, double jumlah, String alasan, {DatabaseExecutor? txn, int? dokumenId}) async {
    if (jumlah <= 0) return;

    final lock = _getLock(id);
    await lock.synchronized(() async {
      final db = txn ?? await _dbHelper.database;

      final barangData = await db.query(
        'barang',
        columns: ['stok', 'profil_id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );

      if (barangData.isEmpty) throw Exception('Barang tidak ditemukan');

      final qtyAwal = (barangData.first['stok'] as num?)?.toDouble() ?? 0;
      final profilId = barangData.first['profil_id'] as int?;

      if (qtyAwal >= UNLIMITED_STOCK) return;

      final qtyAkhir = qtyAwal + jumlah;

      await db.update(
        'barang',
        {'stok': qtyAkhir, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      await db.insert('log_stok', {
        'profil_id': profilId,
        'barang_id': id,
        'dokumen_id': dokumenId,
        'qty_awal': qtyAwal,
        'perubahan': jumlah,
        'qty_akhir': qtyAkhir,
        'alasan': alasan,
        'tanggal': DateTime.now().toIso8601String(),
      });

      if (txn == null) triggerNotificationChecks();
    });
  }

  Future<void> kurangiStok(int id, double jumlah, String alasan, {DatabaseExecutor? txn, bool force = false, int? dokumenId}) async {
    if (jumlah <= 0) return;

    final lock = _getLock(id);
    await lock.synchronized(() async {
      final db = txn ?? await _dbHelper.database;

      final barangData = await db.query(
        'barang',
        columns: ['stok', 'nama', 'profil_id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );

      if (barangData.isEmpty) throw Exception('Barang tidak ditemukan');

      final qtyAwal = (barangData.first['stok'] as num?)?.toDouble() ?? 0;
      final namaBarang = barangData.first['nama'];
      final profilId = barangData.first['profil_id'] as int?;

      if (qtyAwal >= UNLIMITED_STOCK) return;

      if (!force && qtyAwal < (jumlah - 0.0001)) {
        throw Exception('Stok $namaBarang tidak cukup (Stok: $qtyAwal, Dibutuhkan: $jumlah)');
      }

      final qtyAkhir = qtyAwal - jumlah;

      await db.update(
        'barang',
        {'stok': qtyAkhir, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      await db.insert('log_stok', {
        'profil_id': profilId,
        'barang_id': id,
        'dokumen_id': dokumenId,
        'qty_awal': qtyAwal,
        'perubahan': -jumlah,
        'qty_akhir': qtyAkhir,
        'alasan': alasan,
        'tanggal': DateTime.now().toIso8601String(),
      });

      if (txn == null) triggerNotificationChecks();
    });
  }

  // ================= UTILITIES =================

  Future<bool> checkNamaExist(String nama, {int? excludeId}) async {
    final db = await _dbHelper.database;
    String query = 'SELECT id FROM barang WHERE LOWER(nama) = LOWER(?) AND is_deleted = 0';
    List<dynamic> args = [nama];

    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.rawQuery(query, args);
    return result.isNotEmpty;
  }

  Future<List<Barang>> getExpired() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final todayTimestamp = todayOnly.millisecondsSinceEpoch;

    final result = await db.query(
      'barang',
      where: 'tanggal_kadaluarsa_int IS NOT NULL AND tanggal_kadaluarsa_int < ? AND is_deleted = 0',
      whereArgs: [todayTimestamp],
      orderBy: 'tanggal_kadaluarsa_int ASC',
    );
    return result.map((e) => Barang.fromMap(e)).toList();
  }

  void _validateBarang(Barang barang) {
    if (barang.nama.trim().isEmpty) throw Exception('Nama barang tidak boleh kosong');
    if (barang.hargaBeli < 0) throw Exception('Harga beli tidak boleh negatif');
    if (barang.hargaJual < 0) throw Exception('Harga jual tidak boleh negatif');
    if (barang.stok < 0) throw Exception('Stok tidak boleh negatif');
  }

  _AsyncLock _getLock(int id) => _locks.putIfAbsent(id, () => _AsyncLock());

  Future<void> triggerNotificationChecks() async {
    LocalNotificationUtil.cekStokMenipis(force: false);
    LocalNotificationUtil.cekDanNotifikasiKadaluarsa(force: false);
  }
}

class _AsyncLock {
  Future<void>? _last;
  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;
    try {
      if (previous != null) { try { await previous; } catch (_) {} }
      return await action();
    } finally { completer.complete(); }
  }
}
