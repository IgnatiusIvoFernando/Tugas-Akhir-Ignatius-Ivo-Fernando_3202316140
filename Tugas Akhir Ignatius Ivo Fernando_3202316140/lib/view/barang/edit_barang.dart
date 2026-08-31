import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../controller/barang_controller.dart';
import '../../controller/database_helper.dart';
import '../../models/barang.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class EditBarang extends StatefulWidget {
  final Barang barang;
  const EditBarang({super.key, required this.barang});

  @override
  State<EditBarang> createState() => _EditBarangState();
}

class _EditBarangState extends State<EditBarang> {
  // ==================== FORM KEY ====================
  final _formKey = GlobalKey<FormState>();
  final _barangController = BarangController();

  // ==================== CONTROLLERS ====================
  late TextEditingController _namaC, _beliC, _jualC, _descC, _kadC, _stokC, _customSatuanC;

  // ==================== STATE ====================
  File? _fotoBaru;
  DateTime? _selDate;
  int? _selKat, _selMer;
  bool _isInfinity = false;
  bool _isCustomSatuan = false;
  String _satuanTerpilih = 'Pcs';

  final List<String> _daftarSatuan = [
    'Pcs', 'Kg', 'Gram', 'Liter', 'mL', 'Unit', 'Box', 'Pack', 'Lusin', 'Kodi', 'Rim', 'Meter', 'Centimeter', 'Lainnya...'
  ];

  List<Map<String, dynamic>> _listKat = [], _listMer = [];

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    final b = widget.barang;

    _namaC = TextEditingController(text: b.nama);
    _beliC = TextEditingController(text: AppStyles.formatNumber(b.hargaBeli));
    _jualC = TextEditingController(text: AppStyles.formatNumber(b.hargaJual));
    _descC = TextEditingController(text: b.deskripsi);
    _customSatuanC = TextEditingController(text: b.satuan);
    
    _stokC = TextEditingController(text: AppStyles.formatNumber(b.stok));
    _isInfinity = b.stok >= BarangController.UNLIMITED_STOCK;

    if (_daftarSatuan.contains(b.satuan)) {
      _satuanTerpilih = b.satuan;
      _isCustomSatuan = false;
    } else {
      _satuanTerpilih = 'Lainnya...';
      _isCustomSatuan = true;
    }

    _selDate = b.tanggalKadaluarsa;
    _kadC = TextEditingController(
        text: _selDate != null ? DateFormat('yyyy-MM-dd').format(_selDate!) : ''
    );

    _selKat = b.kategoriId;
    _selMer = b.merekId;

