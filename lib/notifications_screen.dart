import 'dart:convert';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/main_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Map<String, String> _statusLabels = {
    'pending': 'Pendiente',
    'in_progress': 'En progreso',
    'completed': 'Completado',
  };

  bool _isLoading = true;
  bool _isTxLoading = false;
  String? _error;
  List<Map<String, dynamic>> _notifications = const [];
  Map<String, dynamic>? _selectedTx;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

  int? _userId() {
    final id = UserSession.idUser ?? AppConfig.defaultUserId;
    return id > 1 ? id : null;
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
      final data =
          map['data'] ?? map['items'] ?? map['notifications'] ?? map['rows'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    }

    return const [];
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    final userId = _userId();
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No hay sesion activa';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final path =
          '/notifications/user/${Uri.encodeComponent(userId.toString())}';
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudieron obtener notificaciones');
      }

      final list = _decodeList(response.body);
      if (!mounted) return;
      setState(() {
        _notifications = list;
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

  String _toDate(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return '-';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';

    final d = parsed.toLocal();
    final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final amPm = d.hour >= 12 ? 'p.m.' : 'a.m.';

    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${hour12}:${d.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _toMoney(dynamic value) {
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _translateStatus(dynamic status) {
    final key = (status ?? '').toString().toLowerCase().trim();
    if (key.isEmpty) return '-';
    return _statusLabels[key] ?? status.toString();
  }

  dynamic _metadataValue(Map<String, dynamic> notification, String key) {
    final metadata = notification['metadata'];
    if (metadata is Map) {
      return metadata[key] ??
          metadata[key.toLowerCase()] ??
          metadata[key.toUpperCase()];
    }
    return null;
  }

  Future<void> _markAsRead(dynamic notifId) async {
    if (notifId == null) return;

    try {
      final path =
          '/notifications/${Uri.encodeComponent(notifId.toString())}/read';
      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          _notifications = _notifications.map((n) {
            final id = n['id_notification'] ?? n['id'];
            if (id?.toString() == notifId.toString()) {
              return {
                ...n,
                'is_read': true,
              };
            }
            return n;
          }).toList();
        });
      }
    } catch (_) {
    }
  }

  List<Map<String, dynamic>> _txDetails(Map<String, dynamic> tx) {
    final dynamic details = tx['details'] ?? tx['items'];
    if (details is! List) return const [];

    return details
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  String _txDetailName(Map<String, dynamic> detail) {
    final product = detail['product'];
    if (product is Map) {
      final item = product['item'];
      if (item is Map) {
        final itemName = item['name']?.toString();
        if (itemName != null && itemName.trim().isNotEmpty) return itemName;
      }

      final description = product['description']?.toString();
      if (description != null && description.trim().isNotEmpty) {
        return description;
      }
    }

    return 'Producto #${detail['id_product'] ?? '-'}';
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final notifId = notification['id_notification'] ?? notification['id'];
    final idTx = _metadataValue(notification, 'id_transaction') ??
        notification['id_transaction'];

    _markAsRead(notifId);

    if (idTx == null || idTx.toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay transaccion asociada')),
      );
      return;
    }

    setState(() {
      _isTxLoading = true;
    });

    try {
      final path = '/transactions/${Uri.encodeComponent(idTx.toString())}';
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo obtener la transaccion');
      }

      final decoded = jsonDecode(response.body);
      final tx = decoded is Map
          ? decoded.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _selectedTx = tx;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e
              .toString()
              .replaceFirst('Exception: ', 'Error al obtener transaccion: ')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isTxLoading = false;
      });
    }
  }

  void _handleBackPressed() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const principal()),
    );
  }

  Widget _buildTxModal() {
    final tx = _selectedTx;
    if (tx == null) return const SizedBox.shrink();

    final id = (tx['id_transaction'] ?? tx['id'] ?? '-').toString();
    final status = _translateStatus(tx['status']);
    final date = _toDate(tx['date'] ?? tx['createdAt']);
    final total = _toMoney(tx['total']);
    final details = _txDetails(tx);

    void closeModal() {
      setState(() {
        _selectedTx = null;
      });
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: closeModal,
        child: Container(
          color: Colors.black45,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 640, maxHeight: 250),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Transaccion #$id',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: closeModal,
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Estado: $status'),
                          const SizedBox(height: 4),
                          Text('Fecha: $date'),
                          const SizedBox(height: 4),
                          Text('Total: $total'),
                          const SizedBox(height: 14),
                          const Text(
                            'Detalles',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: details.isEmpty
                                ? const Center(child: Text('Sin detalles'))
                                : ListView.separated(
                                    itemCount: details.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final d = details[index];
                                      final qty = d['amount'] ?? 0;
                                      final price = _toMoney(d['price']);
                                      final name = _txDetailName(d);

                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFE6EEF9)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                            Text('$qty x $price'),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _error!.trim().isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD3D3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Text(
          'No tienes notificaciones.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _notifications.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Lista de notificaciones recientes.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            final n = _notifications[index - 1];
            final isRead = n['is_read'] == true || n['isRead'] == true;
            final message = (n['message'] ?? '-').toString();
            final date = _toDate(n['createdAt'] ?? n['date']);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isTxLoading ? null : () => _openNotification(n),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD8E8FF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRead ? 'Leido' : 'Nuevo',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isRead ? Colors.black45 : const Color(0xFFB7791F),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isTxLoading)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        if (_selectedTx != null) _buildTxModal(),
      ],
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
              title: 'Notificaciones',
              showBackButton: true,
              onBackPressed: _handleBackPressed,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
