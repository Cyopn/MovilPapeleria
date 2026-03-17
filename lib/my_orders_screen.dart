import 'dart:convert';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
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
  String _selectedMethod = 'Todos los metodos';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPendingOrders();
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

  Future<List<Map<String, dynamic>>> _getListFromPath(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: _headers(),
    );
    debugPrint("[App] GET ${AppConfig.apiUrl}$path -> ${response.statusCode}");
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error en $path (${response.statusCode})');
    }

    return _decodeList(response.body);
  }

  List<Map<String, dynamic>> _onlyPending(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase().trim();
      return status == 'pending' || status == 'pendiente';
    }).toList();
  }

  Future<void> _loadPendingOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = UserSession.idUser ?? AppConfig.defaultUserId;
    try {
      final path =
          '/transactions/user/${Uri.encodeComponent(userId.toString())}/details';
      final list = await _getListFromPath(path);
      final result = _onlyPending(list);

      if (!mounted) return;
      setState(() {
        _orders = result;
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

  String _formatDate(dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return 'Sin fecha';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final d = parsed.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _orderId(Map<String, dynamic> order) {
    return (order['id_transaction'] ?? order['id'] ?? 'N/A').toString();
  }

  String _paymentMethod(Map<String, dynamic> order) {
    final raw =
        (order['payment_method'] ?? order['paymentMethod'] ?? 'N/A').toString();
    final normalized = raw.toLowerCase().trim();
    return _paymentLabels[normalized] ?? raw;
  }

  String _total(Map<String, dynamic> order) {
    final value = order['total'] ?? order['amount'] ?? order['price'];
    if (value == null) return 'N/A';
    return '\$${value.toString()}';
  }

  String _statusText(Map<String, dynamic> order) {
    final raw = (order['status'] ?? 'pending').toString();
    final normalized = raw.toLowerCase().trim();
    return _statusLabels[normalized] ?? raw;
  }

  String _detailTypeLabel(Map<String, dynamic> detail) {
    final product = detail['product'];
    String? productTypeRaw;
    String? serviceTypeRaw;

    if (product is Map) {
      productTypeRaw =
          (product['type'] ?? product['product_type'] ?? product['productType'])
              ?.toString();
      serviceTypeRaw =
          (product['service_type'] ?? product['serviceType'])?.toString();
    }

    productTypeRaw ??=
        (detail['type'] ?? detail['product_type'] ?? detail['productType'])
            ?.toString();
    serviceTypeRaw ??= (detail['special_service'] ??
            detail['specialService'] ??
            detail['service_type'] ??
            detail['serviceType'])
        ?.toString();

    final productLabel =
        _productTypeLabels[(productTypeRaw ?? '').toLowerCase().trim()] ??
            (productTypeRaw?.trim().isNotEmpty == true
                ? productTypeRaw!
                : _productTypeLabels['item']!);

    final specialLabel =
        _specialServiceLabels[(serviceTypeRaw ?? '').toLowerCase().trim()];

    if (specialLabel != null) {
      return '$productLabel • $specialLabel';
    }
    return productLabel;
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
      final productName =
          (product['name'] ?? product['nombre'] ?? product['title'])
              ?.toString();
      if (productName != null && productName.trim().isNotEmpty) {
        return productName;
      }
    }

    final name = (detail['name'] ??
            detail['nombre'] ??
            detail['title'] ??
            detail['product_name'])
        ?.toString();
    if (name != null && name.trim().isNotEmpty) return name;

    final idProduct =
        (detail['id_product'] ?? detail['product_id'] ?? detail['id'])
            ?.toString();
    if (idProduct != null && idProduct.trim().isNotEmpty) {
      return 'Producto #$idProduct';
    }

    return 'Producto';
  }

  int _detailQty(Map<String, dynamic> detail) {
    return _asInt(detail['amount'] ?? detail['quantity'] ?? detail['qty'],
            fallback: 1)
        .clamp(1, 99999);
  }

  double _detailPrice(Map<String, dynamic> detail) {
    return _asDouble(
        detail['price'] ?? detail['total'] ?? detail['amount_total']);
  }

  String _money(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  List<String> _availableMethods() {
    final methods = _orders
        .map(_paymentMethod)
        .where((m) => m.trim().isNotEmpty && m != 'N/A')
        .toSet()
        .toList()
      ..sort();

    return ['Todos los metodos', ...methods];
  }

  bool _isWithinDateRange(Map<String, dynamic> order) {
    if (_fromDate == null && _toDate == null) return true;
    final raw = order['date']?.toString();
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

  bool _matchesSearch(Map<String, dynamic> order) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final idText = _orderId(order).toLowerCase();
    if (idText.contains(query)) return true;

    final details = _detailsForOrder(order);
    for (final d in details) {
      if (_detailName(d).toLowerCase().contains(query)) return true;
    }

    return false;
  }

  bool _matchesMethod(Map<String, dynamic> order) {
    if (_selectedMethod == 'Todos los metodos') return true;
    return _paymentMethod(order).toLowerCase() == _selectedMethod.toLowerCase();
  }

  List<Map<String, dynamic>> _filteredOrders() {
    return _orders.where((order) {
      return _matchesSearch(order) &&
          _matchesMethod(order) &&
          _isWithinDateRange(order);
    }).toList();
  }

  double _accumulatedTotal(List<Map<String, dynamic>> orders) {
    return orders.fold<double>(0, (sum, order) {
      final total =
          _asDouble(order['total'] ?? order['amount'] ?? order['price']);
      if (total > 0) return sum + total;

      final detailTotal =
          _detailsForOrder(order).fold<double>(0, (acc, detail) {
        final qty = _detailQty(detail).toDouble();
        final price = _detailPrice(detail);
        return acc + (qty * price);
      });

      return sum + detailTotal;
    });
  }

  String _formatDateShort(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedMethod = 'Todos los metodos';
      _fromDate = null;
      _toDate = null;
    });
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> filtered) {
    final totalOrders = filtered.length;
    final totalAccumulated = _accumulatedTotal(filtered);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total de pedidos',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  '$totalOrders',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total acumulado',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  _money(totalAccumulated),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final methods = _availableMethods();
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
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMethod,
                isExpanded: true,
                items: methods
                    .map((method) => DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMethod = value;
                  });
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
            const SizedBox(width: 8),
            Expanded(
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
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
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
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
    final details = _detailsForOrder(order);
    final id = _orderId(order);
    final status = _statusText(order);
    final payment = _paymentMethod(order);
    final totalText = _total(order);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pedido #$id',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7A6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(payment),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Fecha: ${_formatDate(order['date'])}')),
              Expanded(child: Text('Tipo: ${(order['type'] ?? 'compra')}')),
              Expanded(
                child: Text(
                  'Total: $totalText',
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
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
                    final typeLabel = _detailTypeLabel(detail);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(name)),
                              Text('${qty} x ${_money(price)}'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transaccion #$id - ${(order['type'] ?? 'COMPRA').toString().toUpperCase()} - $totalText - ${status.toString().toUpperCase()}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                onPressed: _loadPendingOrders,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredOrders = _filteredOrders();

    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          'No tienes pedidos pendientes',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    if (filteredOrders.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildFilters(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Sin resultados con los filtros aplicados',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildFilters();
        }
        if (index == 1) {
          return _buildSummaryCards(filteredOrders);
        }
        final order = filteredOrders[index - 2];
        return _buildOrderCard(order);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Mis pedidos',
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