    _loadMasterData();
  }

  @override
  void dispose() {
    for (var c in [_namaC, _beliC, _jualC, _descC, _kadC, _stokC, _customSatuanC]) {
      c.dispose();
    }
    super.dispose();
  }

  // ==================== MASTER DATA ====================
  Future<void> _loadMasterData() async {
    final db = await DatabaseHelper().database;
    final k = await db.query('kategori');
    final m = await db.query('merek');
    setState(() {
      _listKat = k;
      _listMer = m;
    });
  }

  // ==================== ACTIONS ====================
  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final double hargaBeli = AppStyles.parseNumber(_beliC.text);
      final double hargaJual = AppStyles.parseNumber(_jualC.text);
      final String satuan = _isCustomSatuan ? _customSatuanC.text.trim() : _satuanTerpilih;

      final barangUpdate = widget.barang.copyWith(
        nama: _namaC.text.trim(),
        hargaBeli: hargaBeli,
        hargaJual: hargaJual,
        stok: widget.barang.stok, 
        deskripsi: _descC.text.trim(),
        fotoPath: _fotoBaru?.path ?? widget.barang.fotoPath,
        kategoriId: _selKat,
        merekId: _selMer,
        tanggalKadaluarsa: _selDate,
        satuan: satuan,
      );

      await _barangController.update(barangUpdate);

      if (mounted) {
        AppStyles.showSuccessSnackBar(context, 'Perubahan berhasil disimpan!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppStyles.showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  // ==================== UI BUILD ====================
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Data Barang', style: AppStyles.appBarTitle),
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
              _field("Nama Barang", _namaC, hint: 'Contoh: Sabun Mandi'),
              Row(children: [
                Expanded(child: _dropdown('Kategori', _listKat, _selKat, (v) => setState(() => _selKat = v))),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Merek', _listMer, _selMer, (v) => setState(() => _selMer = v))),
              ]),
              Row(children: [
                Expanded(child: _field("Harga Beli (Opsional)", _beliC, isMoney: true, isRequired: false)),
                const SizedBox(width: 12),
                Expanded(child: _field("Harga Jual Satuan", _jualC, isMoney: true)),
              ]),
              _buildSatuanDropdown(),
              _field("Tanggal Kadaluarsa", _kadC, readOnly: true, icon: Icons.event_available, onTap: _pilihTanggal),
              const SizedBox(height: 16),

              _sectionTitle("Logistik & Stok"),
              _label("Stok Saat Ini"),
              _buildStokInput(),
              const SizedBox(height: 24),

              _field("Catatan / Deskripsi", _descC, maxLines: 3, isRequired: false),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _simpan,
                style: AppStyles.primaryButton,
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('SIMPAN PERUBAHAN')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WIDGETS ====================
  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      s.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
        letterSpacing: 1.2,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(s, style: AppStyles.labelStyle, overflow: TextOverflow.ellipsis),
  );

  Widget _field(
      String label,
      TextEditingController controller, {
        bool isMoney = false,
        bool readOnly = false,
        bool isRequired = true,
        IconData? icon,
        VoidCallback? onTap,
        int maxLines = 1,
        String? hint,
      }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: isMoney ? TextInputType.number : null,
            inputFormatters: isMoney ? [CurrencyInputFormatter()] : null,
            decoration: isMoney
                ? AppStyles.moneyInputDecoration()
                : AppStyles.inputDecoration(hint ?? '', icon: icon ?? Icons.edit_note),
            validator: (v) =>
            isRequired && (v == null || v.trim().isEmpty) && !readOnly ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _dropdown(
      String label,
      List<Map<String, dynamic>> items,
      int? value,
      Function(int?) onChanged,
      ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          DropdownButtonFormField<int>(
            value: value,
            isExpanded: true,
            items: items.map((e) => DropdownMenuItem<int>(
              value: e['id'],
              child: Text(e['nama'], overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: onChanged,
            decoration: AppStyles.inputDecoration(label),
            validator: (v) => v == null ? 'Pilih $label' : null,
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildSatuanDropdown() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label("Satuan"),
      if (!_isCustomSatuan)
        DropdownButtonFormField<String>(
          value: _satuanTerpilih,
          isExpanded: true,
          decoration: AppStyles.inputDecoration('Pilih Satuan'),
          items: _daftarSatuan.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, overflow: TextOverflow.ellipsis),
          )).toList(),
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _customSatuanC,
                decoration: AppStyles.inputDecoration('Masukkan satuan lain'),
                validator: (v) => v == null || v.isEmpty ? 'Masukkan satuan' : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _isCustomSatuan = false;
                  _customSatuanC.clear();
                  _satuanTerpilih = 'Pcs';
                });
              },
            ),
          ],
        ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildStokInput() => Container(
    decoration: AppStyles.cardOutline.copyWith(
      color: Colors.grey.shade50,
    ),
    child: TextFormField(
      controller: _stokC,
      readOnly: true,
      keyboardType: TextInputType.none,
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixIcon: Icon(
          _isInfinity ? Icons.all_inclusive : Icons.numbers,
          color: _isInfinity ? AppColors.primary : AppColors.disabled,
        ),
      ),
    ),
  );

  Widget _photoSelector() => GestureDetector(
    onTap: () async {
      final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (p == null) return;
      
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'barang_${DateTime.now().millisecondsSinceEpoch}${path.extension(p.path)}';
      final savedFile = await File(p.path).copy('${directory.path}/$fileName');
      
      setState(() => _fotoBaru = savedFile);
    },
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _fotoBaru != null
                ? Image.file(_fotoBaru!, fit: BoxFit.cover)
                : (widget.barang.fotoPath != null && File(widget.barang.fotoPath!).existsSync()
                ? Image.file(File(widget.barang.fotoPath!), fit: BoxFit.cover)
                : const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary)),
          ),
        ),
        const Positioned(
          bottom: -5,
          right: -5,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.edit, color: Colors.white, size: 18),
          ),
        ),
      ],
    ),
  );

  void _pilihTanggal() async {
    final p = await showDatePicker(
        context: context,
        initialDate: _selDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
    );
    if (p != null) {
      setState(() {
        _selDate = p;
        _kadC.text = DateFormat('yyyy-MM-dd').format(p);
      });
    }
  }
}
