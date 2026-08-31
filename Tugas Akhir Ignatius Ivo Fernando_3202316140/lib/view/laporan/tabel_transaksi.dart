// ==================== TABEL_TRANSAKSI_KEUANGAN_PAGE.dart ====================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../controller/dokumen_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class TabelTransaksiKeuanganPage extends StatefulWidget {
  final String tanggal;

  const TabelTransaksiKeuanganPage({
    super.key,
    required this.tanggal,
  });

  @override
  State<TabelTransaksiKeuanganPage> createState() => _TabelTransaksiKeuanganPageState();
}

class _TabelTransaksiKeuanganPageState extends State<TabelTransaksiKeuanganPage> {
  final DokumenController _dokumenController = DokumenController();
  late Future<List<Map<String, dynamic>>> _futureDataTransaksi;
  final _formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  late String _tanggalLengkap;

  @override
  void initState() {
    super.initState();
    final tgl = DateTime.parse(widget.tanggal);
    _tanggalLengkap = DateFormat('EEEE, dd MMMM yyyy', 'id').format(tgl);
    _muatDataDetail();
  }

  void _muatDataDetail() {
    setState(() {
      _futureDataTransaksi = _dokumenController.getDetailPerPeriode(widget.tanggal, onlyFinancial: true);
    });
  }

  String _ambilTanggalSaja(dynamic tanggal) {
    if (tanggal == null) return "-";
    String tglStr = tanggal.toString();
    if (tglStr.length >= 10) {
      return tglStr.substring(8, 10);
    }
    return tglStr;
  }

  Map<String, double> _hitungTotalKeuangan(List<Map<String, dynamic>> dataList) {
    double totalKasMasuk = 0;
    double totalKasKeluar = 0;

    for (var item in dataList) {
      double nominal = (item['nominal_bayar'] as num?)?.toDouble() ?? 0.0;
      if (item['jenis'] == 'keluar') {
        totalKasMasuk += nominal;
      } else {
        totalKasKeluar += nominal;
      }
    }
    return {'masuk': totalKasMasuk, 'keluar': totalKasKeluar};
  }

  Future<void> _exportKePDF(List<Map<String, dynamic>> dataList) async {
    try {
      final waktuSekarang = DateFormat('dd/MM/yyyy HH:mm', 'id').format(DateTime.now());
      final totals = _hitungTotalKeuangan(dataList);
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
                    pw.Text("LAPORAN ARUS KEUANGAN", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_tanggalLengkap.toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Text("Dicetak pada: $waktuSekarang", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['Tgl', 'Produk', 'Pemasok/Pelanggan', 'KELUAR', 'MASUK', 'Status', 'Keterangan'],
              data: dataList.map((item) {
                bool isPembelian = item['jenis'] == 'masuk';
                double nilaiTransaksi = (item['nominal_bayar'] as num?)?.toDouble() ?? 0.0;
                return [
                  _ambilTanggalSaja(item['tanggal']),
                  item['nama'] ?? "-",
                  item['pembeli'] ?? "-",
                  isPembelian ? _formatRupiah.format(nilaiTransaksi) : "-",
                  !isPembelian ? _formatRupiah.format(nilaiTransaksi) : "-",
                  item['status'] ?? "DIBAYAR",
                  item['ket_doc'] ?? "-",
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 20),
            _buildPdfSummary(totals['masuk']!, totals['keluar']!),
          ],
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: "Laporan_Keuangan_${widget.tanggal}");
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, "Gagal cetak PDF: $e");
    }
  }

  pw.Widget _buildPdfSummary(double masuk, double keluar) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text("Total Arus Masuk: ${_formatRupiah.format(masuk)}"),
      pw.Text("Total Arus Keluar: ${_formatRupiah.format(keluar)}"),
      pw.Divider(),
      pw.Text("Saldo Akhir Kas: ${_formatRupiah.format(masuk - keluar)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ])
  ]);

