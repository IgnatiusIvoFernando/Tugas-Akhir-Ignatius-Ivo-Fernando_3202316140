import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../controller/barang_controller.dart';
import '../../controller/database_helper.dart';
import '../../models/barang.dart';
import '../widgets/app_drawer.dart';
import '../transaksi/barang_keluar.dart';
import 'edit_barang.dart';
import '../transaksi/barang_tambah.dart';
import 'adjustment_stok.dart';
import 'log_stok_page.dart';
import 'barang_masuk.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import 'widgets/barang_card.dart';
import 'widgets/barang_list_tile.dart';
import 'widgets/stok_peringatan_banner.dart';

/// Halaman GridBarang untuk menampilkan daftar barang dengan fitur pencarian, filter,
/// serta operasi massal (seleksi barang).
class GridBarang extends StatefulWidget {
  const GridBarang({super.key});

  @override
  State<GridBarang> createState() => _GridBarangState();
}

class _GridBarangState extends State<GridBarang> {
  // Controller untuk logika bisnis barang
  final BarangController _barangController = BarangController();
  // Controller untuk menangani scroll (infinite scroll/pagination)
  final ScrollController _scrollController = ScrollController();
  // Controller untuk input pencarian
  final TextEditingController _searchController = TextEditingController();
  // Focus node untuk input pencarian
  final FocusNode _searchFocusNode = FocusNode();

  // State data barang
  List<Barang> _dataBarang = [];
  List<Barang> _dataPeringatan = []; // Data barang yang stoknya menipis/bermasalah
  Map<int, String> _mapNamaKategori = {}; // Mapping ID kategori ke nama
  Map<int, String> _mapNamaMerek = {}; // Mapping ID merek ke nama

  // State pagination
  int _offset = 0;
  final int _limit = 20;
  // Flag untuk menandai apakah masih ada data barang yang bisa dimuat (pagination)
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // State filter & pencarian
  String _kataKunciPencarian = '';
  int? _idKategoriTerfilter;
  int? _idMerekTerfilter;

  // State UI (Mode Seleksi & Tampilan)
  bool _isModeSeleksi = false;
  bool _isListView = false; // Toggle antara Grid View dan List View
  final Map<int, Barang> _mapBarangTerpilih = {}; // Menyimpan barang yang dipilih saat mode seleksi

  Timer? _debounceTimer; // Timer untuk debounce pencarian

