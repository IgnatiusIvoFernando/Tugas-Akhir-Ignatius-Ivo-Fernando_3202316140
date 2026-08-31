import '../models/dokumen_stok.dart';
import '../models/dokumen_item.dart';
import 'barang_controller.dart';
import 'database_helper.dart';
import 'profil_controller.dart';
import 'package:sqflite/sqflite.dart';

class DokumenController {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BarangController _barangController = BarangController();
  final ProfilController _profilController = ProfilController();

  Future<Database> get database async => await _dbHelper.database;

  // ================= SAVE FULL DOKUMEN =================
  
  Future<int> simpanTransaksiLengkap({
    required DokumenStok dokumen,
    required List<DokumenItem> items,
    double? nominalAwal,
  }) async {
    if (items.isEmpty) {
      throw Exception('Tidak ada item yang akan disimpan!');
    }

    final db = await _dbHelper.database;
    int idDokumen = 0;

    // Ambil Profil ID jika belum ada
    int? pId = dokumen.profilId;
    if (pId == null) {
      final profil = await _profilController.getProfil();
      pId = profil?.id;
    }

    await db.transaction((txn) async {
      final mapDokumen = dokumen.toMap();
      mapDokumen['profil_id'] = pId; // Pastikan profil_id terisi
      
      // Sinkronisasi Nominal Bayar & Status
      // nominalAwal biasanya digunakan untuk pencatatan kas (DIBAYAR/DP)
      // Kita tetap pertahankan nominal_bayar asli dari objek dokumen jika nominal_bayar di dokumen > nominalAwal
      if (nominalAwal != null && nominalAwal > 0) {
        double nominalBayarDoc = (mapDokumen['nominal_bayar'] as num?)?.toDouble() ?? 0;
        if (nominalBayarDoc < nominalAwal) {
          mapDokumen['nominal_bayar'] = nominalAwal;
        }
        
        double total = (mapDokumen['total_akhir'] as num?)?.toDouble() ?? 0;
        if (nominalAwal >= total - 0.0001 && total > 0) {
          mapDokumen['status'] = 'DIBAYAR';
        }
      }

      idDokumen = await txn.insert('dokumen_stok', mapDokumen);

      // Simpan Riwayat Pembayaran jika ada pembayaran masuk (nominalAwal)
      if (nominalAwal != null && nominalAwal > 0) {
        await txn.insert('riwayat_pembayaran', {
          'dokumen_id': idDokumen,
          'nominal': nominalAwal,
          'tanggal': DateTime.now().toIso8601String(),
          'keterangan': 'Pembayaran Awal / DP',
        });
      }

      for (var item in items) {
        final itemBaru = DokumenItem(
          dokumenId: idDokumen,
          barangId: item.barangId,
          qty: item.qty,
          harga: item.harga,
          diskon: item.diskon,
        );

        await txn.insert('dokumen_item', itemBaru.toMap());

        String alasan = dokumen.jenis == JenisDokumen.masuk
            ? "Restok: ${dokumen.judul}"
            : "Penjualan: ${dokumen.judul}";

        // Kirimkan idDokumen agar log_stok terhubung ke transaksi ini
        if (dokumen.jenis == JenisDokumen.masuk) {
          await _barangController.tambahStok(item.barangId, item.qty, alasan, txn: txn, dokumenId: idDokumen);
        } else {
          await _barangController.kurangiStok(item.barangId, item.qty, alasan, txn: txn, dokumenId: idDokumen);
        }
      }
    });

    await _barangController.triggerNotificationChecks();
    return idDokumen;
  }

  // ================= GET PERIODE (LIST TANGGAL) =================

  Future<List<Map<String, dynamic>>> getPeriodeDokumen({
    bool onlyFinancial = false,
    bool onlyNonFinancial = false,
  }) async {
    final db = await _dbHelper.database;
    
    if (onlyFinancial) {
      return await db.rawQuery('''
        SELECT SUBSTR(tanggal, 1, 10) as tanggal, COUNT(*) as jumlah_transaksi
        FROM riwayat_pembayaran
        GROUP BY SUBSTR(tanggal, 1, 10)
        ORDER BY tanggal DESC
      ''');
    } else if (onlyNonFinancial) {
      return await db.rawQuery('''
        SELECT SUBSTR(tanggal, 1, 10) as tanggal, COUNT(*) as jumlah_transaksi
        FROM dokumen_stok
        WHERE status != 'BATAL' AND tampil_di_stok = 1
        GROUP BY SUBSTR(tanggal, 1, 10)
        ORDER BY tanggal DESC
      ''');
    } else {
      return await db.rawQuery('''
        SELECT SUBSTR(tanggal, 1, 10) as tanggal, COUNT(*) as jumlah_transaksi
        FROM dokumen_stok
        WHERE status != 'BATAL'
        GROUP BY SUBSTR(tanggal, 1, 10)
        ORDER BY tanggal DESC
      ''');
    }
  }

  // ================= GET DETAIL PER PERIODE =================

