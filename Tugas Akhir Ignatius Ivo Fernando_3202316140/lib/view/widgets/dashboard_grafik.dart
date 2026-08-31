import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class DashboardGrafik extends StatefulWidget {
  const DashboardGrafik({super.key});

  @override
  State<DashboardGrafik> createState() => _DashboardGrafikState();
}

class _DashboardGrafikState extends State<DashboardGrafik> {
  List<FlSpot> _dataPendapatan = [];
  bool _isLoading = true;
  double _maxY = 0;

  @override
  void initState() {
    super.initState();
    _loadDataGrafik();
  }

  Future<void> _loadDataGrafik() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    
    // Optimasi: Gunakan format ISO Lengkap untuk Range Query yang memanfaatkan Index
    final startStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6))) + " 00:00:00";
    final endStr = DateFormat('yyyy-MM-dd').format(now) + " 23:59:59";

    // Optimasi Query: Hilangkan fungsi DATE() pada kolom tanggal agar INDEX terpakai
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        SUBSTR(rp.tanggal, 1, 10) as tgl, 
        SUM(rp.nominal) as total 
      FROM riwayat_pembayaran rp
      JOIN dokumen_stok ds ON rp.dokumen_id = ds.id
      WHERE ds.jenis = 'keluar' AND rp.tanggal BETWEEN ? AND ?
      GROUP BY tgl
    ''', [startStr, endStr]);

    List<FlSpot> spots = [];
    double tempMaxY = 0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      double total = 0;
      for (var row in results) {
        if (row['tgl'] == dateStr) {
          total = (row['total'] as num?)?.toDouble() ?? 0;
        }
      }
      
      spots.add(FlSpot((6 - i).toDouble(), total));
      if (total > tempMaxY) tempMaxY = total;
    }

    if (mounted) {
      setState(() {
        _dataPendapatan = spots;
        _maxY = tempMaxY == 0 ? 100000 : tempMaxY * 1.2;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 10),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: AppStyles.cardShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Arus Kas Masuk 7 Hari Terakhir", style: AppStyles.h2),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  horizontalInterval: _maxY > 0 ? _maxY / 4 : 1,
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                        return Text(DateFormat('dd/MM').format(date), style: AppStyles.chartLabel);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text("");
                        return Text(
                          NumberFormat.compactCurrency(symbol: '', locale: 'id').format(value), 
                          style: AppStyles.chartLabel,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _dataPendapatan,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
                  ),
                ],
                minY: 0,
                maxY: _maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