  @override
  void initState() {
    super.initState();
    _ambilDataMaster(); // Mengambil data kategori & merek
    _muatDataAwal(); // Mengambil data barang awal
    _muatDataPeringatan(); // Mengambil data untuk banner peringatan
    _scrollController.addListener(_onScroll); // Listener untuk infinite scroll
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Menangani event scroll untuk memuat data berikutnya
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _muatDataBerikutnya();
      }
    }
  }

  // BUG FIX: Mengambil data barang yang HANYA bermasalah (low stock/expired)
  // agar banner peringatan berfungsi secara akurat dan efisien.
  Future<void> _muatDataPeringatan() async {
    try {
      final summary = await _barangController.getAlertSummary();
      final List<Barang> combined = [
        ...summary['habis']!,
        ...summary['menipis']!,
        ...summary['expired']!,
      ];
      if (mounted) {
        setState(() {
          _dataPeringatan = combined;
        });
      }
    } catch (e) {
      debugPrint('Error muat data peringatan: $e');
    }
  }

  // Memuat data barang dari awal (reset pagination)
  Future<void> _muatDataAwal() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _offset = 0;
      _dataBarang = [];
      _hasMore = true;
    });

    try {
      String queryClean = _kataKunciPencarian.trim();
      if (queryClean.endsWith(',')) {
        queryClean = queryClean.substring(0, queryClean.length - 1).trim();
      }


      final list = await _barangController.getFilteredPaginated(
        query: queryClean,
        kategoriId: _idKategoriTerfilter,
        merekId: _idMerekTerfilter,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _dataBarang = list;
          _isLoading = false;
          _hasMore = list.length == _limit;
          _offset += _limit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Memuat data barang halaman berikutnya (pagination)
  Future<void> _muatDataBerikutnya() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      String queryClean = _kataKunciPencarian.trim();
      if (queryClean.endsWith(',')) {
        queryClean = queryClean.substring(0, queryClean.length - 1).trim();
      }

      final list = await _barangController.getFilteredPaginated(
        query: queryClean,
        kategoriId: _idKategoriTerfilter,
        merekId: _idMerekTerfilter,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _dataBarang.addAll(list);
          _isLoadingMore = false;
          _hasMore = list.length == _limit;
          _offset += _limit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Mengambil data kategori dan merek untuk keperluan mapping nama
  Future<void> _ambilDataMaster() async {
    try {
      final db = await DatabaseHelper().database;
      final listKat = await db.query('kategori');
      final listMer = await db.query('merek');

      if (mounted) {
        setState(() {
          _mapNamaKategori = {
            for (var item in listKat)
              (item['id'] as int? ?? 0): (item['nama'] as String? ?? 'Tanpa Kategori')
          };
          _mapNamaMerek = {
            for (var item in listMer)
              (item['id'] as int? ?? 0): (item['nama'] as String? ?? 'Tanpa Merek')
          };
        });
      }
    } catch (e) {
      debugPrint('Error ambil data master: $e');
    }
  }

  // Fungsi untuk menambah/menghapus barang dari daftar seleksi
  void _kelolaSeleksiBarang(Barang b) {
    if (b.id == null) return;
    setState(() {
      if (_mapBarangTerpilih.containsKey(b.id)) {
        _mapBarangTerpilih.remove(b.id);
        if (_mapBarangTerpilih.isEmpty) _isModeSeleksi = false;
      } else {
        _mapBarangTerpilih[b.id!] = b;
        _isModeSeleksi = true;
      }
    });
  }

  // Memilih semua barang yang saat ini sedang tampil di layar
  void _pilihSemuaTampil() {
    setState(() {
      for (var b in _dataBarang) {
        if (b.id != null) {
          _mapBarangTerpilih[b.id!] = b;
        }
      }
      _isModeSeleksi = true;
    });
  }

  // Membersihkan semua barang terpilih
  void _bersihkanSeleksi() {
    setState(() {
      _mapBarangTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  // Menutup mode seleksi dan membersihkan data terpilih
  void _tutupModeSeleksi() {
    setState(() {
      _mapBarangTerpilih.clear();
      _isModeSeleksi = false;
    });
  }

  // Menghapus barang yang dipilih secara masal
  Future<void> _hapusBarangMasal() async {
    if (_mapBarangTerpilih.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Hapus Barang Terpilih?'),
        content: Text('Yakin ingin menghapus ${_mapBarangTerpilih.length} barang terpilih?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('BATAL')
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAPUS', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      int berhasil = 0;
      for (int id in _mapBarangTerpilih.keys) {
        if (await _barangController.deleteSafe(id)) berhasil++;
      }

      if (mounted) {
        _tutupModeSeleksi();
        _muatDataAwal();
        _muatDataPeringatan();
        // BUG FIX: Jalankan pemicu notifikasi setelah penghapusan masal selesai
        await _barangController.triggerNotificationChecks();
        if (mounted) {
          AppStyles.showSuccessSnackBar(context, '$berhasil barang berhasil dihapus');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppStyles.showErrorSnackBar(context, 'Gagal menghapus: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: _isModeSeleksi ? null : const AppDrawer(selectedMenu: 'grid barang'),
      appBar: _buildAppBar(),
      floatingActionButton: _isModeSeleksi
          ? null
          : FloatingActionButton(
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add, color: AppColors.white),
        onPressed: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>  BarangMasuk())
          );
          if (result == true && mounted) {
            _muatDataAwal();
            _muatDataPeringatan();
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _muatDataAwal();
          await _muatDataPeringatan();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: StokPeringatanBanner(
                dataPeringatan: _dataPeringatan,
                onRefresh: () {
                  _muatDataAwal();
                  _muatDataPeringatan();
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
                child: Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 10),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.white,
                      child: InkWell(
                        onTap: _tampilkanDialogFilter,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                              Icons.filter_alt_outlined,
                              color: AppColors.primary
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_idKategoriTerfilter != null || _idMerekTerfilter != null)
              SliverToBoxAdapter(child: _buildFilterActiveBar()),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : _dataBarang.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Barang tidak ditemukan', style: AppStyles.subHeadingStyle),
                    TextButton(
                      onPressed: () {
                        setState(() => _kataKunciPencarian = '');
                        _searchController.clear();
                        _muatDataAwal();
                      },
                      child: const Text("Reset Pencarian", style: AppStyles.subHeadingStyle),
                    ),
                  ],
                ),
              ),
            )
                : _isListView
                ? _buildSliverListView()
                : _buildSliverGridView(),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("Memuat data lainnya...", style: AppStyles.caption),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppStyles.selectionAppBar(
      isModeSeleksi: _isModeSeleksi,
      selectedCount: _mapBarangTerpilih.length,
      title: 'Manajemen Stok',
      onClose: _tutupModeSeleksi,
      actions: [
        if (!_isModeSeleksi)
          IconButton(
            icon: Icon(_isListView ? Icons.grid_view : Icons.view_list),
            tooltip: "Ganti Tampilan",
            onPressed: () => setState(() => _isListView = !_isListView),
          ),
        if (_isModeSeleksi) ...[
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: "Pilih Semua di Layar",
            onPressed: _pilihSemuaTampil,
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: "Batal Pilih",
            onPressed: _bersihkanSeleksi,
          ),
          PopupMenuButton<String>(
            onSelected: (pilihan) async {
              final listTerpilih = _mapBarangTerpilih.values.toList();
              Widget? target;
              if (pilihan == 'delete') {
                await _hapusBarangMasal();
                return;
              }
              switch (pilihan) {
                case 'out':
                  if (listTerpilih.any((b) => b.stok <= 0)) {
                    AppStyles.showErrorSnackBar(context, "Ada barang yang stoknya kosong!");
                    return;
                  }
                  target = BarangKeluar(items: listTerpilih);
                  break;
                case 'in':
                  target = TambahBarang(items: listTerpilih);
                  break;
                case 'adj':
                  target = AdjustmentStokPage(items: listTerpilih);
                  break;
              }

              if (target != null) {
                final success = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => target!)
                );
                if (success == true && mounted) {
                  _tutupModeSeleksi();
                  _muatDataAwal();
                  _muatDataPeringatan();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'out', child: Text("Barang Keluar (Jual)")),
              const PopupMenuItem(value: 'in', child: Text("Barang Tambah (Restok)")),
              const PopupMenuItem(value: 'adj', child: Text("Koreksi Stok (Manual)")),
              const PopupMenuItem(
                value: 'delete',
                child: Text("Hapus Barang", style: TextStyle(color: AppColors.error)),
              ),
            ],
          )
        ]
      ],
    );
  }

  Widget _buildSliverGridView() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 20,
          childAspectRatio: 0.58,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index >= _dataBarang.length) {
              if (_hasMore && !_isLoadingMore) {
                _muatDataBerikutnya();
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final b = _dataBarang[index];
            return BarangCard(
              barang: b,
              isSelected: _mapBarangTerpilih.containsKey(b.id),
              namaMerek: _mapNamaMerek[b.merekId] ?? "-",
              namaKategori: _mapNamaKategori[b.kategoriId] ?? "-",
              onTap: () => _isModeSeleksi ? _kelolaSeleksiBarang(b) : _tampilkanDialogOpsi(b),
              onLongPress: () => _kelolaSeleksiBarang(b),
            );
          },
          childCount: _dataBarang.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildSliverListView() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index >= _dataBarang.length) {
              if (_hasMore && !_isLoadingMore) {
                _muatDataBerikutnya();
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final b = _dataBarang[index];
            return BarangListTile(
              barang: b,
              isSelected: _mapBarangTerpilih.containsKey(b.id),
              namaMerek: _mapNamaMerek[b.merekId] ?? "-",
              onTap: () => _isModeSeleksi ? _kelolaSeleksiBarang(b) : _tampilkanDialogOpsi(b),
              onLongPress: () => _kelolaSeleksiBarang(b),
            );
          },
          childCount: _dataBarang.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildFilterActiveBar() {
    String filterText = '';
    if (_idKategoriTerfilter != null) {
      filterText += 'Kategori: ${_mapNamaKategori[_idKategoriTerfilter] ?? "Tidak Diketahui"}';
    }
    if (_idMerekTerfilter != null) {
      filterText += '${filterText.isNotEmpty ? ' | ' : ''}Merek: ${_mapNamaMerek[_idMerekTerfilter] ?? "Tidak Diketahui"}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.blue50,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                filterText,
                style: AppStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _idKategoriTerfilter = null;
                _idMerekTerfilter = null;
              });
              _muatDataAwal();
            },
            child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // Widget pencarian dengan fitur Autocomplete dan Pencarian Masal
  Widget _buildSearchBar() => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<Barang>(
      textEditingController: _searchController,
      focusNode: _searchFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        final String text = textEditingValue.text;
        
        final List<String> searchSegments = text.split(',');
        final String lastSegment = searchSegments.last.trim();

        if (lastSegment.isEmpty) return const Iterable<Barang>.empty();

        return await _barangController.search(lastSegment);
      },
      displayStringForOption: (Barang b) => b.nama,
      onSelected: (Barang b) {
        _debounceTimer?.cancel();
        
        final List<String> segments = _kataKunciPencarian.split(',');
        String newText;

        if (segments.length > 1) {
          segments.removeLast();
          final String prefix = segments.map((s) => s.trim()).join(', ');
          newText = '$prefix, ${b.nama}, ';
        } else {
          newText = '${b.nama}, ';
        }

        Future.microtask(() {
          _searchController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          if (mounted) {
            setState(() {
              _kataKunciPencarian = newText;
            });
            _muatDataAwal();
          }
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(8),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (v) {
              _kataKunciPencarian = v;
              _debounceTimer?.cancel();
              if (v.isEmpty) {
                _muatDataAwal();
              } else {
                _debounceTimer = Timer(const Duration(milliseconds: 200), () {
                  _muatDataAwal();
                });
              }
            },
            decoration: AppStyles
                .inputDecoration('Cari (cth: Sabun, Sampo)...', icon: Icons.search)
                .copyWith(
              filled: true,
              fillColor: AppColors.white,
              border: InputBorder.none,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    if (mounted) {
                      setState(() => _kataKunciPencarian = '');
                      _muatDataAwal();
                    }
                  })
                  : null,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.white,
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final Barang b = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: _buildAutocompleteAvatar(b),
                      title: Text(b.nama, style: AppStyles.labelStyle.copyWith(fontSize: 13)),
                      subtitle: Text(
                        '${_mapNamaMerek[b.merekId] ?? '-'} | Stok: ${AppStyles.formatNumber(b.stok)}',
                        style: AppStyles.caption,
                      ),
                      onTap: () => onSelected(b),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildAutocompleteAvatar(Barang b) {
    if (b.fotoPath != null && b.fotoPath!.isNotEmpty) {
      try {
        final file = File(b.fotoPath!);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              file,
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error loading autocomplete avatar: $e');
      }
    }
    return const Icon(Icons.image, size: 20);
  }

  void _tampilkanDialogOpsi(Barang b) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          b.nama.isNotEmpty ? b.nama : 'Tanpa Nama',
          style: AppStyles.h1.copyWith(color: AppColors.primary),
        ),
        children: [
          _buildItemOpsi("Barang Keluar", Icons.remove_shopping_cart, BarangKeluar(items: [b])),
          _buildItemOpsi("Barang Tambah", Icons.add_business, TambahBarang(items: [b])),
          _buildItemOpsi("Koreksi Stok", Icons.edit_attributes, AdjustmentStokPage(items: [b])),
          if (b.id != null)
            _buildItemOpsi("Riwayat Stok", Icons.history, LogStokPage(barangId: b.id!, namaBarang: b.nama)),
          _buildItemOpsi("Edit Data", Icons.edit, EditBarang(barang: b)),
          const Divider(),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _konfirmasiHapusBarang(b);
            },
            child: const Row(
              children: [
                Icon(Icons.delete, color: AppColors.error, size: 20),
                SizedBox(width: 12),
                Text("Hapus Barang", style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemOpsi(String t, IconData i, Widget hal) => SimpleDialogOption(
    onPressed: () async {
      Navigator.pop(context);
      final success = await Navigator.push(context, MaterialPageRoute(builder: (_) => hal));
      if (success == true && mounted) {
        _muatDataAwal();
        _muatDataPeringatan();
      }
    },
    child: Row(
      children: [
        Icon(i, size: 20, color: AppColors.secondary),
        const SizedBox(width: 12),
        Text(t, style: AppStyles.labelStyle.copyWith(fontWeight: FontWeight.normal)),
      ],
    ),
  );

  void _konfirmasiHapusBarang(Barang b) {
    if (b.id == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Konfirmasi Hapus"),
        content: Text("Hapus '${b.nama.isNotEmpty ? b.nama : 'Tanpa Nama'}' dari database?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              final success = await _barangController.deleteSafe(b.id!);
              if (success && mounted) {
                Navigator.pop(context);
                _muatDataAwal();
                _muatDataPeringatan();
              }
            },
            child: const Text("Hapus", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _tampilkanDialogFilter() {
    showDialog(
      context: context,
      builder: (_) {
        int? tKat = _idKategoriTerfilter, tMer = _idMerekTerfilter;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("Filter Tampilan"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // Label rata kiri
              children: [
                const Text("Pilih Kategori", style: AppStyles.labelStyle),
                const SizedBox(height: 8),
                _buildDropdownFilter('Kategori', _mapNamaKategori, tKat, (v) => setS(() => tKat = v)),
                const SizedBox(height: 16),
                const Text("Pilih Merek", style: AppStyles.labelStyle),
                const SizedBox(height: 8),
                _buildDropdownFilter('Merek', _mapNamaMerek, tMer, (v) => setS(() => tMer = v)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _idKategoriTerfilter = tKat;
                      _idMerekTerfilter = tMer;
                    });
                    Navigator.pop(context);
                    _muatDataAwal();
                  }
                },
                child: const Text("Terapkan"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdownFilter(String l, Map<int, String> d, int? v, Function(int?) onC) =>
      DropdownButtonFormField<int>(
        // FIXED: Gunakan key yang unik dengan menyertakan label 'l' 
        // untuk menghindari error "Duplicate keys found" saat kedua filter bernilai null.
        key: ValueKey('${l}_$v'),
        initialValue: (v != null && d.containsKey(v)) ? v : null,
        decoration: AppStyles.inputDecoration(l).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text("Semua")),
          ...d.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
        ],
        onChanged: onC,
      );
}