  Future<List<Map<String, dynamic>>> getDetailPerPeriode(
    String tanggalSaja, {
    bool onlyFinancial = false,
    bool onlyNonFinancial = false,
    JenisDokumen? jenis,
  }) async {
    final db = await _dbHelper.database;

    String filterJenis = "";
    List<dynamic> args = [tanggalSaja];

    if (jenis != null) {
      filterJenis = " AND ds.jenis = ?";
      args.add(jenis.name);
    }

    if (onlyFinancial) {
      return await db.rawQuery('''
        SELECT 
          rp.id as pay_id, 
          rp.tanggal as tanggal, 
          ds.jenis, 
          COALESCE(pb.nama, py.nama_perusahaan, 'Umum') as pembeli, 
          rp.nominal as nominal_bayar,
          ds.status, 
          ds.id as id,
          ds.judul, 
          rp.keterangan AS ket_doc,
          COALESCE(GROUP_CONCAT(b.nama, ', '), '-') as nama
        FROM riwayat_pembayaran rp
        JOIN dokumen_stok ds ON rp.dokumen_id = ds.id
        LEFT JOIN pembeli pb ON ds.pembeli_id = pb.id
        LEFT JOIN penyuplai py ON ds.penyuplai_id = py.id
        LEFT JOIN dokumen_item di ON di.dokumen_id = ds.id 
        LEFT JOIN barang b ON di.barang_id = b.id
        WHERE SUBSTR(rp.tanggal, 1, 10) = ?
          AND ds.status != 'BATAL'
        GROUP BY rp.id
        ORDER BY rp.tanggal ASC
      ''', [tanggalSaja]);
    }

    String filterNonFinancial = onlyNonFinancial ? " AND ds.tampil_di_stok = 1" : "";

    return await db.rawQuery('''
      SELECT 
        ds.id, ds.tanggal, ds.jenis, 
        COALESCE(pb.nama, py.nama_perusahaan, 'Umum') as pembeli, 
        ds.total_akhir, ds.nominal_bayar, ds.status, ds.judul, 
        b.nama as nama,
        di.qty as qty,
        ds.keterangan as ket_doc
      FROM dokumen_item di
      JOIN dokumen_stok ds ON di.dokumen_id = ds.id
      JOIN barang b ON di.barang_id = b.id
      LEFT JOIN pembeli pb ON ds.pembeli_id = pb.id
      LEFT JOIN penyuplai py ON ds.penyuplai_id = py.id
      WHERE SUBSTR(ds.tanggal, 1, 10) = ?
        AND ds.status != 'BATAL'
        $filterNonFinancial
        $filterJenis
      ORDER BY ds.tanggal ASC
    ''', args);
  }

  // ================= GET RIWAYAT BY KONTAK =================

  Future<List<Map<String, dynamic>>> getRiwayatByPembeli(int pembeliId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'dokumen_stok',
      where: 'pembeli_id = ? AND status != ?',
      whereArgs: [pembeliId, 'BATAL'],
      orderBy: 'tanggal DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getRiwayatByPenyuplai(int penyuplaiId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'dokumen_stok',
      where: 'penyuplai_id = ? AND status != ?',
      whereArgs: [penyuplaiId, 'BATAL'],
      orderBy: 'tanggal DESC',
    );
  }

  // ================= DELETE =================

  Future<void> deleteDokumenByTanggal(String tanggal, {
    bool onlyFinancial = false,
    bool onlyNonFinancial = false,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      List<int> idsToDelete = [];

      if (onlyFinancial) {
        // Cari dokumen yang memiliki riwayat pembayaran pada tanggal tersebut
        final docs = await txn.rawQuery('''
          SELECT DISTINCT dokumen_id FROM riwayat_pembayaran 
          WHERE SUBSTR(tanggal, 1, 10) = ?
        ''', [tanggal]);
        idsToDelete = docs.map((d) => d['dokumen_id'] as int).toList();
      } else {
        String whereClause = "SUBSTR(tanggal, 1, 10) = ?";
        List<dynamic> whereArgs = [tanggal];
        if (onlyNonFinancial) {
          whereClause += " AND tampil_di_stok = 1";
        }
        final docs = await txn.query('dokumen_stok', columns: ['id'], where: whereClause, whereArgs: whereArgs);
        idsToDelete = docs.map((id) => id['id'] as int).toList();
      }

      for (int id in idsToDelete) {
        await txn.delete('dokumen_item', where: 'dokumen_id = ?', whereArgs: [id]);
        await txn.delete('log_stok', where: 'dokumen_id = ?', whereArgs: [id]);
        await txn.delete('riwayat_pembayaran', where: 'dokumen_id = ?', whereArgs: [id]);
        await txn.delete('dokumen_stok', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  // ================= PEMBAYARAN & HUTANG =================

  Future<List<Map<String, dynamic>>> getRiwayatPembayaran(int dokumenId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'riwayat_pembayaran',
      where: 'dokumen_id = ?',
      whereArgs: [dokumenId],
      orderBy: 'tanggal DESC',
    );
  }

  Future<void> updatePembayaran(int dokumenId, double nominalTambahan) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> res = await txn.query(
        'dokumen_stok',
        columns: ['total_akhir', 'nominal_bayar'],
        where: 'id = ?',
        whereArgs: [dokumenId],
      );

      if (res.isEmpty) throw Exception("Dokumen tidak ditemukan");

      double total = (res.first['total_akhir'] as num).toDouble();
      double sdhBayar = (res.first['nominal_bayar'] as num).toDouble();
      double baruBayar = sdhBayar + nominalTambahan;

      await txn.insert('riwayat_pembayaran', {
        'dokumen_id': dokumenId,
        'nominal': nominalTambahan,
        'tanggal': DateTime.now().toIso8601String(),
        'keterangan': 'Pelunasan / Cicilan',
      });

      String status = (baruBayar >= total - 0.0001) ? 'DIBAYAR' : 'HUTANG';
      
      await txn.update(
        'dokumen_stok',
        {
          'nominal_bayar': baruBayar,
          'status': status,
        },
        where: 'id = ?',
        whereArgs: [dokumenId],
      );
    });
  }
}
