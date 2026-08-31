import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../controller/dokumen_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class TabelDokumenStokPage extends StatefulWidget {
  final String tanggal;
  final String bulanNama;
  final String tahun;

  const TabelDokumenStokPage({
    super.key,
    required this.tanggal,
    required this.bulanNama,
    required this.tahun,
  });

  @override
  State<TabelDokumenStokPage> createState() => _TabelDokumenStokPageState();
}

class _TabelDokumenStokPageState extends State<TabelDokumenStokPage> {
  final DokumenController _dokumenController = DokumenController();
  late Future<List<Map<String, dynamic>>> _futureDataArusBarang;
  String _tanggalTeksLengkap = "";

  @override
  void initState() {
    super.initState();
    _futureDataArusBarang = _dokumenController.getDetailPerPeriode(
      widget.tanggal,
      onlyNonFinancial: true,
    );
    _formatHeaderTanggal();
  }

  void _formatHeaderTanggal() {
    try {
      DateTime tgl = DateTime.parse(widget.tanggal);
      _tanggalTeksLengkap = DateFormat('EEEE, dd MMMM yyyy', 'id').format(tgl);
    } catch (_) {
      _tanggalTeksLengkap = "${widget.bulanNama} ${widget.tahun}";
    }
  }

  String _ambilTanggalSaja(dynamic tanggal) {
    if (tanggal == null) return "-";
    String tglStr = tanggal.toString();
    if (tglStr.length >= 10) {
      return tglStr.substring(8, 10);
    }
    return tglStr;
  }

  String _formatQty(dynamic value) {
    return AppStyles.formatNumber(value);
  }

  Future<void> _prosesCetakPDF(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      if (mounted) {
        AppStyles.showWarningSnackBar(context, 'Tidak ada data untuk dicetak');
      }
      return;
    }

    try {
      final waktuSekarang = DateFormat('dd/MM/yyyy HH:mm', 'id').format(DateTime.now());
      double totalIn = 0;
      double totalOut = 0;
      for (var it in items) {
        double q = double.tryParse(it['qty'].toString()) ?? 0;
        if (_isMasuk(it['jenis'])) {
          totalIn += q;
        } else {
          totalOut += q;
        }
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("LAPORAN ARUS BARANG", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_tanggalTeksLengkap.toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Text("Dicetak pada: $waktuSekarang", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['Tgl', 'Nama Barang', 'Pemasok (IN)', 'Pelanggan (OUT)', 'MASUK', 'KELUAR', 'Keterangan'],
              data: items.map((item) {
                bool isMasuk = _isMasuk(item['jenis']);
                return [
                  _ambilTanggalSaja(item['tanggal']),
                  item['nama']?.toString() ?? "-",
                  isMasuk ? (item['pembeli']?.toString() ?? "-") : "-",
                  !isMasuk ? (item['pembeli']?.toString() ?? "-") : "-",
                  isMasuk ? _formatQty(item['qty']) : "-",
                  !isMasuk ? _formatQty(item['qty']) : "-",
                  item['ket_doc']?.toString() ?? "-",
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("TOTAL MASUK : ${_formatQty(totalIn)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("TOTAL KELUAR : ${_formatQty(totalOut)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Container(height: 1, width: 150, color: PdfColors.black),
                  pw.SizedBox(height: 5),
                  pw.Text("TOTAL BARANG : ${_formatQty(totalIn - totalOut)}",
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (f) => pdf.save(), name: "Laporan_Stok_${widget.tanggal}");
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, "Gagal mencetak PDF: $e");
    }
  }

  Future<void> _prosesExportExcel(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    try {
      final waktuSekarang = DateFormat('dd/MM/yyyy HH:mm', 'id').format(DateTime.now());
      var excel = xl.Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      sheet.appendRow([xl.TextCellValue('LAPORAN ARUS BARANG')]);
      sheet.appendRow([xl.TextCellValue('Periode: $_tanggalTeksLengkap')]);
      sheet.appendRow([xl.TextCellValue('Dicetak pada: $waktuSekarang')]);
      sheet.appendRow([xl.TextCellValue('')]);

      sheet.appendRow([
        xl.TextCellValue('Tgl'),
        xl.TextCellValue('Produk'),
        xl.TextCellValue('Pemasok (IN)'),
        xl.TextCellValue('Pelanggan (OUT)'),
        xl.TextCellValue('QTY IN'),
        xl.TextCellValue('QTY OUT'),
        xl.TextCellValue('Keterangan')
      ]);

      double totalIn = 0;
      double totalOut = 0;

      for (var item in items) {
        bool isMasuk = _isMasuk(item['jenis']);
        double qty = double.tryParse(item['qty'].toString()) ?? 0;
        if (isMasuk) totalIn += qty; else totalOut += qty;

        sheet.appendRow([
          xl.TextCellValue(_ambilTanggalSaja(item['tanggal'])),
          xl.TextCellValue(item['nama']?.toString() ?? "-"),
          xl.TextCellValue(isMasuk ? (item['pembeli']?.toString() ?? "-") : "-"),
          xl.TextCellValue(!isMasuk ? (item['pembeli']?.toString() ?? "-") : "-"),
          xl.DoubleCellValue(isMasuk ? qty : 0),
          xl.DoubleCellValue(!isMasuk ? qty : 0),
          xl.TextCellValue(item['ket_doc']?.toString() ?? "-"),
        ]);
      }

      sheet.appendRow([xl.TextCellValue('')]);
      sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('SUMMARY')]);
      sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('Total Masuk'), xl.DoubleCellValue(totalIn)]);
      sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('Total Keluar'), xl.DoubleCellValue(totalOut)]);
      sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('TOTAL BARANG'), xl.DoubleCellValue(totalIn - totalOut)]);

