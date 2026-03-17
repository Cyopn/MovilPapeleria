import 'dart:convert';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HistorialPedidosScreen extends StatefulWidget {
  const HistorialPedidosScreen({super.key});

  @override
  State<HistorialPedidosScreen> createState() => _HistorialPedidosScreenState();
}

class _HistorialPedidosScreenState extends State<HistorialPedidosScreen> {
  static const Map<String, String> _statusLabels = {
    'pending': 'Pendiente',
    'completed': 'Completado',
  };

  static const Map<String, String> _paymentLabels = {
    'cash': 'Efectivo',
    'paypal': 'Paypal',
  };

  static const Map<String, String> _productTypeLabels = {
    'print': 'Impresion',
    'item': 'Articulo',
    'special_service': 'Servicio especial',
  };

  static const Map<String, String> _specialServiceLabels = {
    'enc_imp': 'Encuadernado',
    'doc_esp': 'Documento especial',
    'ani_imp': 'Anillado',
    'photo': 'Fotografia',
  };

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = const [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'Todos los estados';
  String _selectedMethod = 'Todos los metodos';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      if ((UserSession.token ?? '').isNotEmpty)
        'Authorization': 'Bearer ${UserSession.token}',
      if ((UserSession.token ?? '').isEmpty && AppConfig.bearerToken.isNotEmpty)
        'Authorization': 'Bearer ${AppConfig.bearerToken}',
    };
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    if (decoded is Map) {
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final dynamic candidates =
          map['data'] ?? map['items'] ?? map['transactions'] ?? map['rows'];
      if (candidates is List) {
        return candidates
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    }
    return const [];
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = UserSession.idUser ?? AppConfig.defaultUserId;

    try {
      final path =
          '/transactions/user/${Uri.encodeComponent(userId.toString())}/details';
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo obtener el historial de pedidos');
      }

      final list = _decodeList(response.body);
      if (!mounted) return;
      setState(() {
        _orders = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _statusRaw(Map<String, dynamic> order) {
    return (order['status'] ?? '').toString().toLowerCase().trim();
  }

  String _paymentRaw(Map<String, dynamic> order) {
    return (order['payment_method'] ?? order['paymentMethod'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
  }

  String _translateStatus(String? raw) {
    final key = (raw ?? '').toLowerCase().trim();
    if (key.isEmpty) return 'Sin estado';
    return _statusLabels[key] ?? raw!;
  }

  String _translatePayment(String? raw) {
    final key = (raw ?? '').toLowerCase().trim();
    if (key.isEmpty) return 'Sin metodo';
    return _paymentLabels[key] ?? raw!;
  }

  String _orderId(Map<String, dynamic> order) {
    return (order['id_transaction'] ?? order['id'] ?? 'N/A').toString();
  }

  String _monthEs(int month) {
    const names = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  String _formatDate(dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return '-';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return '-';
    final d = parsed.toLocal();
    final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final amPm = d.hour >= 12 ? 'p.m.' : 'a.m.';
    return '${d.day} ${_monthEs(d.month)} ${d.year}, ${hour12}:${d.minute.toString().padLeft(2, '0')} $amPm';
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  String _money(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _detailsForOrder(Map<String, dynamic> order) {
    final dynamic raw = order['details'] ?? order['detail'] ?? order['items'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  String _detailName(Map<String, dynamic> detail) {
    final product = detail['product'];
    if (product is Map) {
      final item = product['item'];
      if (item is Map) {
        final itemName = item['name']?.toString();
        if (itemName != null && itemName.trim().isNotEmpty) {
          return itemName;
        }
      }

      final description = product['description']?.toString();
      if (description != null && description.trim().isNotEmpty) {
        return description;
      }
    }

    final idProduct =
        (detail['id_product'] ?? detail['product_id'] ?? detail['id'])
            ?.toString();
    if (idProduct != null && idProduct.trim().isNotEmpty) {
      return 'Articulo #$idProduct';
    }

    return 'Articulo';
  }

  int _detailQty(Map<String, dynamic> detail) {
    return _asInt(detail['amount'] ?? detail['quantity'] ?? detail['qty'],
            fallback: 1)
        .clamp(1, 99999);
  }

  double _detailPrice(Map<String, dynamic> detail) {
    return _asDouble(
      detail['price'] ?? detail['total'] ?? detail['amount_total'],
    );
  }

  String _detailProductTypeLabel(Map<String, dynamic> detail) {
    final product = detail['product'];
    String? raw;
    if (product is Map) {
      raw =
          (product['type'] ?? product['product_type'] ?? product['productType'])
              ?.toString();
    }
    raw ??= (detail['type'] ?? detail['product_type'] ?? detail['productType'])
        ?.toString();

    final key = (raw ?? '').toLowerCase().trim();
    if (key.isEmpty) return 'Sin tipo';
    return _productTypeLabels[key] ?? raw!;
  }

  String? _detailSpecialServiceLabel(Map<String, dynamic> detail) {
    final product = detail['product'];
    String? rawType;

    if (product is Map) {
      final special = product['special_service'];
      if (special is Map) {
        rawType = special['type']?.toString();
      } else {
        rawType =
            (product['service_type'] ?? product['serviceType'])?.toString();
      }
    }

    rawType ??= (detail['service_type'] ?? detail['serviceType'])?.toString();

    final key = (rawType ?? '').toLowerCase().trim();
    if (key.isEmpty) return null;
    return _specialServiceLabels[key] ?? rawType;
  }

  List<String> _availableStatuses() {
    final values = _orders
        .map(_statusRaw)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todos los estados', ...values.map(_translateStatus)];
  }

  List<String> _availableMethods() {
    final values = _orders
        .map(_paymentRaw)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todos los metodos', ...values.map(_translatePayment)];
  }

  String _statusFromLabel(String label) {
    if (label == 'Todos los estados') return '';
    for (final e in _statusLabels.entries) {
      if (e.value.toLowerCase() == label.toLowerCase()) return e.key;
    }
    return label.toLowerCase().trim();
  }

  String _paymentFromLabel(String label) {
    if (label == 'Todos los metodos') return '';
    for (final e in _paymentLabels.entries) {
      if (e.value.toLowerCase() == label.toLowerCase()) return e.key;
    }
    return label.toLowerCase().trim();
  }

  bool _matchesSearch(Map<String, dynamic> order) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    if (_orderId(order).toLowerCase().contains(query)) return true;

    for (final detail in _detailsForOrder(order)) {
      if (_detailName(detail).toLowerCase().contains(query)) return true;
    }
    return false;
  }

  bool _matchesStatus(Map<String, dynamic> order) {
    final selectedRaw = _statusFromLabel(_selectedStatus);
    if (selectedRaw.isEmpty) return true;
    return _statusRaw(order) == selectedRaw;
  }

  bool _matchesPayment(Map<String, dynamic> order) {
    final selectedRaw = _paymentFromLabel(_selectedMethod);
    if (selectedRaw.isEmpty) return true;
    return _paymentRaw(order) == selectedRaw;
  }

  bool _isWithinDateRange(Map<String, dynamic> order) {
    if (_fromDate == null && _toDate == null) return true;
    final raw = (order['date'] ?? order['createdAt'])?.toString();
    if (raw == null || raw.isEmpty) return false;

    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return false;

    if (_fromDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      if (parsed.isBefore(from)) return false;
    }

    if (_toDate != null) {
      final to =
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      if (parsed.isAfter(to)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _filteredTransactions() {
    return _orders.where((order) {
      return _matchesSearch(order) &&
          _matchesStatus(order) &&
          _matchesPayment(order) &&
          _isWithinDateRange(order);
    }).toList();
  }

  ({int total, int pending, int completed, double amount}) _summary(
      List<Map<String, dynamic>> source) {
    final total = source.length;
    final pending = source.where((o) => _statusRaw(o) == 'pending').length;
    final completed = source.where((o) => _statusRaw(o) == 'completed').length;
    final amount = source.fold<double>(
      0,
      (acc, item) => acc + _asDouble(item['total'], fallback: 0),
    );

    return (
      total: total,
      pending: pending,
      completed: completed,
      amount: amount,
    );
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
        _toDate = _fromDate;
      }
    });
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    setState(() {
      _toDate = picked;
      if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
        _fromDate = _toDate;
      }
    });
  }

  String _formatDateShort(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'Todos los estados';
      _selectedMethod = 'Todos los metodos';
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });
  }

  Widget _summaryCard({
    required String title,
    required String value,
    Color valueColor = Colors.black87,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8FF)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = _availableStatuses();
    final methods = _availableMethods();

    if (!statuses.contains(_selectedStatus)) {
      _selectedStatus = 'Todos los estados';
    }
    if (!methods.contains(_selectedMethod)) {
      _selectedMethod = 'Todos los metodos';
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar por id o producto',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: statuses
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 15))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedStatus = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMethod,
                items: methods
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 15))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedMethod = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: InkWell(
                onTap: _pickFromDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    _fromDate == null ? 'Desde' : _formatDateShort(_fromDate),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: InkWell(
                onTap: _pickToDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    _toDate == null ? 'Hasta' : _formatDateShort(_toDate),
                  ),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _clearFilters,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = _orderId(order);
    final statusRaw = _statusRaw(order);
    final isCompleted = statusRaw == 'completed';
    final statusLabel = _translateStatus(statusRaw);
    final paymentLabel = _translatePayment(_paymentRaw(order));
    final dateLabel = _formatDate(order['date'] ?? order['createdAt']);
    final typeLabel = (order['type'] ?? '-').toString();
    final totalLabel = _money(_asDouble(order['total'], fallback: 0));
    final details = _detailsForOrder(order);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pedido',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      '#$id',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFCFF5E4)
                      : const Color(0xFFFFE7A6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF177A52)
                        : const Color(0xFF8A6200),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  paymentLabel,
                  style: const TextStyle(color: Color(0xFF2F5BC0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Fecha: $dateLabel')),
              Expanded(child: Text('Tipo: $typeLabel')),
              Expanded(
                child: Text(
                  'Total: $totalLabel',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4ECF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalle de productos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (details.isEmpty)
                  const Text('Sin detalle de productos')
                else
                  ...details.map((detail) {
                    final name = _detailName(detail);
                    final qty = _detailQty(detail);
                    final price = _detailPrice(detail);
                    final productTypeLabel = _detailProductTypeLabel(detail);
                    final specialServiceLabel =
                        _detailSpecialServiceLabel(detail);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEDEFF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text('$qty x ${_money(price)}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECEFF4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  productTypeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (specialServiceLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8DDFE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    specialServiceLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8B2FA8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadOrders,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          'Aun no tienes pedidos registrados.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final filtered = _filteredTransactions();
    final summary = _summary(filtered);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de pedidos',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Consulta el detalle de tus compras y su estado actual.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          );
        }
        if (index == 1) {
          return _buildFilters();
        }
        if (index == 2) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 30.0;
              final cardSize = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: _summaryCard(
                      title: 'Total de pedidos',
                      value: '${summary.total}',
                    ),
                  ),
                  SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: _summaryCard(
                      title: 'Pendientes',
                      value: '${summary.pending}',
                      valueColor: const Color(0xFFB7791F),
                    ),
                  ),
                  SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: _summaryCard(
                      title: 'Completados',
                      value: '${summary.completed}',
                      valueColor: const Color(0xFF15835C),
                    ),
                  ),
                  SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: _summaryCard(
                      title: 'Total acumulado',
                      value: _money(summary.amount),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return _buildOrderCard(filtered[index - 3]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Historial',
              showBackButton: true,
              onBackPressed: () => Navigator.pop(context),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