  Future<void> _exportKeExcel(List<Map<String, dynamic>> dataList) async {
    try {
      final waktuSekarang = DateFormat('dd/MM/yyyy HH:mm', 'id').format(DateTime.now());
      var excel = xl.Excel.createExcel();
      xl.Sheet sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
      
      sheet.appendRow([xl.TextCellValue('LAPORAN ARUS KEUANGAN')]);
      sheet.appendRow([xl.TextCellValue('Periode: $_tanggalLengkap')]);
      sheet.appendRow([xl.TextCellValue('Dicetak pada: $waktuSekarang')]);
      sheet.appendRow([xl.TextCellValue('')]);

      sheet.appendRow([
        xl.TextCellValue('Tgl'),
        xl.TextCellValue('Produk'),
        xl.TextCellValue('Pemasok/Pelanggan'),
        xl.TextCellValue('KELUAR'),
        xl.TextCellValue('MASUK'),
        xl.TextCellValue('Status'),
        xl.TextCellValue('Keterangan')
      ]);
      for (var item in dataList) {
        bool isPembelian = item['jenis'] == 'masuk';
        double nilaiTransaksi = (item['nominal_bayar'] as num?)?.toDouble() ?? 0.0;
        sheet.appendRow([
          xl.TextCellValue(_ambilTanggalSaja(item['tanggal'])),
          xl.TextCellValue(item['nama'] ?? "-"),
          xl.TextCellValue(item['pembeli'] ?? "-"),
          xl.DoubleCellValue(isPembelian ? nilaiTransaksi : 0.0),
          xl.DoubleCellValue(!isPembelian ? nilaiTransaksi : 0.0),
          xl.TextCellValue(item['status'] ?? "DIBAYAR"),
          xl.TextCellValue(item['ket_doc'] ?? "-"),
        ]);
      }
      final bytes = excel.save();
      if (bytes == null) throw Exception("Gagal membuat data Excel");

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }
      
      directory ??= await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String filePath = "${directory.path}/Keuangan_${widget.tanggal}_$timestamp.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          AppStyles.showSnackBar(context, "File tersimpan di: $filePath", backgroundColor: Colors.blue, icon: Icons.file_present);
        }
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, "Gagal ekspor Excel: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureDataTransaksi,
      builder: (context, snapshot) {
        final listFinancial = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text('Laporan $_tanggalLengkap', style: AppStyles.appBarTitle),
            backgroundColor: AppColors.primary,
            iconTheme: AppStyles.appBarIconTheme,
          ),
          body: _buildBodyContent(snapshot, listFinancial),
          bottomNavigationBar: listFinancial.isNotEmpty ? _buildActionArea(listFinancial) : null,
        );
      },
    );
  }

  Widget _buildBodyContent(AsyncSnapshot<List<Map<String, dynamic>>> snapshot, List<Map<String, dynamic>> financialList) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (financialList.isEmpty) return const Center(child: Text("Tidak ada transaksi keuangan"));

    final totals = _hitungTotalKeuangan(financialList);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        AppStyles.buildHeaderBanner(title: "LAPORAN ARUS KEUANGAN", subtitle: _tanggalLengkap, isKeuangan: true),
        const SizedBox(height: 16),
        _buildSummaryCards(totals['masuk']!, totals['keluar']!),
        const SizedBox(height: 20),
        _buildScrollableTable(financialList),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildSummaryCards(double masuk, double keluar) {
    return Row(
      children: [
        AppStyles.buildSummaryCard(
          label: "KAS MASUK",
          value: _formatRupiah.format(masuk),
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        AppStyles.buildSummaryCard(
          label: "KAS KELUAR",
          value: _formatRupiah.format(keluar),
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        AppStyles.buildSummaryCard(
          label: "SALDO AKHIR",
          value: _formatRupiah.format(masuk - keluar),
          color: AppColors.primary,
        ),
      ],
    );
  }

  void _showBayarHutangDialog(Map<String, dynamic> row) {
    AppStyles.showPelunasanDialog(
      context: context,
      controller: _dokumenController,
      doc: row,
      onSuccess: () => _muatDataDetail(),
    );
  }

  Widget _buildScrollableTable(List<Map<String, dynamic>> items) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
          decoration: AppStyles.cardOutline,
          child: SizedBox(
              width: 1100,
              child: Table(
                  border: TableBorder.all(color: AppColors.disabledBackground, width: 0.5),
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(2.2),
                    2: FlexColumnWidth(2.2),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.2),
                    6: FlexColumnWidth(2.5),
                  },
                  children: [_buildTableHeader(), ...items.map((item) => _buildTableRow(item)).toList()]
              )
          )
      )
  );

  TableRow _buildTableHeader() => const TableRow(
      decoration: BoxDecoration(color: AppColors.primary),
      children: [
        _Cell("TGL", isHeader: true),
        _Cell("PRODUK", isHeader: true),
        _Cell("PELANGGAN/PEMASOK", isHeader: true),
        _Cell("KELUAR", isHeader: true),
        _Cell("MASUK", isHeader: true),
        _Cell("STATUS", isHeader: true),
        _Cell("KETERANGAN", isHeader: true),
      ]
  );

  TableRow _buildTableRow(Map<String, dynamic> row) {
    bool isPembelian = row['jenis'] == 'masuk';
    bool isBatal = row['status'] == 'BATAL';
    bool isHutang = row['status'] == 'HUTANG';
    double nilai = (row['nominal_bayar'] as num).toDouble();

    VoidCallback? onTap = isHutang ? () => _showBayarHutangDialog(row) : null;

    return TableRow(children: [
      _Cell(_ambilTanggalSaja(row['tanggal']), isStrikethrough: isBatal, onTap: onTap),
      _Cell(row['nama'] ?? "-", isStrikethrough: isBatal, align: TextAlign.left, onTap: onTap),
      _Cell(row['pembeli'] ?? "-", isStrikethrough: isBatal, align: TextAlign.left, onTap: onTap),
      _Cell(isPembelian ? _formatRupiah.format(nilai) : "-",
          textColor: isBatal ? Colors.grey : (isPembelian ? AppColors.error : null),
          isStrikethrough: isBatal,
          isBold: isPembelian && !isBatal,
          onTap: onTap),
      _Cell(!isPembelian ? _formatRupiah.format(nilai) : "-",
          textColor: isBatal ? Colors.grey : (!isPembelian ? AppColors.success : null),
          isStrikethrough: isBatal,
          isBold: !isPembelian && !isBatal,
          onTap: onTap),
      _Cell(row['status'] ?? "DIBAYAR",
          isBold: true,
          textColor: isBatal ? Colors.grey : (isHutang ? AppColors.error : null),
          onTap: onTap),
      _Cell(row['ket_doc']?.toString() ?? "-", align: TextAlign.left, isStrikethrough: isBatal, onTap: onTap),
    ]);
  }

  Widget _buildActionArea(List<Map<String, dynamic>> items) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _btn(
              Icons.print,
              "Print PDF",
              AppColors.tertiary,
              () => _exportKePDF(items),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _btn(
              Icons.grid_on,
              "Export Excel",
              AppColors.success,
              () => _exportKeExcel(items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData i, String l, Color c, VoidCallback t) => ElevatedButton.icon(
    onPressed: t,
    icon: Icon(i, size: 18),
    label: Text(l, overflow: TextOverflow.ellipsis),
    style: ElevatedButton.styleFrom(
      backgroundColor: c,
      foregroundColor: Colors.white,
    ),
  );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool isBold;
  final bool isStrikethrough;
  final Color? textColor;
  final TextAlign align;
  final VoidCallback? onTap;

  const _Cell(this.text, {
    this.isHeader = false, 
    this.isBold = false,
    this.isStrikethrough = false,
    this.textColor,
    this.align = TextAlign.center,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isHeader ? 11 : 10,
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.white : (textColor ?? (isStrikethrough ? Colors.grey : AppColors.black87)),
            decoration: isStrikethrough
                ? TextDecoration.lineThrough
                : (onTap != null ? TextDecoration.underline : null),
          )
        )
      ),
    );
  }
}
