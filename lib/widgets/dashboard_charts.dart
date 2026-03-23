import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/services/transaction_service.dart';

class _MetricBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MetricBox(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class DashboardCharts extends StatelessWidget {
  const DashboardCharts({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: TransactionService.fetchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final transactions = snapshot.data ?? [];
          final int totalTransacciones = transactions.length;
          double ingresosTotales = 0;
          int completadas = 0;
          int pendientes = 0;
          for (final tx in transactions) {
            ingresosTotales += double.tryParse(tx['total'].toString()) ?? 0.0;
            if ((tx['status'] ?? '').toString().toLowerCase() == 'completed') {
              completadas++;
            } else {
              pendientes++;
            }
          }

          final Map<String, double> ingresosPorFecha = {};
          for (final tx in transactions) {
            final date = DateTime.tryParse(tx['date'] ?? '') ?? DateTime(2000);
            final label =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
            final total = double.tryParse(tx['total'].toString()) ?? 0.0;
            ingresosPorFecha[label] = (ingresosPorFecha[label] ?? 0) + total;
          }
          final labelsFechas = ingresosPorFecha.keys.toList()
            ..sort((a, b) {
              final da = DateTime.parse(
                  '20${a.substring(6, 8)}-${a.substring(3, 5)}-${a.substring(0, 2)}');
              final db = DateTime.parse(
                  '20${b.substring(6, 8)}-${b.substring(3, 5)}-${b.substring(0, 2)}');
              return da.compareTo(db);
            });
          final ingresosPorDia =
              labelsFechas.map((f) => ingresosPorFecha[f]!).toList();
          final List<double> acumulado = [];
          double running = 0;
          for (final v in ingresosPorDia) {
            running += v;
            acumulado.add(running);
          }

          final Map<String, double> metodosPago = {};
          for (final tx in transactions) {
            final metodo = (tx['payment_method'] ?? 'Otro').toString();
            final total = double.tryParse(tx['total'].toString()) ?? 0.0;
            metodosPago[metodo] = (metodosPago[metodo] ?? 0) + total;
          }

          final Map<String, double> ventasPorCategoria = {};
          for (final tx in transactions) {
            if (tx['details'] is List) {
              for (final detail in tx['details']) {
                final product = detail['product'];
                if (product != null) {
                  String? categoria;
                  if (product['print'] != null) {
                    categoria = 'Impresión';
                  } else if (product['special_service'] != null) {
                    categoria = 'Servicio especial';
                  } else if (product['item'] != null &&
                      product['item']['category'] != null) {
                    categoria = product['item']['category'].toString();
                  } else if (product['category'] != null) {
                    categoria = product['category'].toString();
                  } else {
                    categoria = 'otros';
                  }
                  categoria =
                      categoria.toLowerCase().replaceAll('_', ' ').trim();
                  if (categoria == 'impresion' || categoria == 'impresión') {
                    categoria = 'Impresión';
                  } else if (categoria == 'servicio especial' ||
                      categoria == 'servicioespecial') {
                    categoria = 'Servicio especial';
                  } else if (categoria == 'oficina') {
                    categoria = 'Oficina';
                  } else if (categoria == 'papeleria' ||
                      categoria == 'papelería') {
                    categoria = 'Papeleria';
                  } else if (categoria == 'arte y diseño' ||
                      categoria == 'arte y diseno' ||
                      categoria == 'arte y diseño') {
                    categoria = 'Arte y diseño';
                  } else if (categoria == 'otros') {
                    categoria = 'Otros';
                  } else {
                    categoria = categoria
                        .split(' ')
                        .map((w) => w.isNotEmpty
                            ? w[0].toUpperCase() + w.substring(1)
                            : '')
                        .join(' ');
                  }
                  final total =
                      double.tryParse(detail['price'].toString()) ?? 0.0;
                  ventasPorCategoria[categoria] =
                      (ventasPorCategoria[categoria] ?? 0) + total;
                }
              }
            }
          }

          final Map<String, int> productosMasVendidos = {};
          for (final tx in transactions) {
            if (tx['details'] is List) {
              for (final detail in tx['details']) {
                final product = detail['product'];
                if (product != null) {
                  String? nombre;
                  if (product['item'] != null &&
                      product['item']['name'] != null) {
                    nombre = product['item']['name'].toString();
                  } else if (product['description'] != null) {
                    nombre = product['description'].toString();
                  } else {
                    nombre = 'Producto';
                  }
                  final cantidad =
                      int.tryParse(detail['amount'].toString()) ?? 1;
                  productosMasVendidos[nombre] =
                      (productosMasVendidos[nombre] ?? 0) + cantidad;
                }
              }
            }
          }

          final histogramRanges = ['20–50', '50–100', '100–300', '> 300'];
          final histogramCounts = [0, 0, 0, 0];
          for (final tx in transactions) {
            final total = double.tryParse(tx['total'].toString()) ?? 0.0;
            if (total < 20) continue;
            if (total < 50)
              histogramCounts[0]++;
            else if (total < 100)
              histogramCounts[1]++;
            else if (total < 300)
              histogramCounts[2]++;
            else
              histogramCounts[3]++;
          }

          final List<double> ticketPromedio = [];
          for (final f in labelsFechas) {
            final ingresos = ingresosPorFecha[f]!;
            final count = transactions.where((tx) {
              final date =
                  DateTime.tryParse(tx['date'] ?? '') ?? DateTime(2000);
              final label =
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
              return label == f;
            }).length;
            ticketPromedio.add(count > 0 ? ingresos / count : 0);
          }

          final List<double> ingresosPorHora = List.filled(24, 0.0);
          for (final tx in transactions) {
            final date = DateTime.tryParse(tx['date'] ?? '');
            if (date != null) {
              final total = double.tryParse(tx['total'].toString()) ?? 0.0;
              ingresosPorHora[date.hour] += total;
            }
          }

          final labelsDias = labelsFechas;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _MetricBox(
                          value: totalTransacciones.toString(),
                          label: 'Total de transacciones',
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _MetricBox(
                          value: ' 24${ingresosTotales.toStringAsFixed(2)}',
                          label: 'Ingresos totales',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _MetricBox(
                          value: completadas.toString(),
                          label: 'Completadas',
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _MetricBox(
                          value: pendientes.toString(),
                          label: 'Pendientes',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Ingresos por día',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                  ingresosPorDia.length,
                                  (i) =>
                                      FlSpot(i.toDouble(), ingresosPorDia[i])),
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 4,
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.15)),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  int maxLabels = 8;
                                  int step =
                                      (labelsFechas.length / maxLabels).ceil();
                                  if (idx >= 0 &&
                                      idx < labelsFechas.length &&
                                      (idx % step == 0 ||
                                          idx == labelsFechas.length - 1)) {
                                    return RotatedBox(
                                      quarterTurns: 1,
                                      child: Text(labelsFechas[idx],
                                          style: const TextStyle(fontSize: 10)),
                                    );
                                  } else {
                                    return const SizedBox();
                                  }
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true),
                          minY: -50),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Ingreso acumulado',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(acumulado.length,
                                (i) => FlSpot(i.toDouble(), acumulado[i])),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 4,
                            belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withOpacity(0.12)),
                            dotData: FlDotData(show: false),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 40),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                int maxLabels = 8;
                                int step =
                                    (labelsFechas.length / maxLabels).ceil();
                                if (idx >= 0 &&
                                    idx < labelsFechas.length &&
                                    (idx % step == 0 ||
                                        idx == labelsFechas.length - 1)) {
                                  return RotatedBox(
                                    quarterTurns: 1,
                                    child: Text(labelsFechas[idx],
                                        style: const TextStyle(fontSize: 10)),
                                  );
                                } else {
                                  return const SizedBox();
                                }
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Ticket promedio por día',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                  ticketPromedio.length,
                                  (i) =>
                                      FlSpot(i.toDouble(), ticketPromedio[i])),
                              isCurved: true,
                              color: Colors.purple,
                              barWidth: 4,
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.purple.withOpacity(0.12)),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  int maxLabels = 8;
                                  int step =
                                      (labelsDias.length / maxLabels).ceil();
                                  if (idx >= 0 &&
                                      idx < labelsDias.length &&
                                      (idx % step == 0 ||
                                          idx == labelsDias.length - 1)) {
                                    return RotatedBox(
                                      quarterTurns: 1,
                                      child: Text(labelsDias[idx],
                                          style: const TextStyle(fontSize: 10)),
                                    );
                                  } else {
                                    return const SizedBox();
                                  }
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true),
                          minY: -15),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Ingresos por hora del día',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                  ingresosPorHora.length,
                                  (i) =>
                                      FlSpot(i.toDouble(), ingresosPorHora[i])),
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 4,
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withOpacity(0.12)),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < 24) {
                                    return Text(
                                        '${idx.toString().padLeft(2, '0')}:00',
                                        style: const TextStyle(fontSize: 10));
                                  } else {
                                    return const SizedBox();
                                  }
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true),
                          minY: -80),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Distribución de métodos de pago',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: metodosPago.entries.map((e) {
                          final idx = metodosPago.keys.toList().indexOf(e.key);
                          final colors = [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.grey
                          ];
                          String displayName;
                          switch (e.key.toLowerCase()) {
                            case 'cash':
                              displayName = 'Efectivo';
                              break;
                            case 'credit_card':
                            case 'credit card':
                              displayName = 'Tarjeta de crédito';
                              break;
                            case 'paypal':
                              displayName = 'Paypal';
                              break;
                            default:
                              displayName = e.key[0].toUpperCase() +
                                  e.key.substring(1).replaceAll('_', ' ');
                          }
                          return PieChartSectionData(
                            color: colors[idx % colors.length],
                            value: e.value,
                            title: displayName,
                            radius: 60,
                            titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Ingresos por categoría',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: ventasPorCategoria.entries.map((e) {
                          final idx =
                              ventasPorCategoria.keys.toList().indexOf(e.key);
                          final colors = [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.grey,
                            Colors.pink,
                            Colors.teal,
                            Colors.brown
                          ];
                          String displayName;
                          switch (e.key.toLowerCase()) {
                            case 'oficina':
                              displayName = 'Oficina';
                              break;
                            case 'papeleria':
                              displayName = 'Papeleria';
                              break;
                            case 'otros':
                              displayName = 'Otros';
                              break;
                            case 'arte_y_diseño':
                            case 'arte_y_diseno':
                            case 'arte y diseño':
                            case 'arte y diseno':
                              displayName = 'Arte y diseño';
                              break;
                            default:
                              displayName = e.key[0].toUpperCase() +
                                  e.key.substring(1).replaceAll('_', ' ');
                          }
                          return PieChartSectionData(
                            color: colors[idx % colors.length],
                            value: e.value,
                            title: displayName,
                            radius: 60,
                            titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Productos más vendidos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: Builder(
                      builder: (context) {
                        final productosMasVendidosTop10 = Map.fromEntries(
                            (productosMasVendidos.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                                .take(10));
                        return BarChart(
                          BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barGroups: List.generate(
                                  productosMasVendidosTop10.length,
                                  (i) => BarChartGroupData(x: i, barRods: [
                                        BarChartRodData(
                                            toY: productosMasVendidosTop10
                                                .values
                                                .elementAt(i)
                                                .toDouble(),
                                            color: Colors.blueAccent,
                                            width: 18),
                                      ])),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true, reservedSize: 30),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    reservedSize: 100,
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      return idx >= 0 &&
                                              idx <
                                                  productosMasVendidosTop10
                                                      .length
                                          ? RotatedBox(
                                              quarterTurns: 1,
                                              child: Text(
                                                  productosMasVendidosTop10.keys
                                                      .elementAt(idx),
                                                  style: const TextStyle(
                                                      fontSize: 10)),
                                            )
                                          : const SizedBox();
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(show: true),
                              minY: -2),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Histograma de montos de compra',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: List.generate(
                            histogramCounts.length,
                            (i) => BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(
                                      toY: histogramCounts[i].toDouble(),
                                      color: Colors.purple,
                                      width: 18),
                                ])),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 30),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                return idx >= 0 && idx < histogramRanges.length
                                    ? Text(histogramRanges[idx])
                                    : const SizedBox();
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        );
  }
}
