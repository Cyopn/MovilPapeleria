import 'package:flutter/material.dart';
import 'widgets/dashboard_charts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF318BEF),
      ),
      body: const DashboardCharts(),
    );
  }
}
