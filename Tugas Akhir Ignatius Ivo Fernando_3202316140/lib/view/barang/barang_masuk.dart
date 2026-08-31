import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../controller/database_helper.dart';
import '../../controller/barang_controller.dart';
import '../../controller/dokumen_controller.dart';
import '../../models/barang.dart';
import '../../models/dokumen_stok.dart';
import '../../models/dokumen_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class BarangMasuk extends StatefulWidget {
  const BarangMasuk({super.key});

  @override
  State<BarangMasuk> createState() => _BarangMasukState();
}

class _BarangMasukState extends State<BarangMasuk> {
  final _formKey = GlobalKey<FormState>();

  final _namaC = TextEditingController();
  final _beliC = TextEditingController();
  final _jualC = TextEditingController();
  final _descC = TextEditingController();
  final _kadC = TextEditingController();
  final _tagihanC = TextEditingController();
  final _bayarC = TextEditingController();
  final _diskonC = TextEditingController(text: '0');
  final _pajakC = TextEditingController(text: '11');
  final _stokC = TextEditingController(text: '1');
  final _customSatuanC = TextEditingController();

  File? _foto;
  DateTime? _selDate;
  int? _selPem, _selKat, _selMer;

  bool _isKeu = false;
  bool _isPajakAktif = false;
  bool _isCalculating = false;
  bool _isCustomSatuan = false;
  bool _isInfinity = false;

  double _nominalDiskon = 0;
  double _nominalPajak = 0;
  double _totalHarusBayar = 0;
  double _kembalian = 0;

  String _satuanTerpilih = 'Pcs';

  final List<String> _daftarSatuan = [
    'Pcs', 'Kg', 'Gram', 'Liter', 'mL', 'Unit', 'Box', 'Pack', 'Lusin', 'Kodi', 'Rim', 'Meter', 'Centimeter', 'Lainnya...'
  ];

