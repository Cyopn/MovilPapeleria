import 'dart:convert';
import 'dart:typed_data';

import 'package:office_teschi/cart_provider.dart';
import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/main_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentModal extends StatefulWidget {
  const PaymentModal({
    super.key,
    required this.amount,
    this.serviceContext,
    this.cartItems,
    this.onPaymentSuccess,
  });

  final double amount;
  final Map<String, dynamic>? serviceContext;
  final List<CartItem>? cartItems;
  final VoidCallback? onPaymentSuccess;

  static Future<void> open(
    BuildContext context, {
    required double amount,
    Map<String, dynamic>? serviceContext,
    List<CartItem>? cartItems,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentModal(
        amount: amount,
        serviceContext: serviceContext,
        cartItems: cartItems,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  bool _processing = false;
  bool _downloadingQr = false;
  String _selectedMethod = 'cash';
  String? _error;
  String? _qrCode;
  int? _transactionId;

  String? _resolveToken() {
    final sessionToken = UserSession.token?.trim();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      return sessionToken;
    }

    final configToken = AppConfig.bearerToken.trim();
    if (configToken.isNotEmpty) {
      return configToken;
    }

    return null;
  }

  Map<String, String> _headers({bool json = true}) {
    final token = _resolveToken();
    return {
      if (json) 'Content-Type': 'application/json; charset=utf-8',
      'Accept': '*/*',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$endpoint');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message']?.toString() ?? decoded['error']?.toString())
          : null;
      throw Exception(
          message ?? 'Error en $endpoint (${response.statusCode}).');
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _extractProductId(Map<String, dynamic> response) {
    final direct = _safeInt(
      response['id_product'] ?? response['id'] ?? response['productId'],
      fallback: 0,
    );
    if (direct > 0) return direct;

    final data = response['data'];
    if (data is Map) {
      final nested = _safeInt(
        data['id_product'] ?? data['id'] ?? data['productId'],
        fallback: 0,
      );
      if (nested > 0) return nested;
    }

    final item = response['item'];
    if (item is Map) {
      final nested = _safeInt(
        item['id_product'] ?? item['id'] ?? item['productId'],
        fallback: 0,
      );
      if (nested > 0) return nested;
    }

    final items = response['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final first = Map<String, dynamic>.from(items.first as Map);
      final nested = _safeInt(
        first['id_product'] ?? first['id'] ?? first['productId'],
        fallback: 0,
      );
      if (nested > 0) return nested;
    }

    return 0;
  }

  double _safeDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _asFileHash(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return raw;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return raw;
  }

  String _serviceTypeFromContext(Map<String, dynamic> context) {
    if (context['photoPaper'] != null) return 'photo';
    if (context['boundType'] != null) return 'bound';
    if (context['docType'] != null) return 'docs';
    if (context['ringType'] != null) return 'spiral';
    return 'print';
  }

  Map<String, dynamic>? _filePayloadFromUpload(dynamic upload) {
    if (upload is! Map) return null;
    final filename =
        (upload['filehash'] ?? upload['storedName'] ?? upload['filename'])
            ?.toString();
    if (filename == null || filename.trim().isEmpty) return null;

    final service =
        (upload['type'] ?? upload['service'] ?? 'document').toString();
    return {
      'filename': _asFileHash(filename),
      'service': service,
    };
  }

  int _fileIdFromUpload(dynamic upload) {
    if (upload is! Map) return 0;

    final direct = _safeInt(
      upload['id_file'] ?? upload['idFile'] ?? upload['id'],
      fallback: 0,
    );
    if (direct > 0) return direct;

    final file = upload['file'];
    if (file is Map) {
      final nested = _safeInt(
        file['id_file'] ?? file['idFile'] ?? file['id'],
        fallback: 0,
      );
      if (nested > 0) return nested;
    }

    final data = upload['data'];
    if (data is Map) {
      final nested = _safeInt(
        data['id_file'] ?? data['idFile'] ?? data['id'],
        fallback: 0,
      );
      if (nested > 0) return nested;

      final dataFile = data['file'];
      if (dataFile is Map) {
        return _safeInt(
          dataFile['id_file'] ?? dataFile['idFile'] ?? dataFile['id'],
          fallback: 0,
        );
      }
    }

    return 0;
  }

  List<int> _fileIdsFromContext(Map<String, dynamic> context) {
    final ids = <int>[];

    final rawIdFiles = context['id_files'];
    debugPrint('[App] Contexto id_files: $rawIdFiles');
    if (rawIdFiles is List) {
      for (final value in rawIdFiles) {
        final parsed = _safeInt(value, fallback: 0);
        if (parsed > 0) ids.add(parsed);
      }
    }

    final directId = _safeInt(context['id_file'], fallback: 0);
    if (directId > 0 && !ids.contains(directId)) {
      ids.insert(0, directId);
    }

    if (ids.isNotEmpty) {
      return ids;
    }

    final rawUploads = context['uploads'];
    if (rawUploads is List) {
      for (final upload in rawUploads) {
        final id = _fileIdFromUpload(upload);
        if (id > 0) ids.add(id);
      }
    }

    if (ids.isEmpty) {
      final singleId = _fileIdFromUpload(context['lastUpload']);
      if (singleId > 0) ids.add(singleId);
    }

    return ids;
  }

  List<Map<String, dynamic>> _normalizeUploadsFromContext(
      Map<String, dynamic> context) {
    final rawUploads = context['uploads'];
    if (rawUploads is List) {
      final uploads = rawUploads
          .map(_filePayloadFromUpload)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (uploads.isNotEmpty) return uploads;
    }

    final single = _filePayloadFromUpload(context['lastUpload']);
    if (single != null) return [single];

    return [];
  }

  Future<int?> _createProductForService(Map<String, dynamic> context) async {
    final serviceType = _serviceTypeFromContext(context);
    final price = _safeDouble(context['price']);
    return _createServiceProduct(
      context: context,
      serviceType: serviceType,
      price: price,
    );
  }

  Future<int?> _createServiceProduct({
    required Map<String, dynamic> context,
    required String serviceType,
    required double price,
    int? idPrint,
  }) async {
    final files = _normalizeUploadsFromContext(context);
    final fileIds = _fileIdsFromContext(context);
    final idFile = fileIds.isNotEmpty ? fileIds.first : null;
    final quantity = _safeInt(context['quantity'], fallback: 1);

    final Map<String, dynamic> payload;

    if (serviceType == 'print') {
      payload = {
        'type': 'print',
        'description': 'Impresión de documentos',
        'price': price,
        'id_file': idFile,
        if (fileIds.isNotEmpty) 'id_files': fileIds,
        'amount': quantity > 0 ? quantity : 1,
        'type_print': (context['printType'] ?? 'bw').toString(),
        'type_paper': (context['typePaper'] ?? 'bond').toString(),
        'paper_size': (context['paperSize'] ?? 'carta').toString(),
        'range': (context['rangeValue'] ?? 'all').toString(),
        'both_sides': context['bothSides'] == true,
        'print_amount': quantity > 0 ? quantity : 1,
        'observations': (context['observations'] ?? '').toString(),
        'status': 'pending',
        'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
      };
    } else {
      String mapDescription(String type) {
        switch (type) {
          case 'bound':
            return 'special_service_bounding';
          case 'docs':
            return 'special_service_documents';
          case 'spiral':
            return 'special_service_spiral';
          case 'photo':
            return 'special_service_photo';
          default:
            return 'special_service_generic';
        }
      }

      String mapServiceType(String type) {
        switch (type) {
          case 'bound':
            return 'enc_imp';
          case 'docs':
            return 'doc_esp';
          case 'spiral':
            return 'ani_imp';
          case 'photo':
            return 'photo';
          default:
            return 'srv_imp';
        }
      }

      int? parseDeliveryEpoch(dynamic value) {
        final text = value?.toString().trim() ?? '';
        if (text.isEmpty) return null;
        final parsedInt = int.tryParse(text);
        if (parsedInt != null && parsedInt > 0) {
          return parsedInt;
        }
        final parsedDate = DateTime.tryParse(text);
        if (parsedDate != null) {
          return parsedDate.millisecondsSinceEpoch;
        }
        return null;
      }

      String? mapCoverType(dynamic raw) {
        final value = raw?.toString().trim().toLowerCase() ?? '';
        if (value.isEmpty) return null;
        if (value == 'dura' || value == 'hard') return 'hard';
        if (value == 'blanda' || value == 'soft') return 'soft';
        return value;
      }

      String? mapColor(dynamic raw) {
        final value = raw?.toString().trim().toLowerCase() ?? '';
        if (value.isEmpty) return null;
        switch (value) {
          case 'rojo':
            return 'red';
          case 'azul':
            return 'blue';
          case 'verde':
            return 'green';
          case 'negro':
            return 'black';
          case 'blanco':
            return 'white';
          default:
            return value;
        }
      }

      String? mapSpiralType(dynamic raw) {
        final value = raw?.toString().trim().toLowerCase() ?? '';
        if (value.isEmpty) return null;
        if (value.contains('glued') || value.contains('encol')) {
          return 'glued';
        }
        if (value.contains('sewn') || value.contains('cosid')) {
          return 'sewn';
        }
        if (value.contains('metal')) {
          return 'sewn';
        }
        if (value.contains('plastic') ||
            value.contains('plastico') ||
            value.contains('espiral') ||
            value.contains('stapled')) {
          return 'stapled';
        }
        return 'stapled';
      }

      final delivery = parseDeliveryEpoch(context['deliveryDate']);
      final coverType = mapCoverType(context['coverType']);
      final coverColor = mapColor(context['coverColor']);
      final spiralType = mapSpiralType(context['spiralType']) ??
          mapSpiralType(context['ringType']) ??
          (serviceType == 'spiral'
              ? 'plastic'
              : (context['boundType']?.toString() == 'espiral'
                  ? 'plastic'
                  : null));
      final documentType = context['docType']?.toString().trim().toLowerCase();
      final photoSize = serviceType == 'photo'
          ? context['paperSize']?.toString().trim()
          : null;
      final paperType = serviceType == 'photo'
          ? context['photoPaper']?.toString().trim()
          : null;

      payload = {
        'type': 'special_service',
        'description': mapDescription(serviceType),
        'price': price,
        'amount': quantity > 0 ? quantity : 1,
        'service_type': mapServiceType(serviceType),
        'mode': 'online',
        if (delivery != null) 'delivery': delivery,
        'observations': (context['observations'] ?? '').toString(),
        if (coverType != null) 'cover_type': coverType,
        if (coverColor != null) 'cover_color': coverColor,
        if (spiralType != null) 'spiral_type': spiralType,
        if (documentType != null && documentType.isNotEmpty)
          'document_type': documentType,
        if (photoSize != null && photoSize.isNotEmpty) 'photo_size': photoSize,
        if (paperType != null && paperType.isNotEmpty) 'paper_type': paperType,
        if ((idPrint ?? 0) > 0) 'id_print': idPrint,
        'status': 'pending',
        'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
        'id_file': idFile,
        if (fileIds.isNotEmpty) 'id_files': fileIds,
        if (files.isNotEmpty) 'files': files,
      };
    }

    final created = await _postJson('/products', payload);
    debugPrint('[App] Producto creado para servicio: $created');
    final id = _extractProductId(created);
    return id > 0 ? id : null;
  }

  double _round2(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  double _sumMapKeys(Map<String, dynamic> source, List<String> keys) {
    var total = 0.0;
    for (final key in keys) {
      total += _safeDouble(source[key]);
    }
    return total;
  }

  Map<String, double> _splitSpecialServiceAmounts(
    Map<String, dynamic> context,
    double total,
  ) {
    if (total <= 0) {
      return {'print': 0, 'special': 0};
    }

    final explicitPrint = _safeDouble(context['printPrice'], fallback: -1);
    final explicitSpecial =
        _safeDouble(context['specialServicePrice'], fallback: -1);
    if (explicitPrint >= 0 && explicitSpecial >= 0) {
      final printAmount = _round2(explicitPrint);
      final specialAmount = _round2(total - printAmount);
      return {
        'print': printAmount.clamp(0, total).toDouble(),
        'special': specialAmount.clamp(0, total).toDouble(),
      };
    }

    Map<String, dynamic> breakdown = const {};
    final rawBreakdown = context['breakdownTotal'];
    if (rawBreakdown is Map) {
      breakdown = rawBreakdown.map((key, value) => MapEntry('$key', value));
    }

    final printFromBreakdown = _sumMapKeys(
      breakdown,
      const ['inkCost', 'paperCost'],
    );
    final specialFromBreakdown = _sumMapKeys(
      breakdown,
      const [
        'ringCost',
        'docsCost',
        'coverCost',
        'bindingCost',
        'photoPaperCost'
      ],
    );

    if (printFromBreakdown > 0 || specialFromBreakdown > 0) {
      final sum = printFromBreakdown + specialFromBreakdown;
      if (sum > 0) {
        final printAmount = _round2(total * (printFromBreakdown / sum));
        final specialAmount = _round2(total - printAmount);
        return {
          'print': printAmount.clamp(0, total).toDouble(),
          'special': specialAmount.clamp(0, total).toDouble(),
        };
      }
    }

    final fallbackPrint = _round2(total * 0.5);
    final fallbackSpecial = _round2(total - fallbackPrint);
    return {
      'print': fallbackPrint,
      'special': fallbackSpecial,
    };
  }

  List<Map<String, dynamic>> _transactionDetailsFromCart(List<CartItem> items) {
    final details = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = _safeInt(item.id, fallback: 0);
      if (id > 0) {
        details.add({
          'id_product': id,
          'amount': item.quantity,
          'price': item.price,
        });
      }
    }
    return details;
  }

  Map<String, dynamic>? _transactionDetailFromService(
    Map<String, dynamic> context,
    int productId,
    double total,
  ) {
    if (productId <= 0) return null;

    final quantity = _safeInt(context['quantity'], fallback: 1);
    final price = _safeDouble(context['price'], fallback: total);

    return {
      'id_product': productId,
      'amount': quantity > 0 ? quantity : 1,
      'price': price,
    };
  }

  Map<String, dynamic>? _transactionDetailFromProduct(
    Map<String, dynamic> context,
    int productId,
    double price,
  ) {
    if (productId <= 0) return null;

    final quantity = _safeInt(context['quantity'], fallback: 1);
    return {
      'id_product': productId,
      'amount': quantity > 0 ? quantity : 1,
      'price': _round2(price),
    };
  }

  Future<void> _startPayment() async {
    if (_processing) return;

    final total = widget.amount;
    if (total <= 0) {
      setState(() {
        _error = 'El total debe ser mayor a 0 para generar la compra.';
      });
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final details = <Map<String, dynamic>>[];

      if (widget.cartItems != null && widget.cartItems!.isNotEmpty) {
        details.addAll(_transactionDetailsFromCart(widget.cartItems!));
      }

      if (widget.serviceContext != null) {
        final context = widget.serviceContext!;
        final serviceType = _serviceTypeFromContext(context);

        if (serviceType == 'print') {
          final productId = await _createProductForService(context);
          final serviceDetail = _transactionDetailFromService(
            context,
            productId ?? 0,
            total,
          );
          if (serviceDetail != null) {
            details.add(serviceDetail);
          }
        } else {
          final split = _splitSpecialServiceAmounts(context, total);
          final printPrice = split['print'] ?? 0;
          final specialPrice = split['special'] ?? 0;

          final printProductId = await _createServiceProduct(
            context: context,
            serviceType: 'print',
            price: printPrice,
          );
          final specialProductId = await _createServiceProduct(
            context: context,
            serviceType: serviceType,
            price: specialPrice,
            idPrint: printProductId,
          );

          final printDetail = _transactionDetailFromProduct(
            context,
            printProductId ?? 0,
            printPrice,
          );
          final specialDetail = _transactionDetailFromProduct(
            context,
            specialProductId ?? 0,
            specialPrice,
          );

          if (printDetail != null) {
            details.add(printDetail);
          }
          if (specialDetail != null) {
            details.add(specialDetail);
          }
        }
      }

      if (widget.serviceContext != null && details.isEmpty) {
        throw Exception(
          'No se pudo obtener id_product del producto creado para el servicio.',
        );
      }

      if (widget.serviceContext == null &&
          (widget.cartItems?.isNotEmpty ?? false) &&
          details.isEmpty) {
        throw Exception(
          'No se encontraron IDs de producto en el carrito para generar la transacción.',
        );
      }

      final isSpecialServiceFlow = widget.serviceContext != null &&
          _serviceTypeFromContext(widget.serviceContext!) != 'print';

      final payload = {
        'type': 'compra',
        'date': DateTime.now().toUtc().toIso8601String(),
        'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
        'status': 'pending',
        'payment_method': _selectedMethod,
        if (isSpecialServiceFlow) 'total': total,
        'details': details,
      };

      final transaction = await _postJson('/transactions', payload);
      final transactionId = _safeInt(
        transaction['id_transaction'] ??
            transaction['id'] ??
            transaction['transactionId'],
        fallback: 0,
      );
      final qrCode = transaction['qr_code']?.toString();

      if (!mounted) return;
      setState(() {
        _transactionId = transactionId > 0 ? transactionId : null;
        _qrCode = qrCode;
      });

      widget.onPaymentSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
    }
  }

  Widget _buildQrWidget(String qrValue) {
    if (qrValue.startsWith('data:image')) {
      final data = qrValue.split(',');
      if (data.length == 2) {
        try {
          final bytes = base64Decode(data[1]);
          return _qrImageFromBytes(bytes);
        } catch (_) {
          return const Text('No se pudo leer el QR generado.');
        }
      }
    }

    final uri = Uri.tryParse(qrValue);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        qrValue,
        width: 210,
        height: 210,
        fit: BoxFit.contain,
      );
    }

    return const Text('QR generado sin formato de imagen soportado.');
  }

  Widget _qrImageFromBytes(Uint8List bytes) {
    return Image.memory(
      bytes,
      width: 210,
      height: 210,
      fit: BoxFit.contain,
    );
  }

  Future<Uint8List> _qrBytesFromValue(String qrValue) async {
    if (qrValue.startsWith('data:image')) {
      final data = qrValue.split(',');
      if (data.length == 2) {
        return base64Decode(data[1]);
      }
    }

    final uri = Uri.tryParse(qrValue);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw Exception('No se pudo descargar la imagen QR.');
    }

    throw Exception('Formato de QR no soportado para descarga.');
  }

  Future<void> _downloadQr() async {
    if (_downloadingQr || _processing) return;
    final qrValue = _qrCode;
    final trxId = _transactionId;

    if (qrValue == null || qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay QR disponible para descargar.')),
      );
      return;
    }

    if (trxId == null || trxId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ID de transacción disponible.')),
      );
      return;
    }

    setState(() {
      _downloadingQr = true;
      _error = null;
    });

    try {
      final bytes = await _qrBytesFromValue(qrValue);
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar codigo QR',
        fileName: 'trx-$trxId.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );

      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR guardado: trx-$trxId.png')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _downloadingQr = false;
      });
    }
  }

  void _handleCloseAction() {
    final completed = _transactionId != null && _transactionId! > 0;

    if (completed) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const principal()),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasQr = _qrCode != null;
    final isPaypalSelected = _selectedMethod == 'paypal';
    final subtotal = _round2(widget.amount);
    final ivaValue = _round2(subtotal * 0.16);
    final importeValue = _round2(subtotal - ivaValue);
    final subtotalText = subtotal.toStringAsFixed(2);
    final ivaText = ivaValue.toStringAsFixed(2);
    final importeText = importeValue.toStringAsFixed(2);
    final initialInfoText = isPaypalSelected
        ? 'Se te redirigir\u00e1 a PayPal para completar el pago.\n'
            'Las impresiones se procesar\u00e1n una vez que se confirme el pago.\n'
            'Los pedidos se preparar\u00e1n una vez que se confirme el pago.'
        : 'Las impresiones se procesar\u00e1n una vez que se confirme el pago.\n'
            'Los pedidos se preparar\u00e1n una vez que se realice el pago en la tienda f\u00edsica.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            color: const Color(0xFFF0F0F0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: const Color(0xFFC4E28D),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gestion de pago',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: (_processing || _downloadingQr)
                              ? null
                              : _handleCloseAction,
                          icon: const Icon(Icons.close, color: Colors.black),
                          splashRadius: 18,
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            'Total: \$ $subtotalText MXN',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'Subtotal: \$ $importeText MXN',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'IVA (16%): \$ $ivaText MXN',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _processing
                                    ? null
                                    : () => setState(() {
                                          _selectedMethod = 'cash';
                                        }),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _selectedMethod == 'cash'
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFFF7F7F7),
                                  side: BorderSide(
                                    color: _selectedMethod == 'cash'
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFFBDBDBD),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: const Text(
                                  'Efectivo',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _processing
                                    ? null
                                    : () => setState(() {
                                          _selectedMethod = 'paypal';
                                        }),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _selectedMethod == 'paypal'
                                      ? const Color(0xFFE5E7EB)
                                      : const Color(0xFFF7F7F7),
                                  side: BorderSide(
                                    color: _selectedMethod == 'paypal'
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFBDBDBD),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                child: const Text(
                                  'PayPal',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (hasQr) ...[
                          const Center(
                            child: Text(
                              'Guarda el codigo QR para recoger tu pedido.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(child: _buildQrWidget(_qrCode!)),
                          const SizedBox(height: 10),
                          Center(
                            child: OutlinedButton(
                              onPressed: _downloadingQr ? null : _downloadQr,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide.none,
                                backgroundColor: const Color(0xFFD9E8FF),
                                minimumSize: const Size(170, 42),
                              ),
                              child: _downloadingQr
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Descargar QR'),
                            ),
                          ),
                          if (_transactionId != null) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                'Transacci\u00f3n #$_transactionId - COMPRA - \$${widget.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            initialInfoText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (hasQr)
                          const Text(
                            'Las impresiones se procesar\u00e1n una vez que se confirme el pago.\n'
                            'Los pedidos se preparar\u00e1n una vez que se realice el pago en la tienda f\u00edsica.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF374151),
                            ),
                          ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF81CFE7), Color(0xFF0E6FE6)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: (_processing || _downloadingQr)
                                ? null
                                : hasQr
                                    ? _handleCloseAction
                                    : _startPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _processing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    hasQr ? 'Cerrar' : 'Pagar',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
