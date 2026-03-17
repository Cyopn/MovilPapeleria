import 'dart:convert';
import 'dart:math';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/main_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/payment_modal.dart';
import 'package:office_teschi/widgets/print_service_header.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const impresiones());
}

class impresiones extends StatelessWidget {
  const impresiones({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImpresionesScreen(),
    );
  }
}

class ImpresionesScreen extends StatefulWidget {
  const ImpresionesScreen({super.key});

  @override
  State<ImpresionesScreen> createState() => _ImpresionesScreenState();
}

class _ImpresionesScreenState extends State<ImpresionesScreen> {
  // Variables existentes
  String tipoImpresion = 'BN';
  bool _uploadLoading = false;
  bool _priceLoading = false;
  List<Map<String, dynamic>> _uploads = [];
  int _selectedUploadIndex = -1;
  double _precioTotal = 0;
  Map<String, dynamic>? _priceData;

  // Variables para los campos visuales
  TextEditingController totalHojasController =
      TextEditingController(text: "--");
  TextEditingController rangoPaginasController = TextEditingController();
  int cantidad = 1;
  String tamanoHoja = 'Carta';
  String rango = 'Todas';
  String ambasCaras = 'Una cara';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    totalHojasController.dispose();
    rangoPaginasController.dispose();
    super.dispose();
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
            : 'undefinied')
        : 'undefinied';
    request.fields['username'] = username;

    debugPrint(
      '[Impresiones] file-manager request -> url=$uri username=$username files=${files.map((f) => f.name).toList()}',
    );

    for (final file in files) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'files',
          file.path!,
          filename: file.name,
        ));
      } else if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          file.bytes!,
          filename: file.name,
        ));
      } else {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    debugPrint(
      '[Impresiones] file-manager response <- status=${streamedResponse.statusCode} body=$body',
    );

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
      throw Exception(
          'No se pudo construir resList con filename/filehash desde file-manager.');
    }

    final firstFile = normalizedResList.first;

    final payload = {
      'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
      // Keep original contract
      'resList': normalizedResList,
      // Compatibility contracts used by some backends
      'files': normalizedResList,
      'file': firstFile,
      'filename': firstFile['filename'],
      'filehash': firstFile['filehash'],
      'type': 'document',
    };

    debugPrint(
        '[Impresiones] /file request -> url=$uri normalizedResList=$normalizedResList payload=$payload');

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
    debugPrint(
      '[Impresiones] /file response <- status=${response.statusCode} body=$body',
    );
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
                final idFile = extractIdFile(file);
                if (idFile > 0) {
                  normalized['id_file'] = idFile;
                }
                return normalized;
              }
              final normalized =
                  data.map((key, value) => MapEntry(key.toString(), value));
              final idFile = extractIdFile(data);
              if (idFile > 0) {
                normalized['id_file'] = idFile;
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
      int sheets = 0;
      int pages = 0;

      for (final item in data) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        final totalValue = double.tryParse('${map['totalPrice'] ?? 0}') ?? 0;
        final sheetsValue = int.tryParse('${map['sheets'] ?? 0}') ?? 0;
        final pagesValue = int.tryParse('${map['pages'] ?? 0}') ?? 0;
        totalPrice += totalValue;
        sheets += sheetsValue;
        pages += pagesValue;
      }

      return {
        'totalPrice': totalPrice,
        'sheets': sheets,
        'pages': pages,
      };
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  // ==========================================
  // DISEÑO 1: DIÁLOGO DE ERROR (ROJO)
  // ==========================================
  void _mostrarAlertaError() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor:
              Colors.transparent, // Fondo transparente para manejar bordes
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
                    color: Color(0xFFEF4444), // Rojo tipo alerta
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
                        "Error al subir el archivo!",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 10),
                        ),
                        child: const Text(
                          "Aceptar",
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

  // ==========================================
  // [NUEVO] DISEÑO 3: VISTA PREVIA FLOTANTE
  // ==========================================
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

  Future<void> _openPaymentModal() async {
    if (_precioTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero calcula el precio del pedido.')),
      );
      return;
    }

    final fileIds = _collectFileIdsFromUploads();

    await PaymentModal.open(
      context,
      amount: _precioTotal,
      serviceContext: {
        'lastUpload': _selectedUpload(),
        'uploads': _uploads,
        'id_file': fileIds.isNotEmpty ? fileIds.first : null,
        'id_files': fileIds,
        'printType': tipoImpresion == 'Color' ? 'color' : 'bw',
        'paperSize': tamanoHoja.toLowerCase(),
        'rangeValue':
            rango == 'Todas' ? 'all' : rangoPaginasController.text.trim(),
        'bothSides': ambasCaras != 'Una cara',
        'quantity': cantidad,
        'totalSheets': totalHojasController.text.trim(),
        'price': _precioTotal,
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
        _precioTotal = 0;
        totalHojasController.text = '--';
      }
    });

    if (updatedUploads.isNotEmpty) {
      await _calcularPrecioApi(uploads: updatedUploads);
    }
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

  void _mostrarVistaPrevia() {
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
                BoxShadow(color: Colors.black26, blurRadius: 10)
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
                    Text("Vista Previa",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const Divider(height: 30),
                Text(
                    "Archivo: ${_selectedUpload() != null ? _uploadDisplayName(_selectedUpload()!) : 'Ninguno'}",
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text("Total de hojas: ${totalHojasController.text}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LÓGICA DE SUBIDA ACTUALIZADA
  // ==========================================
  Future<void> _calcularPrecioApi({List<Map<String, dynamic>>? uploads}) async {
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
      final uri = Uri.parse('${AppConfig.apiUrl}/printing-price');
      final token = _resolveToken();
      final sets = max(1, cantidad);

      final payload = {
        'filename': filesPayload.length > 1
            ? filesPayload.map((f) => f['filename']).toList()
            : filesPayload.first['filename'],
        'service': filesPayload.first['service'] ?? 'document',
        'colorModes': tipoImpresion == 'Color' ? 'color' : 'bw',
        'paperSizes': tamanoHoja.toLowerCase(),
        'ranges': rango == 'Todas'
            ? 'all'
            : (rangoPaginasController.text.trim().isEmpty
                ? 'all'
                : rangoPaginasController.text.trim()),
        'bothSides': ambasCaras == 'Ambas caras',
        'type': 'document',
        'sets': sets,
      };

      debugPrint(
        '[Impresiones] /printing-price request -> url=$uri payload=$payload',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (token != null) 'Accept': '*/*',
        },
        body: jsonEncode(payload),
      );

      final dynamic decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      debugPrint(
        '[Impresiones] /printing-price response <- status=${response.statusCode} body=${response.body}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = (decoded is Map
                ? decoded['error']?.toString() ?? decoded['message']?.toString()
                : null) ??
            'Error calculando precio (${response.statusCode}).';
        throw Exception(errorMessage);
      }

      final normalized = _normalizePriceData(decoded);
      final total = double.tryParse('${normalized?['totalPrice'] ?? 0}') ?? 0;
      final pages = int.tryParse('${normalized?['pages'] ?? ''}');

      if (!mounted) return;
      setState(() {
        _precioTotal = total;
        _priceData = normalized;
        if (pages != null && pages > 0) {
          totalHojasController.text = pages.toString();
        }
      });
    } catch (e) {
      debugPrint('[Impresiones] Error en /printing-price: $e');
      if (!mounted) return;
      setState(() {
        _precioTotal = 0;
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

  Future<void> _subirArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      final selectedFiles = result.files;
      debugPrint(
        '[Impresiones] Seleccion de archivos -> total=${selectedFiles.length} files=${selectedFiles.map((f) => f.name).toList()}',
      );
      final uploadResponse = await _uploadToFileManager(selectedFiles);
      final registerResponse = await _registerUploadedFiles(uploadResponse);
      final savedFiles = _extractSavedFiles(registerResponse, uploadResponse);
      debugPrint(
        '[Impresiones] Archivos guardados -> total=${savedFiles.length} data=$savedFiles',
      );

      if (!mounted) return;
      final mergedUploads = [..._uploads, ...savedFiles];
      final firstNewIndex = _uploads.length;

      setState(() {
        _uploads = mergedUploads;
        _selectedUploadIndex = firstNewIndex;
      });

      await _calcularPrecioApi(uploads: mergedUploads);
      if (!mounted) return;
    } catch (e, st) {
      debugPrint('[Impresiones] Error durante subida/registro: $e');
      debugPrint('[Impresiones] StackTrace: $st');
      if (!mounted) return;
      _mostrarAlertaError();
    } finally {
      if (!mounted) return;
      setState(() {
        _uploadLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                PrintServiceHeader(
                  title: 'Impresiones',
                  backgroundImage: 'assets/impresiones.png',
                  onBackPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const principal()),
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BOTÓN SUBIR ARCHIVO
                      GestureDetector(
                        onTap: _subirArchivo,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007BFF),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.description,
                                  color: Colors.white),
                              const SizedBox(width: 10),
                              Flexible(
                                child: const Text(
                                  'Subir archivo',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.upload, color: Colors.white),
                            ],
                          ),
                        ),
                      ),

                      if (_uploads.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Archivos cargados: ${_uploads.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _uploads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
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
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar archivo',
                                      onPressed: () => _removeUploadAt(index),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // FILAS DE CONFIGURACIÓN
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cantidad de hojas',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: totalHojasController,
                                  readOnly: true,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Text('Tipo de Impresión',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          setState(() => tipoImpresion = 'BN');
                          if (_uploads.isNotEmpty) {
                            _calcularPrecioApi();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Radio(
                                  value: 'BN',
                                  groupValue: tipoImpresion,
                                  onChanged: (val) {
                                    setState(() => tipoImpresion = val!);
                                    if (_uploads.isNotEmpty) {
                                      _calcularPrecioApi();
                                    }
                                  },
                                  activeColor: Colors.black),
                              const Text('Impresión Blanco y Negro'),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => tipoImpresion = 'Color');
                          if (_uploads.isNotEmpty) {
                            _calcularPrecioApi();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Radio(
                                  value: 'Color',
                                  groupValue: tipoImpresion,
                                  onChanged: (val) {
                                    setState(() => tipoImpresion = val!);
                                    if (_uploads.isNotEmpty) {
                                      _calcularPrecioApi();
                                    }
                                  },
                                  activeColor: Colors.black),
                              const Text('Impresión a Color'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text('Tamaño de Hoja',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tamanoHoja,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items: ['Carta', 'Oficio', 'A4']
                                .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey))))
                                .toList(),
                            onChanged: (val) {
                              setState(() => tamanoHoja = val!);
                              if (_uploads.isNotEmpty) {
                                _calcularPrecioApi();
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text('Rango',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: [
                        Radio(
                            value: 'Todas',
                            groupValue: rango,
                            onChanged: (v) {
                              setState(() => rango = 'Todas');
                              if (_uploads.isNotEmpty) {
                                _calcularPrecioApi();
                              }
                            },
                            activeColor: Colors.black),
                        const Text('Todas')
                      ]),
                      Row(children: [
                        const Text('Páginas  ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: TextField(
                            controller: rangoPaginasController,
                            onTap: () {
                              if (rango != 'Páginas') {
                                setState(() => rango = 'Páginas');
                              }
                            },
                            onChanged: (_) {
                              if (rango != 'Páginas') {
                                setState(() => rango = 'Páginas');
                              }
                              if (_uploads.isNotEmpty) {
                                _calcularPrecioApi();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: '1,3-6',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        )
                      ]),

                      const SizedBox(height: 20),
                      const Text('Cantidad de juegos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Cantidad: ",
                                style: TextStyle(fontSize: 16)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (cantidad > 1) cantidad--;
                                    });
                                    if (_uploads.isNotEmpty) {
                                      _calcularPrecioApi();
                                    }
                                  },
                                  child: const Icon(Icons.remove, size: 24),
                                ),
                                const SizedBox(width: 4),
                                Text("$cantidad ",
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => cantidad++);
                                    if (_uploads.isNotEmpty) {
                                      _calcularPrecioApi();
                                    }
                                  },
                                  child: const Icon(Icons.add, size: 24),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text('Imprimir por:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ambasCaras,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items: ['Una cara', 'Ambas caras']
                                .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e,
                                        style: const TextStyle(
                                            color: Colors.grey))))
                                .toList(),
                            onChanged: (val) {
                              setState(() => ambasCaras = val!);
                              if (_uploads.isNotEmpty) {
                                _calcularPrecioApi();
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Precios',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                            const SizedBox(height: 5),
                            if (_priceData == null) ...const [
                              Text('Sube un archivo para calcular precio.',
                                  style: TextStyle(color: Colors.black87)),
                            ] else ...[
                              Text(
                                  'Tinta: \$ ${(double.tryParse('${_priceData?['breakdownPerSet']?['inkCost'] ?? 0}') ?? 0).toStringAsFixed(1)}',
                                  style:
                                      const TextStyle(color: Colors.black87)),
                              Text(
                                  'Papel: \$ ${(double.tryParse('${_priceData?['breakdownPerSet']?['paperCost'] ?? 0}') ?? 0).toStringAsFixed(1)}',
                                  style:
                                      const TextStyle(color: Colors.black87)),
                              Text(
                                  'Precio por juego: \$ ${(double.tryParse('${_priceData?['pricePerSet'] ?? 0}') ?? 0).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Precio total',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 8),
                            decoration: BoxDecoration(
                                color: const Color(0xFFD0E3FF),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: Colors.blue.shade200)),
                            child: Text('\$ ${_precioTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _mostrarVistaPrevia, // <--- AQUÍ ESTÁ EL ENLACE A VISTA PREVIA
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC107),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                              child: const Text('vista previa',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _openPaymentModal,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8BC34A),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                              child: const Text('Aceptar',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
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
