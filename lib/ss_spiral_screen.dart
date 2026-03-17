import 'dart:convert';
import 'dart:math';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/special_services_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/print_service_header.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:office_teschi/widgets/payment_modal.dart';

void main() => runApp(const anillado());

class anillado extends StatelessWidget {
  const anillado({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SpiralScreen(),
    );
  }
}

class SpiralScreen extends StatefulWidget {
  const SpiralScreen({super.key});

  @override
  State<SpiralScreen> createState() => _SpiralScreenState();
}

class _SpiralScreenState extends State<SpiralScreen> {
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _totalSheetsController =
      TextEditingController(text: '--');
  final TextEditingController _observationsController = TextEditingController();

  bool _uploadLoading = false;
  bool _priceLoading = false;
  bool _allPages = true;
  bool _bothSides = false;

  int _quantity = 1;
  int _printType = 0;
  int _selectedUploadIndex = -1;

  String _paperSize = 'Carta';
  String _ringType = 'stapled';

  static const List<Map<String, String>> _ringTypeOptions = [
    {'value': 'stapled', 'label': 'Engrapado'},
    {'value': 'glued', 'label': 'Encolado'},
    {'value': 'sewn', 'label': 'Cosido'},
  ];

  DateTime _deliveryDate = _nextBusinessDay();

  double _totalPrice = 0;
  List<Map<String, dynamic>> _uploads = [];
  Map<String, dynamic>? _priceData;

