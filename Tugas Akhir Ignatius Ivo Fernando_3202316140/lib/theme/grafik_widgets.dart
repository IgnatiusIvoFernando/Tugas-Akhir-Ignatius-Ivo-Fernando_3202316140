import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'app_styles.dart';

/// Widget Header Banner untuk Laporan
class HeaderBanner extends StatelessWidget {
  final bool isKeuangan;
  final DateTimeRange range;

  const HeaderBanner({super.key, required this.isKeuangan, required this.range});

  @override
  Widget build(BuildContext context) {
    return AppStyles.buildHeaderBanner(
      title: isKeuangan ? "LAPORAN ARUS KEUANGAN" : "LAPORAN ARUS BARANG",
      subtitle: "${DateFormat('MMMM', 'id').format(range.start).toUpperCase()} ${range.start.year}",
      isKeuangan: isKeuangan,
    );
  }
}

/// Widget Ringkasan Angka dalam bentuk Kartu
class RingkasanKartu extends StatelessWidget {
  final bool isKeuangan;
  final double total1;
  final double total2;
  final NumberFormat formatter;
  final NumberFormat unitFormatter;

  const RingkasanKartu({
    super.key,
    required this.isKeuangan,
    required this.total1,
    required this.total2,
    required this.formatter,
    required this.unitFormatter,
  });

  @override
  Widget build(BuildContext context) {
    // Validasi angka
    final safeTotal1 = _safeDouble(total1);
    final safeTotal2 = _safeDouble(total2);
    final saldo = safeTotal1 - safeTotal2;

    if (isKeuangan) {
      return Row(
        children: [
          AppStyles.buildSummaryCard(
            label: "KAS MASUK",
            value: formatter.format(safeTotal1),
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          AppStyles.buildSummaryCard(
            label: "KAS KELUAR",
            value: formatter.format(safeTotal2),
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          AppStyles.buildSummaryCard(
            label: "SALDO KAS",
            value: formatter.format(saldo),
            color: AppColors.primary,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          AppStyles.buildSummaryCard(
            label: "TOTAL MASUK",
            value: AppStyles.formatNumber(safeTotal1),
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          AppStyles.buildSummaryCard(
            label: "TOTAL KELUAR",
            value: AppStyles.formatNumber(safeTotal2),
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          AppStyles.buildSummaryCard(
            label: "TOTAL BARANG",
            value: AppStyles.formatNumber(saldo),
            color: AppColors.primary,
          ),
        ],
      );
    }
  }

  double _safeDouble(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value;
  }
}

/// Widget untuk tampilan saat data tidak ditemukan
class NoDataState extends StatelessWidget {
  final double? height;
  const NoDataState({super.key, this.height});

  @override
  Widget build(BuildContext context) {
    final containerHeight = height ?? MediaQuery.of(context).size.height * 0.4;
    return Container(
      height: containerHeight,
      width: double.infinity,
      decoration: AppStyles.cardOutline,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: AppColors.disabled),
          SizedBox(height: 16),
          Text(
            "Tidak ada data untuk rentang ini",
            style: TextStyle(color: AppColors.disabled, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget Legenda Grafik (Penanda Warna)
class LegendBox extends StatelessWidget {
  final bool isKeuangan;
  const LegendBox({super.key, required this.isKeuangan});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _LegendItem(
        label: isKeuangan ? "Uang Masuk" : "Barang Masuk",
        color: AppColors.success,
      ),
      const SizedBox(width: 24),
      _LegendItem(
        label: isKeuangan ? "Uang Keluar" : "Barang Keluar",
        color: AppColors.error,
      ),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

/// Kontainer Utama Grafik (Line Chart)
class ChartContainer extends StatelessWidget {
  final List<FlSpot> spot1;
  final List<FlSpot> spot2;
  final double max;
  final bool isKeuangan;
  final DateTime startDate;

  const ChartContainer({
    super.key,
    required this.spot1,
    required this.spot2,
    required this.max,
    required this.isKeuangan,
    required this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    // Jika tidak ada data, tampilkan NoDataState
    if (spot1.isEmpty && spot2.isEmpty) {
      return const NoDataState(height: 300);
    }

    // Validasi max
    double safeMax = _safeMax(max);
    double interval = _calculateInterval(safeMax);

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(5, 10, 20, 10),
      decoration: AppStyles.cardOutline,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.primary.withValues(alpha: 0.9),
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) => LineTooltipItem(
                isKeuangan
                    ? AppStyles.formatCurrency(s.y)
                    : "${AppStyles.formatNumber(s.y)} Unit",
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              )).toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: interval,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (val) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
            ),
          ),
          titlesData: _titles(isKeuangan, startDate, safeMax),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _lineData(spot1, AppColors.primary),
            _lineData(spot2, AppColors.success),
          ],
          minY: 0,
          maxY: safeMax,
        ),
      ),
    );
  }

  double _safeMax(double value) {
    if (value.isNaN || value.isInfinite) return 10.0;
    if (value <= 0) return 10.0; // Minimal 10
    return value * 1.1; // Tambah 10% untuk padding atas
  }

  double _calculateInterval(double max) {
    double interval = (max / 4).ceilToDouble();
    if (interval <= 0) interval = 1;
    return interval;
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.35,
    color: color,
    barWidth: 3,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: true),
    belowBarData: BarAreaData(
      show: true,
      color: color.withValues(alpha: 0.1),
    ),
  );

  FlTitlesData _titles(bool isCurr, DateTime start, double maxVal) => FlTitlesData(
    rightTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    ),
    topTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (val, meta) => SideTitleWidget(
          meta: meta,
          space: 8.0,
          child: Text(
            _formatDateLabel(start, val.toInt()),
            style: AppStyles.chartLabel,
          ),
        ),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 80,
        getTitlesWidget: (val, meta) => SideTitleWidget(
          meta: meta,
          space: 8.0,
          child: Text(
            isCurr
                ? NumberFormat.compactCurrency(symbol: 'Rp', locale: 'id').format(val)
                : AppStyles.formatNumber(val),
            style: AppStyles.chartLabel,
          ),
        ),
      ),
    ),
  );

  String _formatDateLabel(DateTime start, int dayOffset) {
    try {
      final date = start.add(Duration(days: dayOffset));
      return DateFormat('dd/MM').format(date);
    } catch (_) {
      return '--/--';
    }
  }
}