  List<Map<String, dynamic>> _listKat = [];
  List<Map<String, dynamic>> _listMer = [];
  List<Map<String, dynamic>> _listPem = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    
    _tagihanC.addListener(_hitungSeluruhNota);
    _diskonC.addListener(_hitungSeluruhNota);
    _pajakC.addListener(_hitungSeluruhNota);
    _bayarC.addListener(_hitungKembalian);
    _hitungSeluruhNota();
  }

  @override
  void dispose() {
    for (var c in [_namaC, _beliC, _jualC, _descC, _kadC, _tagihanC, _bayarC, _diskonC, _pajakC, _stokC, _customSatuanC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    final db = await DatabaseHelper().database;
    final k = await db.query('kategori');
    final m = await db.query('merek');
    final p = await db.query('penyuplai', where: 'is_deleted = 0');
    setState(() {
      _listKat = k;
      _listMer = m;
      _listPem = p;
    });
  }

  void _hitungSeluruhNota() {
    if (_isCalculating) return;
    _isCalculating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isCalculating = false;
        return;
      }

      final double totalKotor = AppStyles.parseNumber(_tagihanC.text);
      final double persenDiskon = AppStyles.parseNumber(_diskonC.text);
      final double persenPajak = _isPajakAktif ? AppStyles.parseNumber(_pajakC.text) : 0;
      final double bayar = AppStyles.parseNumber(_bayarC.text);

      setState(() {
        _nominalDiskon = totalKotor * (persenDiskon / 100);
        double setelahDiskon = totalKotor - _nominalDiskon;
        _nominalPajak = setelahDiskon * (persenPajak / 100);
        _totalHarusBayar = setelahDiskon + _nominalPajak;
        _kembalian = bayar - _totalHarusBayar;
        _isCalculating = false;
      });
    });
  }

  void _hitungKembalian() {
    setState(() {
      _kembalian = AppStyles.parseNumber(_bayarC.text) - _totalHarusBayar;
    });
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final double fixStok = _isInfinity ? BarangController.UNLIMITED_STOCK : AppStyles.parseNumber(_stokC.text);

    if (_isKeu) {
      if (_selPem == null) return AppStyles.showWarningSnackBar(context, 'Pilih pemasok!');
      if (_totalHarusBayar <= 0) return AppStyles.showWarningSnackBar(context, 'Tagihan wajib diisi!');
    }

    try {
      final barangController = BarangController();
      final dokumenController = DokumenController();
      
      final hargaBeliInput = AppStyles.parseNumber(_beliC.text);
      final hargaJual = AppStyles.parseNumber(_jualC.text);
      final tagihanDasar = AppStyles.parseNumber(_tagihanC.text);
      final satuan = _isCustomSatuan ? _customSatuanC.text.trim() : _satuanTerpilih;

      // 1. Buat Objek Barang
      final barangBaru = Barang(
        nama: _namaC.text.trim(),
        deskripsi: _descC.text.trim(),
        hargaBeli: hargaBeliInput,
        hargaJual: hargaJual,
        stok: fixStok,
        fotoPath: _foto?.path,
        kategoriId: _selKat,
        merekId: _selMer,
        satuan: satuan,
        tanggalKadaluarsa: _selDate,
      );

      // 2. Simpan Barang via Controller
      final bId = await barangController.insert(barangBaru);

      // 3. Simpan Transaksi Dokumen jika diperlukan
      final bayar = _isKeu ? AppStyles.parseNumber(_bayarC.text) : 0.0;
      
      final dokumen = DokumenStok(
        jenis: JenisDokumen.masuk,
        judul: "Stok Awal: ${_namaC.text}",
        tanggal: DateTime.now(),
        keterangan: "Stok Awal",
        penyuplaiId: _selPem,
        totalAkhir: _isKeu ? _totalHarusBayar : 0.0,
        nominalBayar: bayar,
        pajakPersen: _isKeu ? AppStyles.parseNumber(_pajakC.text) : 0,
        diskonPersen: _isKeu ? AppStyles.parseNumber(_diskonC.text) : 0,
      );

      final double unitPrice = _isKeu 
          ? (fixStok > 0 ? (tagihanDasar / fixStok) : 0.0) 
          : hargaBeliInput;

      final item = DokumenItem(
        dokumenId: 0, 
        barangId: bId,
        qty: fixStok,
        harga: unitPrice,
      );

      await dokumenController.simpanTransaksiLengkap(
        dokumen: dokumen,
        items: [item],
        nominalAwal: _isKeu && bayar > 0 ? bayar : null,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tambah Barang Baru', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: AppStyles.appBarIconTheme,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _photoSelector()),
              const SizedBox(height: 30),
              _sectionTitle("Informasi Produk"),
              _field("Nama Barang", _namaC, hint: 'Sabun Mandi'),
              Row(children: [
                Expanded(child: _dropdown('Kategori', _listKat, _selKat, (v) => setState(() => _selKat = v))),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Merek', _listMer, _selMer, (v) => setState(() => _selMer = v))),
              ]),
              Row(children: [
                Expanded(child: _field("Harga Beli (Opsional)", _beliC, isMoney: true, isRequired: false)),
                const SizedBox(width: 12),
                Expanded(child: _field("Harga Jual", _jualC, isMoney: true)),
              ]),
              _buildSatuanDropdown(),
              _field("Tanggal Kadaluarsa", _kadC, readOnly: true, icon: Icons.event, onTap: _pilihTanggalKadaluarsa),
              const SizedBox(height: 16),
              _sectionTitle("Logistik & Stok"),
              _buildStokHeader(),
              _buildStokInput(),
              const SizedBox(height: 24),
              _keuanganSection(),
              _field("Catatan", _descC, maxLines: 3, isRequired: false),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _simpan,
                style: AppStyles.primaryButton,
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('SIMPAN BARANG BARU')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      s.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(s, style: AppStyles.labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  Widget _field(String label, TextEditingController controller, {bool isMoney = false, bool readOnly = false, bool isRequired = true, IconData? icon, VoidCallback? onTap, int maxLines = 1, String? hint}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(label),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: isMoney ? TextInputType.number : null,
            inputFormatters: isMoney ? [CurrencyInputFormatter()] : null,
            decoration: isMoney ? AppStyles.moneyInputDecoration(hintText: '0') : AppStyles.inputDecoration(hint ?? '', icon: icon ?? Icons.edit_note),
            validator: (v) => isRequired && (v == null || v.isEmpty) && !readOnly ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _dropdown(String label, List<Map<String, dynamic>> items, int? value, Function(int?) onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(label),
          DropdownButtonFormField<int>(
            value: value,
            isExpanded: true,
            items: items.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['nama'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
            decoration: AppStyles.inputDecoration(label),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildSatuanDropdown() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label("Satuan"),
      if (!_isCustomSatuan)
        DropdownButtonFormField<String>(
          value: _satuanTerpilih,
          isExpanded: true,
          decoration: AppStyles.inputDecoration('Pilih Satuan'),
          items: _daftarSatuan.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            setState(() {
              if (v == 'Lainnya...') {
                _isCustomSatuan = true;
                _customSatuanC.text = '';
              } else {
                _satuanTerpilih = v!;
                _isCustomSatuan = false;
              }
            });
          },
          validator: (v) => v == null ? 'Pilih satuan' : null,
        ),
      if (_isCustomSatuan)
        Row(children: [
            Expanded(child: TextFormField(controller: _customSatuanC, decoration: AppStyles.inputDecoration('Masukkan satuan lain'), validator: (v) => v == null || v.isEmpty ? 'Masukkan satuan' : null)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() { _isCustomSatuan = false; _customSatuanC.clear(); })),
          ],
        ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildStokHeader() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: _label("Stok Awal")),
      Row(children: [
          const Text("Tak Terbatas (∞)", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Switch(value: _isInfinity, onChanged: (v) => setState(() { _isInfinity = v; _stokC.text = v ? '∞' : '1'; })),
        ],
      ),
    ],
  );

  Widget _buildStokInput() => Container(
    decoration: AppStyles.cardOutline.copyWith(color: _isInfinity ? Colors.grey.shade50 : Colors.white),
    child: TextFormField(
      controller: _stokC,
      readOnly: _isInfinity,
      keyboardType: _isInfinity ? TextInputType.none : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _isInfinity ? [] : [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+[.,]?[0-9]*$'))],
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        hintText: 'Contoh: 0.5 untuk setengah',
        suffixIcon: Icon(_isInfinity ? Icons.all_inclusive : Icons.numbers, color: _isInfinity ? AppColors.primary : AppColors.disabled),
      ),
      validator: (v) {
        if (_isInfinity) return null;
        if (v == null || v.isEmpty) return 'Masukkan jumlah stok';
        if (AppStyles.parseNumber(v) <= 0) return 'Stok harus > 0';
        return null;
      },
    ),
  );

  Widget _keuanganSection() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 24),
    decoration: AppStyles.cardShadow.copyWith(
      color: _isKeu ? AppColors.primary.withValues(alpha: 0.02) : Colors.white,
      border: Border.all(color: _isKeu ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Expanded(child: Text('Catat transaksi beli?', style: TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Switch(value: _isKeu, onChanged: (v) => setState(() { _isKeu = v; _hitungSeluruhNota(); })),
          ],
        ),
        if (_isKeu) ...[
          const Divider(height: 32),
          _dropdown('Pemasok', _listPem, _selPem, (v) => setState(() => _selPem = v)),
          Row(children: [
            Expanded(child: _field("Diskon (%)", _diskonC, isRequired: false)),
            const SizedBox(width: 12),
            Expanded(child: _field("Pajak (%)", _pajakC, isRequired: false)),
            Padding(padding: const EdgeInsets.only(top: 25), child: Switch(value: _isPajakAktif, onChanged: (v) { setState(() { _isPajakAktif = v; _hitungSeluruhNota(); }); }, activeThumbColor: AppColors.primary)),
          ]),
          _field("Tagihan Dasar (Total Nota Vendor)", _tagihanC, isMoney: true),
          _summary(),
          _field("Jumlah Bayar", _bayarC, isMoney: true),
          _kembaliBox(),
        ],
      ],
    ),
  );

  Widget _summary() => Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppStyles.cardOutline.copyWith(color: AppColors.blue50),
      child: Column(children: [
        _sumRow('Potongan Diskon', '- ${AppStyles.formatCurrency(_nominalDiskon, showDecimal: true)}', true),
        _sumRow('Biaya Pajak', '+ ${AppStyles.formatCurrency(_nominalPajak, showDecimal: true)}', false),
        const Divider(),
        _sumRow('TOTAL MODAL BERSIH', AppStyles.formatCurrency(_totalHarusBayar), false, true),
      ]),
    );

  Widget _sumRow(String label, String value, bool neg, [bool bold = false]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.bold : null, color: neg ? Colors.red : (bold ? AppColors.primary : null))),
      ],
    ),
  );

  Widget _kembaliBox() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _kembalian < -0.01 ? Colors.red.shade50 : (_kembalian > 0.01 ? Colors.green.shade50 : Colors.blue.shade50), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(_kembalian < -0.01 ? 'HUTANG ${AppStyles.formatCurrency(_kembalian.abs())}' : (_kembalian > 0.01 ? 'KEMBALI ${AppStyles.formatCurrency(_kembalian)}' : 'PAS'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, color: _kembalian < -0.01 ? AppColors.error : (_kembalian > 0.01 ? AppColors.success : Colors.blue)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  Widget _photoSelector() => GestureDetector(
    onTap: _ambilFoto,
    child: Container(
      width: 140, height: 140,
      decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)], image: _foto != null ? DecorationImage(image: FileImage(_foto!), fit: BoxFit.cover) : null),
      child: _foto == null ? const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary) : null,
    ),
  );

  Future<void> _ambilFoto() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p == null) return;
    final saved = await File(p.path).copy('${(await getApplicationDocumentsDirectory()).path}/${DateTime.now().millisecondsSinceEpoch}${path.extension(p.path)}');
    setState(() => _foto = saved);
  }

  void _pilihTanggalKadaluarsa() async {
    final p = await showDatePicker(context: context, initialDate: _selDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p != null) setState(() { _selDate = p; _kadC.text = DateFormat('yyyy-MM-dd').format(p); });
  }
}
