import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../widgets/app_drawer.dart';
import '../../theme/grafik_widgets.dart';

class GrafikLaporanPage extends StatefulWidget {
  const GrafikLaporanPage({super.key});

  @override
  State<GrafikLaporanPage> createState() => _GrafikLaporanPageState();
}

class _GrafikLaporanPageState extends State<GrafikLaporanPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  DateTimeRange? _rangeK;
  DateTimeRange? _rangeB;

  List<FlSpot> _spotsInK = [];
  List<FlSpot> _spotsOutK = [];
  double _maxK = 100000;

  List<FlSpot> _spotsInB = [];
  List<FlSpot> _spotsOutB = [];
  double _maxB = 10;

  double _totalInK = 0;
  double _totalOutK = 0;
  double _totalInB = 0;
  double _totalOutB = 0;

  final _formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final _unitFormatter = NumberFormat.decimalPattern('id');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _rangeK = DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        end: now
    );
    _rangeB = DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        end: now
    );

    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDataKeuangan(),
      _loadDataBarang(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDataKeuangan() async {
    final db = await DatabaseHelper().database;
    
    final startStr = DateFormat('yyyy-MM-dd').format(_rangeK!.start);
    final endStr = DateFormat('yyyy-MM-dd').format(_rangeK!.end);

    // FIX: Gunakan filter tampil_di_laporan dan status != BATAL agar sinkron dengan tabel
    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT 
      SUBSTR(rp.tanggal, 1, 10) as tgl, 
      ds.jenis, 
      SUM(rp.nominal) as total 
    FROM riwayat_pembayaran rp
    JOIN dokumen_stok ds ON rp.dokumen_id = ds.id
    WHERE SUBSTR(rp.tanggal, 1, 10) BETWEEN ? AND ?
      AND ds.tampil_di_laporan = 1
      AND ds.status != 'BATAL'
    GROUP BY tgl, ds.jenis
  ''', [startStr, endStr]);

    final int totalDays = _rangeK!.end.difference(_rangeK!.start).inDays + 1;
    List<FlSpot> inSpots = [];
    List<FlSpot> outSpots = [];
    double tempMax = 0;
    double totalIn = 0;
    double totalOut = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = _rangeK!.start.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      double vIn = 0;
      double vOut = 0;

      for (var row in results) {
        if (row['tgl'] == dateStr) {
          if (row['jenis'] == 'keluar') {
            vIn = (row['total'] as num?)?.toDouble() ?? 0;
          }
          if (row['jenis'] == 'masuk') {
            vOut = (row['total'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      inSpots.add(FlSpot(i.toDouble(), vIn));
      outSpots.add(FlSpot(i.toDouble(), vOut));
      totalIn += vIn;
      totalOut += vOut;

      if (vIn > tempMax) tempMax = vIn;
      if (vOut > tempMax) tempMax = vOut;
    }

    if (mounted) {
      setState(() {
        _spotsInK = inSpots;
        _spotsOutK = outSpots;
        _totalInK = totalIn;
        _totalOutK = totalOut;
        _maxK = tempMax == 0 ? 100000 : tempMax * 1.2;
      });
    }
  }

  Future<void> _loadDataBarang() async {
    final db = await DatabaseHelper().database;
    
    final startStr = DateFormat('yyyy-MM-dd').format(_rangeB!.start);
    final endStr = DateFormat('yyyy-MM-dd').format(_rangeB!.end);

    // FIX: Tambahkan filter tampil_di_stok agar sinkron dengan daftar tabel dokumen
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        SUBSTR(ds.tanggal, 1, 10) as tgl, 
        ds.jenis, 
        SUM(di.qty) as q 
      FROM dokumen_item di 
      JOIN dokumen_stok ds ON di.dokumen_id = ds.id 
      WHERE SUBSTR(ds.tanggal, 1, 10) BETWEEN ? AND ?
        AND ds.status != 'BATAL'
        AND ds.tampil_di_stok = 1
      GROUP BY tgl, ds.jenis
    ''', [startStr, endStr]);

    final int totalDays = _rangeB!.end.difference(_rangeB!.start).inDays + 1;
    List<FlSpot> inSpots = [];
    List<FlSpot> outSpots = [];
    double tempMax = 0;
    double totalIn = 0;
    double totalOut = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = _rangeB!.start.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      double qIn = 0;
      double qOut = 0;

      for (var row in results) {
        if (row['tgl'] == dateStr) {
          if (row['jenis'] == 'masuk') qIn = (row['q'] as num?)?.toDouble() ?? 0;
          if (row['jenis'] == 'keluar') qOut = (row['q'] as num?)?.toDouble() ?? 0;
        }
      }

      inSpots.add(FlSpot(i.toDouble(), qIn));
      outSpots.add(FlSpot(i.toDouble(), qOut));
      totalIn += qIn;
      totalOut += qOut;

      if (qIn > tempMax) tempMax = qIn;
      if (qOut > tempMax) tempMax = qOut;
    }

    if (mounted) {
      setState(() {
        _spotsInB = inSpots;
        _spotsOutB = outSpots;
        _totalInB = totalIn;
        _totalOutB = totalOut;
        _maxB = tempMax == 0 ? 10 : tempMax * 1.2;
      });
    }
  }

  Future<void> _pickDateRange(bool isKeuangan) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: isKeuangan ? _rangeK : _rangeB,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'PILIH RENTANG TANGGAL ANALISIS',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            )
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      if (isKeuangan) {
        setState(() => _rangeK = picked);
        _loadDataKeuangan();
      } else {
        setState(() => _rangeB = picked);
        _loadDataBarang();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(selectedMenu: 'grafik'),
      appBar: AppBar(
        title: const Text('Statistik Bisnis', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.warning,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'KEUANGAN', icon: Icon(Icons.monetization_on, color: AppColors.white)),
            Tab(text: 'STOK BARANG', icon: Icon(Icons.swap_horiz, color: AppColors.white)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildSimpleGrafikView(true),
          _buildSimpleGrafikView(false),
        ],
      ),
    );
  }

  Widget _buildSimpleGrafikView(bool isKeuangan) {
    final range = isKeuangan ? _rangeK! : _rangeB!;
    final spot1 = isKeuangan ? _spotsInK : _spotsInB;
    final spot2 = isKeuangan ? _spotsOutK : _spotsOutB;
    final maxVal = isKeuangan ? _maxK : _maxB;
    final total1 = isKeuangan ? _totalInK : _totalInB;
    final total2 = isKeuangan ? _totalOutK : _totalOutB;

    return RefreshIndicator(
      onRefresh: _initData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppStyles.buildHeaderBanner(
              title: isKeuangan ? "LAPORAN ARUS KEUANGAN" : "LAPORAN ARUS BARANG",
              subtitle: "${DateFormat('MMMM', 'id').format(range.start).toUpperCase()} ${range.start.year}",
              isKeuangan: isKeuangan,
            ),
            const SizedBox(height: 16),
            RingkasanKartu(
                isKeuangan: isKeuangan,
                total1: total1,
                total2: total2,
                formatter: _formatter,
                unitFormatter: _unitFormatter
            ),
            const SizedBox(height: 20),
            _buildCalendarFilter(isKeuangan),
            const SizedBox(height: 20),
            if (total1 > 0 || total2 > 0)
              ChartContainer(
                spot1: spot1,
                spot2: spot2,
                max: maxVal,
                isKeuangan: isKeuangan,
                startDate: range.start,
              )
            else
              const NoDataState(),
            const SizedBox(height: 20),
            LegendBox(isKeuangan: isKeuangan),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarFilter(bool isKeuangan) {
    final formatTgl = DateFormat('dd MMM yyyy', 'id');
    final range = isKeuangan ? _rangeK! : _rangeB!;
    return InkWell(
      onTap: () => _pickDateRange(isKeuangan),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.disabled),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${formatTgl.format(range.start)}  s/d  ${formatTgl.format(range.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.black87),
          ],
        ),
      ),
    );
  }
}