  @override
  void dispose() {
    _rangeController.dispose();
    _totalSheetsController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  static DateTime _nextBusinessDay() {
    var date = DateTime.now().add(const Duration(days: 1));
    while (
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day);
  }

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

  Future<List<dynamic>> _uploadToFileManager(List<PlatformFile> files) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/file-manager?service=document');
    final request = http.MultipartRequest('POST', uri);
    final token = _resolveToken();

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = '*/*';

    final username = (UserSession.token != null && UserSession.user != null)
        ? (UserSession.username?.trim().isNotEmpty == true
            ? UserSession.username!.trim()
            : 'undefined')
        : 'undefined';
    request.fields['username'] = username;

    for (final file in files) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      String message =
          'Error al subir archivo (${streamedResponse.statusCode}).';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          message = decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              message;
        }
      } catch (_) {
        if (body.trim().isNotEmpty) {
          message = body;
        }
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map && decoded['data'] is List) {
      return List<dynamic>.from(decoded['data']);
    }
    throw Exception('Respuesta inválida en /file-manager.');
  }

  Future<Map<String, dynamic>> _registerUploadedFiles(
      List<dynamic> responseList) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/files');
    final token = _resolveToken();

    final normalizedResList = responseList
        .whereType<Map>()
        .map((raw) => {
              'filename': raw['originalName']?.toString() ??
                  raw['filename']?.toString() ??
                  '',
              'filehash': raw['storedName']?.toString() ??
                  raw['filehash']?.toString() ??
                  '',
              'type': 'document',
            })
        .where((item) =>
            item['filename']!.isNotEmpty && item['filehash']!.isNotEmpty)
        .toList();

    if (normalizedResList.isEmpty) {
      throw Exception('No se pudo registrar el archivo subido.');
    }

    final firstFile = normalizedResList.first;
    final payload = {
      'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
      'resList': normalizedResList,
      'files': normalizedResList,
      'file': firstFile,
      'filename': firstFile['filename'],
      'filehash': firstFile['filehash'],
      'type': 'document',
    };

    final response = await http.post(
      uri,
      headers: {
        'Accept': '*/*',
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final body = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Error registrando archivo (${response.statusCode}).';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          message = decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              message;
        }
      } catch (_) {
        if (body.trim().isNotEmpty) {
          message = body;
        }
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractSavedFiles(
    Map<String, dynamic> registerResponse,
    List<dynamic> responseList,
  ) {
    int extractIdFile(dynamic source) {
      if (source is! Map) return 0;
      final map = source.map((k, v) => MapEntry(k.toString(), v));
      final direct = int.tryParse(
            (map['id_file'] ?? map['idFile'] ?? map['id'])?.toString() ?? '',
          ) ??
          0;
      if (direct > 0) return direct;

      final nestedFile = map['file'];
      if (nestedFile is Map) {
        final nested = int.tryParse(
              (nestedFile['id_file'] ??
                          nestedFile['idFile'] ??
                          nestedFile['id'])
                      ?.toString() ??
                  '',
            ) ??
            0;
        if (nested > 0) return nested;
      }

      return 0;
    }

    List<int> extractIdsFromRegisterResponse(Map<String, dynamic> source) {
      final ids = <int>[];

      void addId(dynamic value) {
        final parsed = int.tryParse(value?.toString() ?? '') ?? 0;
        if (parsed > 0 && !ids.contains(parsed)) {
          ids.add(parsed);
        }
      }

      addId(source['id_file']);
      addId(source['id']);

      final topData = source['data'];
      if (topData is Map) {
        addId(topData['id_file']);
        addId(topData['id']);
        final topDataFile = topData['file'];
        if (topDataFile is Map) {
          addId(topDataFile['id_file']);
          addId(topDataFile['id']);
        }
      }

      final topFile = source['file'];
      if (topFile is Map) {
        addId(topFile['id_file']);
        addId(topFile['id']);
      }

      final topItems = source['items'];
      if (topItems is List) {
        for (final item in topItems) {
          if (item is! Map) continue;
          addId(item['id_file']);
          addId(item['id']);
          final itemData = item['data'];
          if (itemData is Map) {
            addId(itemData['id_file']);
            addId(itemData['id']);
            final itemFile = itemData['file'];
            if (itemFile is Map) {
              addId(itemFile['id_file']);
              addId(itemFile['id']);
            }
          }
          final itemFile = item['file'];
          if (itemFile is Map) {
            addId(itemFile['id_file']);
            addId(itemFile['id']);
          }
        }
      }

      return ids;
    }

    final items = registerResponse['items'];
    if (items is List && items.isNotEmpty) {
      return items
          .map((item) {
            if (item is! Map) return null;
            final data = item['data'];
            if (data is Map) {
              final file = data['file'];
              if (file is Map) {
                final normalized =
                    file.map((key, value) => MapEntry(key.toString(), value));
                final idFile = extractIdFile(data);
                if (idFile > 0) {
                  normalized['id_file'] = idFile.toString();
                }
                return normalized;
              }
              final normalized =
                  data.map((key, value) => MapEntry(key.toString(), value));
              final idFile = extractIdFile(data);
              if (idFile > 0) {
                normalized['id_file'] = idFile.toString();
              }
              return normalized;
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    final fallbackSaved = responseList
        .whereType<Map>()
        .map((raw) => {
              'filename': raw['originalName']?.toString() ??
                  raw['filename']?.toString() ??
                  'archivo.pdf',
              'type': raw['service']?.toString() ?? 'document',
              'filehash': raw['storedName']?.toString() ??
                  raw['filehash']?.toString() ??
                  raw['filename']?.toString(),
            })
        .toList();

    final registerIds = extractIdsFromRegisterResponse(registerResponse);
    for (var i = 0; i < fallbackSaved.length; i++) {
      if (i < registerIds.length) {
        fallbackSaved[i]['id_file'] = registerIds[i].toString();
      }
    }

    if (registerIds.length == 1 && fallbackSaved.length > 1) {
      for (final item in fallbackSaved) {
        item['id_file'] = registerIds.first.toString();
      }
    }

    return fallbackSaved;
  }

  Map<String, dynamic>? _normalizePriceData(dynamic data) {
    if (data == null) return null;

    if (data is List) {
      double totalPrice = 0;
      int pages = 0;
      int sheets = 0;
      int sets = 0;
      final Map<String, double> breakdownPerSet = {};
      final Map<String, double> breakdownTotal = {};

      for (final item in data) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));

        totalPrice += double.tryParse('${map['totalPrice'] ?? 0}') ?? 0;
        pages += int.tryParse('${map['pages'] ?? 0}') ?? 0;
        sheets += int.tryParse('${map['sheets'] ?? 0}') ?? 0;
        sets += int.tryParse('${map['sets'] ?? 0}') ?? 0;

        final perSet = map['breakdownPerSet'];
        if (perSet is Map) {
          perSet.forEach((key, value) {
            final parsed = double.tryParse('$value');
            if (parsed != null) {
              breakdownPerSet[key.toString()] =
                  (breakdownPerSet[key.toString()] ?? 0) + parsed;
            }
          });
        }

        final total = map['breakdownTotal'];
        if (total is Map) {
          total.forEach((key, value) {
            final parsed = double.tryParse('$value');
            if (parsed != null) {
              breakdownTotal[key.toString()] =
                  (breakdownTotal[key.toString()] ?? 0) + parsed;
            }
          });
        }
      }

      return {
        'totalPrice': totalPrice,
        'pages': pages,
        'sheets': sheets,
        'sets': sets,
        'breakdownPerSet': breakdownPerSet.isEmpty ? null : breakdownPerSet,
        'breakdownTotal': breakdownTotal.isEmpty ? null : breakdownTotal,
      };
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  Map<String, dynamic>? _selectedUpload() {
    if (_uploads.isEmpty) return null;
    if (_selectedUploadIndex >= 0 && _selectedUploadIndex < _uploads.length) {
      return _uploads[_selectedUploadIndex];
    }
    return _uploads.first;
  }

  List<int> _collectFileIdsFromUploads() {
    final ids = <int>[];
    for (final upload in _uploads) {
      final raw = upload['id_file'] ?? upload['idFile'] ?? upload['id'];
      final id = int.tryParse(raw?.toString() ?? '') ?? 0;
      if (id > 0) ids.add(id);
    }
    return ids;
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _openPaymentModal() async {
    if (_totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero calcula el precio del pedido.')),
      );
      return;
    }

    final fileIds = _collectFileIdsFromUploads();

    await PaymentModal.open(
      context,
      amount: _totalPrice,
      serviceContext: {
        'lastUpload': _selectedUpload(),
        'uploads': _uploads,
        'id_file': fileIds.isNotEmpty ? fileIds.first : null,
        'id_files': fileIds,
        'printType': _printType == 1 ? 'color' : 'bw',
        'paperSize': _paperSize.toLowerCase(),
        'rangeValue': _allPages ? 'all' : _rangeController.text.trim(),
        'bothSides': _bothSides,
        'quantity': _quantity,
        'totalSheets': _totalSheetsController.text.trim(),
        'deliveryDate': _formatDate(_deliveryDate),
        'observations': _observationsController.text.trim(),
        'ringType': _ringTypeApiValue(),
        'spiralType': _ringTypeApiValue(),
        'breakdownTotal': _priceData?['breakdownTotal'],
        'price': _totalPrice,
      },
    );
  }

  String _uploadDisplayName(Map<String, dynamic> file) {
    final filename = file['filename']?.toString().trim();
    if (filename != null && filename.isNotEmpty) {
      return filename;
    }
    final fallback =
        (file['originalName'] ?? file['storedName'] ?? file['filehash'])
            ?.toString()
            .trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return 'archivo.pdf';
  }

  String? _buildPreviewUrl() {
    final file = _selectedUpload();
    if (file == null) return null;

    final filehash =
        (file['filehash'] ?? file['storedName'] ?? file['filename'])
            ?.toString();
    if (filehash == null || filehash.isEmpty) return null;

    final type = (file['type'] ?? file['service'] ?? 'document').toString();
    return '${AppConfig.apiUrl}/file-manager/download/$type/$filehash';
  }

  String _ringTypeApiValue() => _ringType;

  String _ringTypeLabel(String value) {
    for (final option in _ringTypeOptions) {
      if (option['value'] == value) {
        return option['label']!;
      }
    }
    return value;
  }

  Future<void> _removeUploadAt(int index) async {
    if (index < 0 || index >= _uploads.length) return;

    final updatedUploads = List<Map<String, dynamic>>.from(_uploads)
      ..removeAt(index);

    int nextSelectedIndex = -1;
    if (updatedUploads.isNotEmpty) {
      if (_selectedUploadIndex == index) {
        nextSelectedIndex = min(index, updatedUploads.length - 1);
      } else if (_selectedUploadIndex > index) {
        nextSelectedIndex = _selectedUploadIndex - 1;
      } else {
        nextSelectedIndex = _selectedUploadIndex;
      }
    }

    if (!mounted) return;
    setState(() {
      _uploads = updatedUploads;
      _selectedUploadIndex = nextSelectedIndex;
      if (updatedUploads.isEmpty) {
        _priceData = null;
        _totalPrice = 0;
        _totalSheetsController.text = '--';
      }
    });

    if (updatedUploads.isNotEmpty) {
      await _calculatePriceApi(uploads: updatedUploads);
    }
  }

  Future<void> _calculatePriceApi({List<Map<String, dynamic>>? uploads}) async {
    final uploadInfo = uploads ?? _uploads;
    if (uploadInfo.isEmpty) return;

    final filesPayload = uploadInfo
        .map((u) => {
              'filename': u['filehash']?.toString() ??
                  u['storedName']?.toString() ??
                  u['filename']?.toString(),
              'service': u['type']?.toString() ??
                  u['service']?.toString() ??
                  'document',
            })
        .where((u) => u['filename'] != null && u['filename']!.isNotEmpty)
        .toList();

    if (filesPayload.isEmpty) return;

    setState(() {
      _priceLoading = true;
    });

    try {
      final token = _resolveToken();
      final sets = max(1, _quantity);

      final payload = {
        'filename': filesPayload.length > 1
            ? filesPayload.map((f) => f['filename']).toList()
            : filesPayload.first['filename'],
        'service': filesPayload.first['service'] ?? 'document',
        'colorModes': _printType == 1 ? 'color' : 'bw',
        'paperSizes': _paperSize.toLowerCase(),
        'ranges': _allPages
            ? 'all'
            : (_rangeController.text.trim().isEmpty
                ? 'all'
                : _rangeController.text.trim()),
        'bothSides': _bothSides,
        'sets': sets,
        'type': 'spiral',
        'ringType': _ringTypeApiValue(),
      };

      final endpoints = ['/price-printing', '/printing-price'];
      http.Response? response;
      dynamic decoded;
      Object? lastError;

      for (final endpoint in endpoints) {
        final uri = Uri.parse('${AppConfig.apiUrl}$endpoint');
        try {
          final res = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': '*/*',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          );

          final parsed =
              res.body.isNotEmpty ? jsonDecode(res.body) : <String, dynamic>{};

          if (res.statusCode >= 200 && res.statusCode < 300) {
            response = res;
            decoded = parsed;
            break;
          }

          lastError = (parsed is Map
                  ? parsed['error']?.toString() ?? parsed['message']?.toString()
                  : null) ??
              'Error calculando precio (${res.statusCode}).';
        } catch (e) {
          lastError = e;
        }
      }

      if (response == null) {
        throw Exception(
            lastError?.toString() ?? 'No se pudo calcular el precio.');
      }

      final normalized = _normalizePriceData(decoded);
      final total = double.tryParse('${normalized?['totalPrice'] ?? 0}') ?? 0;
      final sheets = int.tryParse('${normalized?['sheets'] ?? ''}');

      if (!mounted) return;
      setState(() {
        _totalPrice = total;
        _priceData = normalized;
        if (sheets != null && sheets > 0) {
          _totalSheetsController.text = sheets.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _totalPrice = 0;
        _priceData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _priceLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _uploadLoading = true;
    });

    try {
      final uploadResponse = await _uploadToFileManager(result.files);
      final registerResponse = await _registerUploadedFiles(uploadResponse);
      final savedFiles = _extractSavedFiles(registerResponse, uploadResponse);

      if (!mounted) return;
      final mergedUploads = [..._uploads, ...savedFiles];
      final firstNewIndex = _uploads.length;

      setState(() {
        _uploads = mergedUploads;
        _selectedUploadIndex = firstNewIndex;
      });

      await _calculatePriceApi(uploads: mergedUploads);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() {
        _uploadLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 60, color: Colors.black),
                      const SizedBox(height: 10),
                      const Text(
                        'Error al subir el archivo',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Aceptar',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDeliveryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: _nextBusinessDay(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        return date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday;
      },
    );

    if (date == null) return;
    setState(() {
      _deliveryDate = DateTime(date.year, date.month, date.day);
    });
  }

  void _showPreview() {
    final previewUrl = _buildPreviewUrl();
    final token = _resolveToken();

    showDialog(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_red_eye, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Vista Previa',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  'Archivo: ${_selectedUpload() != null ? _uploadDisplayName(_selectedUpload()!) : 'Ninguno'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Total de hojas: ${_totalSheetsController.text}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.grey.shade100,
                      child: previewUrl == null
                          ? const Center(
                              child: Text(
                                'No hay un PDF cargado para previsualizar.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SfPdfViewer.network(
                              previewUrl,
                              headers: {
                                if (token != null)
                                  'Authorization': 'Bearer $token',
                              },
                              canShowScrollHead: true,
                              canShowScrollStatus: true,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _triggerPriceRecalculation() {
    if (_uploads.isNotEmpty) {
      _calculatePriceApi();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildUploadsList() {
    if (_uploads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Archivos cargados: ${_uploads.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _uploads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final file = _uploads[index];
            final isSelected = index == _selectedUploadIndex ||
                (_selectedUploadIndex < 0 && index == 0);
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _selectedUploadIndex = index;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE8F0FE)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1A73E8)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: isSelected
                          ? const Color(0xFF1A73E8)
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadDisplayName(file),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar archivo',
                      onPressed: () => _removeUploadAt(index),
                      icon: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPriceInfo() {
    final perSet = (_priceData?['breakdownPerSet'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        <String, dynamic>{};
    final total = (_priceData?['breakdownTotal'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        <String, dynamic>{};

    double parseNum(dynamic value) => double.tryParse('$value') ?? 0;

    final ringCost = parseNum(perSet['ringCost']);
    final ringCostTotal = parseNum(total['ringCost']);
    final inkCost = parseNum(perSet['inkCost']);
    final paperCost = parseNum(perSet['paperCost']);
    final inkTotal = parseNum(total['inkCost']);
    final paperTotal = parseNum(total['paperCost']);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Precios de anillado',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_priceData == null)
                const Text('Sube un archivo para calcular precio.')
              else ...[
                Text(
                  '${_ringTypeLabel(_ringType)}: \$ ${ringCost.toStringAsFixed(2)}',
                ),
                Text('Precio por juego: \$ ${ringCost.toStringAsFixed(2)}'),
                Text('Total anillado: \$ ${ringCostTotal.toStringAsFixed(2)}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cálculo de impresion',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_priceData == null)
                const Text('Sube un archivo para calcular precio.')
              else ...[
                Text('Tinta: \$ ${inkCost.toStringAsFixed(2)}'),
                Text('Papel: \$ ${paperCost.toStringAsFixed(2)}'),
                Text(
                  'Precio por juego: \$ ${(inkCost + paperCost).toStringAsFixed(2)}',
                ),
                Text(
                  'Total impresi\u00f3n: \$ ${(inkTotal + paperTotal).toStringAsFixed(2)}',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                PrintServiceHeader(
                  title: 'Anillado',
                  backgroundImage: 'assets/anillado.png',
                  onBackPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const servicioses(),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.description, color: Colors.white),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Subir archivo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.file_upload_outlined,
                              color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUploadsList(),
                      if (_uploads.isNotEmpty) const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Total de hojas'),
                                TextField(
                                  controller: _totalSheetsController,
                                  readOnly: true,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Tipo de Impresión'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RadioListTile<int>(
                          title: const Text('Impresión Blanco y Negro'),
                          value: 0,
                          groupValue: _printType,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _printType = v);
                            _triggerPriceRecalculation();
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RadioListTile<int>(
                          title: const Text('Impresión a Color'),
                          value: 1,
                          groupValue: _printType,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _printType = v);
                            _triggerPriceRecalculation();
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Tamano de Hoja'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _paperSize,
                            isExpanded: true,
                            items: ['Carta', 'Oficio', 'A4']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _paperSize = v);
                              _triggerPriceRecalculation();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Rango'),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _allPages,
                            onChanged: (v) {
                              setState(() {
                                _allPages = true;
                                _rangeController.clear();
                              });
                              _triggerPriceRecalculation();
                            },
                            activeColor: Colors.black,
                          ),
                          const Text('Todas', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            'Páginas',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _rangeController,
                              onTap: () {
                                if (_allPages) {
                                  setState(() => _allPages = false);
                                }
                              },
                              onChanged: (_) {
                                if (_allPages) {
                                  setState(() => _allPages = false);
                                }
                                _triggerPriceRecalculation();
                              },
                              decoration: InputDecoration(
                                hintText: '1,3-6',
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Cantidad de juegos'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cantidad:',
                                style: TextStyle(fontSize: 15)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_quantity > 1) _quantity--;
                                    });
                                    _triggerPriceRecalculation();
                                  },
                                  child: const Icon(Icons.remove, size: 22),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _quantity++;
                                    });
                                    _triggerPriceRecalculation();
                                  },
                                  child: const Icon(Icons.add, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Imprimir por'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<bool>(
                            value: _bothSides,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                  value: false, child: Text('Una cara')),
                              DropdownMenuItem(
                                  value: true, child: Text('Ambas caras')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _bothSides = v);
                              _triggerPriceRecalculation();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Tipo de anillado'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _ringType,
                            isExpanded: true,
                            items: _ringTypeOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e['value'],
                                    child: Text(e['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _ringType = v);
                              _triggerPriceRecalculation();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Observaciones'),
                      TextField(
                        controller: _observationsController,
                        minLines: 3,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Observaciones (opcional)',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Fecha de entrega'),
                      InkWell(
                        onTap: _pickDeliveryDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_deliveryDate.year.toString().padLeft(4, '0')}-${_deliveryDate.month.toString().padLeft(2, '0')}-${_deliveryDate.day.toString().padLeft(2, '0')}',
                              ),
                              const Icon(Icons.calendar_month),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sujeto a cambios sin previo aviso',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      _buildPriceInfo(),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Precio total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 35, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1E4FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              '\$ ${_totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showPreview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Vista previa',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _openPaymentModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9BDD66),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Aceptar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_uploadLoading || _priceLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _uploadLoading
                              ? 'Subiendo archivo...'
                              : 'Calculando precio...',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}