      final bytes = excel.save();
      if (bytes == null) return;

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String filePath = "${directory.path}/Stok_${widget.tanggal}_$timestamp.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          AppStyles.showSnackBar(context, 'File tersimpan di: $filePath', backgroundColor: Colors.blue, icon: Icons.file_present);
        }
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, "Gagal mengekspor Excel: $e");
    }
  }

  bool _isMasuk(dynamic jenis) {
    if (jenis == null) return false;
    final jenisStr = jenis.toString().toLowerCase();
    return jenisStr == 'masuk' || jenisStr == '0';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureDataArusBarang,
      builder: (context, snapshot) {
        final dataItems = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: Text('Laporan $_tanggalTeksLengkap', style: AppStyles.appBarTitle),
            backgroundColor: AppColors.primary,
            iconTheme: AppStyles.appBarIconTheme,
          ),
          body: _buildMainBody(snapshot, dataItems),
          bottomNavigationBar: dataItems.isNotEmpty ? _buildActionArea(dataItems) : null,
        );
      },
    );
  }

  Widget _buildMainBody(AsyncSnapshot<List<Map<String, dynamic>>> snapshot, List<Map<String, dynamic>> items) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text("Tidak ada mutasi barang pada tanggal ini"));

    double totalMasuk = 0;
    double totalKeluar = 0;
    for (var it in items) {
      double q = double.tryParse(it['qty'].toString()) ?? 0;
      if (_isMasuk(it['jenis'])) totalMasuk += q; else totalKeluar += q;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppStyles.buildHeaderBanner(title: "LAPORAN ARUS BARANG", subtitle: _tanggalTeksLengkap, isKeuangan: false),
          const SizedBox(height: 16),
          _buildSummaryCards(totalMasuk, totalKeluar),
          const SizedBox(height: 20),
          _buildTable(items),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double inQty, double outQty) {
    return Row(
      children: [
        Expanded(child: AppStyles.buildSummaryCard(label: "TOTAL MASUK", value: _formatQty(inQty), color: AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: AppStyles.buildSummaryCard(label: "TOTAL KELUAR", value: _formatQty(outQty), color: AppColors.error)),
        const SizedBox(width: 8),
        Expanded(child: AppStyles.buildSummaryCard(label: "TOTAL BARANG", value: _formatQty(inQty - outQty), color: AppColors.primary)),
      ],
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: AppStyles.cardOutline,
        child: SizedBox(
          width: 950,
          child: Table(
            border: TableBorder.all(color: AppColors.disabledBackground, width: 0.5),
            columnWidths: const {
              0: FlexColumnWidth(0.8), 1: FlexColumnWidth(2.5), 2: FlexColumnWidth(2),
              3: FlexColumnWidth(2), 4: FlexColumnWidth(1), 5: FlexColumnWidth(1), 6: FlexColumnWidth(3)
            },
            children: [_buildHeaderRow(), ...items.map((it) => _buildDataRow(it))],
          ),
        ),
      ),
    );
  }

  TableRow _buildHeaderRow() => const TableRow(
    decoration: BoxDecoration(color: AppColors.primary),
    children: [
      _Cell("TGL", isHeader: true), _Cell("NAMA BARANG", isHeader: true), _Cell("PEMASOK (IN)", isHeader: true),
      _Cell("PELANGGAN (OUT)", isHeader: true), _Cell("IN", isHeader: true), _Cell("OUT", isHeader: true), _Cell("KETERANGAN", isHeader: true),
    ],
  );

  TableRow _buildDataRow(Map<String, dynamic> item) {
    bool isMasuk = _isMasuk(item['jenis']);
    return TableRow(
      children: [
        _Cell(_ambilTanggalSaja(item['tanggal'])),
        _Cell(item['nama']?.toString() ?? "-", align: TextAlign.left),
        _Cell(isMasuk ? (item['pembeli']?.toString() ?? "-") : "-", align: TextAlign.left, color: isMasuk ? null : Colors.grey),
        _Cell(!isMasuk ? (item['pembeli']?.toString() ?? "-") : "-", align: TextAlign.left, color: !isMasuk ? null : Colors.grey),
        _Cell(isMasuk ? _formatQty(item['qty']) : "-", color: AppColors.success, isBold: isMasuk),
        _Cell(!isMasuk ? _formatQty(item['qty']) : "-", color: AppColors.error, isBold: !isMasuk),
        _Cell(item['ket_doc']?.toString() ?? "-", align: TextAlign.left),
      ],
    );
  }

  Widget _buildActionArea(List<Map<String, dynamic>> items) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          Expanded(child: _btn(Icons.print, "Print PDF", AppColors.tertiary, () => _prosesCetakPDF(items))),
          const SizedBox(width: 12),
          Expanded(child: _btn(Icons.grid_on, "Ke Excel", AppColors.success, () => _prosesExportExcel(items))),
        ],
      ),
    );
  }

  Widget _btn(IconData i, String l, Color c, VoidCallback t) => ElevatedButton.icon(
    onPressed: t, icon: Icon(i, size: 18), label: Text(l, overflow: TextOverflow.ellipsis),
    style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white),
  );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isBold;
  final bool isHeader;
  final Color? color;
  final TextAlign align;
  const _Cell(this.text, {this.isBold = false, this.isHeader = false, this.color, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text, 
        textAlign: align, 
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: (isBold || isHeader) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.white : (color ?? AppColors.black87),
        )
      ),
    );
  }
}
