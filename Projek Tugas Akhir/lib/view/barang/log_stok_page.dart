import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tugas_akhir/theme/app_styles.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';

class LogStokPage extends StatefulWidget {
  final int barangId;
  final String namaBarang;
  const LogStokPage({super.key, required this.barangId, required this.namaBarang});

  @override
  State<LogStokPage> createState() => _LogStokPageState();
}

class _LogStokPageState extends State<LogStokPage> {
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('log_stok', where: 'barang_id = ?', whereArgs: [widget.barangId], orderBy: 'tanggal DESC');
    setState(() => _logs = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Riwayat Stok: ${widget.namaBarang}', style: AppStyles.appBarTitle),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _logs.isEmpty
          ? const Center(child: Text("Belum ada riwayat perubahan stok"))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _logs.length,
              itemBuilder: (context, index) => _itemLog(_logs[index]),
            ),
    );
  }

  Widget _itemLog(Map<String, dynamic> log) {
    final double p = (log['perubahan'] as num?)?.toDouble() ?? 0;
    final bool isIn = p > 0;
    final double qtyAkhir = (log['qty_akhir'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        tileColor: AppColors.white,
        shape: AppStyles.selectionShape(false), // Menggunakan border style yang sama
        leading: CircleAvatar(
            backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(isIn ? Icons.add_business : Icons.assignment_return, color: isIn ? Colors.green : Colors.red)
        ),
        title: Text(log['alasan'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(DateFormat('dd MMM yyyy, HH:mm', 'id').format(DateTime.parse(log['tanggal'])), style: const TextStyle(fontSize: 11)),
        trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  isIn ? '+${_formatQty(p)}' : _formatQty(p),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isIn ? Colors.green : Colors.red)
              ),
              Text('Sisa: ${_formatQty(qtyAkhir)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]
        ),
      ),
    );
  }

  String _formatQty(double value) {
    if (value % 1 == 0) {
      return AppStyles.formatNumber(value.toInt());
    } else {
      return value.toStringAsFixed(value.toString().split('.')[1].length);
    }
  }
}
