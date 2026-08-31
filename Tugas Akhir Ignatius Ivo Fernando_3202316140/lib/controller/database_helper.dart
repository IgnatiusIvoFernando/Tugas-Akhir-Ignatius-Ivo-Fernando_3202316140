import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static bool _isOpen = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'stok_barang.db');

    return await openDatabase(
      path,
      version: 26,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    if (_isOpen) return;
    _isOpen = true;
    await db.execute('PRAGMA foreign_keys = ON');
    try {
      await db.execute('PRAGMA journal_mode = WAL');
      await db.execute('PRAGMA synchronous = NORMAL');
    } catch (_) {}
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'stok_barang.db');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _isOpen = false;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profil_perusahaan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_perusahaan TEXT,
        jenis_industri TEXT,
        negara TEXT,
        provinsi TEXT,
        kota TEXT,
        alamat TEXT,
        foto_path TEXT,
        header_struk TEXT,
        footer_struk TEXT,
        notifikasi_aktif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE penyuplai (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        nama_perusahaan TEXT,
        nama_kontak TEXT,
        telepon TEXT,
        alamat TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pembeli (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        nama TEXT,
        telepon TEXT,
        alamat TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE kategori (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        nama TEXT,
        keterangan TEXT,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE merek (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        nama TEXT,
        keterangan TEXT,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE barang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        nama TEXT,
        deskripsi TEXT,
        harga_beli REAL DEFAULT 0,
        harga_jual REAL DEFAULT 0,
        stok REAL DEFAULT 0,
        satuan TEXT,
        foto_path TEXT,
        tanggal_kadaluarsa TEXT,
        tanggal_kadaluarsa_int INTEGER,
        kategori_id INTEGER,
        merek_id INTEGER,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE,
        FOREIGN KEY (kategori_id) REFERENCES kategori (id) ON DELETE SET NULL,
        FOREIGN KEY (merek_id) REFERENCES merek (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dokumen_stok (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        pembeli_id INTEGER,
        penyuplai_id INTEGER,
        jenis TEXT,
        judul TEXT,
        tanggal TEXT,
        keterangan TEXT,
        total_akhir REAL DEFAULT 0,
        nominal_bayar REAL DEFAULT 0,
        pajak_persen REAL DEFAULT 0,
        diskon_persen REAL DEFAULT 0,
        status TEXT,
        tampil_di_struk INTEGER DEFAULT 1,
        tampil_di_laporan INTEGER DEFAULT 1,
        tampil_di_stok INTEGER DEFAULT 1,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE,
        FOREIGN KEY (pembeli_id) REFERENCES pembeli (id) ON DELETE SET NULL,
        FOREIGN KEY (penyuplai_id) REFERENCES penyuplai (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dokumen_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dokumen_id INTEGER,
        barang_id INTEGER,
        qty REAL DEFAULT 0,
        harga REAL DEFAULT 0,
        diskon REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        FOREIGN KEY (dokumen_id) REFERENCES dokumen_stok (id) ON DELETE CASCADE,
        FOREIGN KEY (barang_id) REFERENCES barang (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE log_stok (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profil_id INTEGER,
        barang_id INTEGER,
        dokumen_id INTEGER,
        qty_awal REAL DEFAULT 0,
        perubahan REAL DEFAULT 0,
        qty_akhir REAL DEFAULT 0,
        alasan TEXT,
        tanggal TEXT,
        FOREIGN KEY (profil_id) REFERENCES profil_perusahaan (id) ON DELETE CASCADE,
        FOREIGN KEY (barang_id) REFERENCES barang (id) ON DELETE CASCADE,
        FOREIGN KEY (dokumen_id) REFERENCES dokumen_stok (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE riwayat_pembayaran (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dokumen_id INTEGER,
        nominal REAL DEFAULT 0,
        tanggal TEXT,
        keterangan TEXT,
        FOREIGN KEY (dokumen_id) REFERENCES dokumen_stok (id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 22) {
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN keterangan TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN nominal_bayar REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN pajak_persen REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN diskon_persen REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN tampil_di_struk INTEGER DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN tampil_di_laporan INTEGER DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE dokumen_stok ADD COLUMN tampil_di_stok INTEGER DEFAULT 1'); } catch (_) {}
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS riwayat_pembayaran (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dokumen_id INTEGER,
          nominal REAL DEFAULT 0,
          tanggal TEXT,
          keterangan TEXT,
          FOREIGN KEY (dokumen_id) REFERENCES dokumen_stok (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 23) {
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN jenis_industri TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN negara TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN provinsi TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN kota TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN header_struk TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN footer_struk TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE profil_perusahaan ADD COLUMN notifikasi_aktif INTEGER DEFAULT 1'); } catch (_) {}
    }
    if (oldVersion < 24) {
      try { await db.execute('ALTER TABLE kategori ADD COLUMN keterangan TEXT'); } catch (_) {}
    }
    if (oldVersion < 25) {
      try { await db.execute('ALTER TABLE merek ADD COLUMN keterangan TEXT'); } catch (_) {}
    }
    if (oldVersion < 26) {
      // Migrasi untuk tabel barang
      try { await db.execute('ALTER TABLE barang ADD COLUMN foto_path TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE barang ADD COLUMN tanggal_kadaluarsa TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE barang ADD COLUMN tanggal_kadaluarsa_int INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE barang ADD COLUMN created_at TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE barang ADD COLUMN updated_at TEXT'); } catch (_) {}
      
      // Migrasi untuk tabel log_stok
      try { await db.execute('ALTER TABLE log_stok ADD COLUMN qty_awal REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE log_stok ADD COLUMN alasan TEXT'); } catch (_) {}
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_barang_profil ON barang (profil_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dokumen_pembeli ON dokumen_stok (pembeli_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dokumen_penyuplai ON dokumen_stok (penyuplai_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_item_dokumen ON dokumen_item (dokumen_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_riwayat_dokumen ON riwayat_pembayaran (dokumen_id)');
  }
}