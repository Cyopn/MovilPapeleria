import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/special_services_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/print_service_header.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:office_teschi/widgets/payment_modal.dart';

void main() => runApp(const fotografia());

class fotografia extends StatelessWidget {
  const fotografia({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const PhotoPrintScreen(),
    );
  }
}

class PhotoPrintScreen extends StatefulWidget {
  const PhotoPrintScreen({super.key});

  @override
  State<PhotoPrintScreen> createState() => _PhotoPrintScreenState();
}

class _PhotoPrintScreenState extends State<PhotoPrintScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _observationsController = TextEditingController();

  File? _imageFile;
  double _rotationAngle = 0.0;
  double _cropZoom = 1.0;
  double _cropOffsetX = 0.0;
  double _cropOffsetY = 0.0;
  bool _uploadLoading = false;
  bool _priceLoading = false;

  int _quantity = 1;
  int _selectedType = 1;
  String _paperSize = 'Tamaño infantil (2.5x3cm)';
  String _photoPaper = 'Papel brillante';

  DateTime _deliveryDate = _nextBusinessDay();

  Map<String, dynamic>? _uploadedFile;
  Map<String, dynamic>? _priceData;
  double _totalPrice = 0;

  @override
  void dispose() {
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

  String _paperSizeApiValue() {
    switch (_paperSize) {
      case 'Tamaño carnet (4x4cm)':
        return 'tc';
      case 'Tamaño album pequeño (9x13cm)':
        return 'tap';
      default:
        return 'ti';
    }
  }

  String _paperTypeApiValue() {
    switch (_photoPaper) {
      case 'Papel mate':
        return 'mate';
      case 'Papel satinado':
        return 'satiny';
      default:
        return 'bright';
    }
  }

  double _currentTargetAspect() {
    switch (_paperSizeApiValue()) {
      case 'tc':
        return 1.0;
      case 'tap':
        return 9.0 / 13.0;
      default:
        return 2.5 / 3.0;
    }
  }

  Future<List<int>?> _generatePdfBytesFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('No se pudo leer la imagen seleccionada.');
    }

    final rotationDeg = ((_rotationAngle * 180 / pi).round()) % 360;
    final normalizedRotation =
        rotationDeg < 0 ? rotationDeg + 360 : rotationDeg;
    final rotated = normalizedRotation == 0
        ? decoded
        : img.copyRotate(decoded, angle: normalizedRotation.toDouble());

    const sizeMap = {
      'ti': {'w': 2.5, 'h': 3.0},
      'tc': {'w': 4.0, 'h': 4.0},
      'tap': {'w': 9.0, 'h': 13.0},
    };
    final paperKey = _paperSizeApiValue();
    final target = sizeMap[paperKey] ?? const {'w': 2.5, 'h': 3.0};
    final targetAspect = target['w']! / target['h']!;

    final srcAspect = rotated.width / rotated.height;
    int sx = 0;
    int sy = 0;
    int sw = rotated.width;
    int sh = rotated.height;

    if ((srcAspect - targetAspect).abs() > 0.001) {
      if (srcAspect > targetAspect) {
        sw = (rotated.height * targetAspect).round();
        sx = ((rotated.width - sw) / 2).round();
      } else {
        sh = (rotated.width / targetAspect).round();
        sy = ((rotated.height - sh) / 2).round();
      }
    }

    final zoom = _cropZoom < 1.0 ? 1.0 : _cropZoom;
    final zoomedW = max(1, (sw / zoom).round());
    final zoomedH = max(1, (sh / zoom).round());
    final maxDx = max(0.0, (sw - zoomedW) / 2);
    final maxDy = max(0.0, (sh - zoomedH) / 2);

    final centerX = sx + sw / 2 + (_cropOffsetX.clamp(-1.0, 1.0) * maxDx);
    final centerY = sy + sh / 2 + (_cropOffsetY.clamp(-1.0, 1.0) * maxDy);

    sx = (centerX - zoomedW / 2).round().clamp(0, rotated.width - 1);
    sy = (centerY - zoomedH / 2).round().clamp(0, rotated.height - 1);
    sw = zoomedW;
    sh = zoomedH;

    if (sx + sw > rotated.width) {
      sx = max(0, rotated.width - sw);
    }
    if (sy + sh > rotated.height) {
      sy = max(0, rotated.height - sh);
    }

    const dpi = 300.0;
    final targetWpx = ((target['w']! / 2.54) * dpi).round();
    final targetHpx = ((target['h']! / 2.54) * dpi).round();
    final cropped = img.copyCrop(rotated, x: sx, y: sy, width: sw, height: sh);
    final processed =
        img.copyResize(cropped, width: targetWpx, height: targetHpx);

    final outputBytes = img.encodeJpg(processed, quality: 90);
    final pdfDoc = pw.Document();
    final memoryImage = pw.MemoryImage(outputBytes);

    const pointsPerInch = 72.0;
    double cmToPt(double cm) => (cm / 2.54) * pointsPerInch;

    final pageWpt = PdfPageFormat.letter.width;
    final pageHpt = PdfPageFormat.letter.height;
    final targetWpt = cmToPt(target['w']!);
    final targetHpt = cmToPt(target['h']!);
    final marginPt = cmToPt(2.5);
    final gapPt = cmToPt(0.5);

    final usableW = max(0.0, pageWpt - marginPt * 2);
    final usableH = max(0.0, pageHpt - marginPt * 2);
    final cols = max(1, ((usableW + gapPt) / (targetWpt + gapPt)).floor());
    final rows = max(1, ((usableH + gapPt) / (targetHpt + gapPt)).floor());
    final perPage = max(1, cols * rows);

    var remaining = max(1, _quantity);
    while (remaining > 0) {
      final toDraw = min(remaining, perPage);
      final children = <pw.Widget>[];

      for (var i = 0; i < toDraw; i++) {
        final col = i % cols;
        final row = i ~/ cols;
        final dx = marginPt + col * (targetWpt + gapPt);
        final dy = marginPt + row * (targetHpt + gapPt);
        children.add(
          pw.Positioned(
            left: dx,
            top: dy,
            child: pw.Image(memoryImage, width: targetWpt, height: targetHpt),
          ),
        );
      }

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (_) => pw.Stack(children: children),
        ),
      );

      remaining -= toDraw;
    }

    return await pdfDoc.save();
  }

  Future<List<dynamic>> _uploadGeneratedOrRawFile(
      {required File imageFile, List<int>? pdfBytes}) async {
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

    if (pdfBytes != null) {
      final generatedName =
          'photo-${DateTime.now().millisecondsSinceEpoch.toString()}.pdf';
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          pdfBytes,
          filename: generatedName,
          contentType: null,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          imageFile.path,
          filename: imageFile.uri.pathSegments.isNotEmpty
              ? imageFile.uri.pathSegments.last
              : 'photo.jpg',
        ),
      );
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

  Map<String, dynamic>? _selectedUpload() => _uploadedFile;

  List<int> _collectFileIdsFromUpload() {
    final upload = _uploadedFile;
    if (upload == null) return const [];

    final rawId = upload['id_file'] ?? upload['idFile'] ?? upload['id'];
    final id = int.tryParse(rawId?.toString() ?? '') ?? 0;
    return id > 0 ? [id] : const [];
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

    final fileIds = _collectFileIdsFromUpload();

    await PaymentModal.open(
      context,
      amount: _totalPrice,
      serviceContext: {
        'lastUpload': _selectedUpload(),
        'uploads': _uploadedFile != null ? [_uploadedFile] : const [],
        'id_file': fileIds.isNotEmpty ? fileIds.first : null,
        'id_files': fileIds,
        'printType': _selectedType == 1 ? 'color' : 'bw',
        'paperSize': _paperSizeApiValue(),
        'rangeValue': 'all',
        'bothSides': false,
        'quantity': _quantity,
        'deliveryDate': _formatDate(_deliveryDate),
        'observations': _observationsController.text.trim(),
        'photoPaper': _paperTypeApiValue(),
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

  Future<void> _calculatePriceApi({Map<String, dynamic>? upload}) async {
    final uploadInfo = upload ?? _uploadedFile;
    if (uploadInfo == null) return;

    final filename = uploadInfo['filehash']?.toString() ??
        uploadInfo['storedName']?.toString() ??
        uploadInfo['filename']?.toString();
    if (filename == null || filename.isEmpty) return;

    final service = uploadInfo['type']?.toString() ??
        uploadInfo['service']?.toString() ??
        'document';

    setState(() {
      _priceLoading = true;
    });

    try {
      final token = _resolveToken();
      final payload = {
        'filename': filename,
        'service': service,
        'colorModes': _selectedType == 1 ? 'color' : 'bw',
        'paperSizes': 'carta',
        'ranges': 'all',
        'bothSides': false,
        'sets': 1,
        'type': 'photo',
        'paperType': _paperTypeApiValue(),
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

          debugPrint('[App] response $parsed');

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

      if (!mounted) return;
      setState(() {
        _priceData = normalized;
        _totalPrice = total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _priceData = null;
        _totalPrice = 0;
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

  Map<String, dynamic>? _extractSavedFile(
    Map<String, dynamic> registerResponse,
    List<dynamic> responseList,
  ) {
    final extracted = _extractSavedFiles(registerResponse, responseList);
    if (extracted.isEmpty) return null;
    return extracted.first;
  }

  Future<void> _processPickedImage(File imageFile) async {
    setState(() {
      _uploadLoading = true;
      _imageFile = imageFile;
    });

    try {
      final generatedPdf = await _generatePdfBytesFromImage(imageFile);
      final uploadResponse = await _uploadGeneratedOrRawFile(
        imageFile: imageFile,
        pdfBytes: generatedPdf,
      );
      final registerResponse = await _registerUploadedFiles(uploadResponse);
      final savedFile = _extractSavedFile(registerResponse, uploadResponse);

      if (!mounted) return;
      setState(() {
        _uploadedFile = savedFile;
      });

      if (savedFile != null) {
        await _calculatePriceApi(upload: savedFile);
      }
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

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final accepted = await _openCropRotateDialog(file, reset: true);
    if (!accepted) return;
    await _processPickedImage(file);
  }

  Future<bool> _openCropRotateDialog(File imageFile,
      {bool reset = false}) async {
    double normalizeAngle(double radians) {
      final full = 2 * pi;
      var v = radians % full;
      if (v < 0) v += full;
      return v;
    }

    double tempRotation = reset ? 0.0 : _rotationAngle;
    double tempZoom = reset ? 1.0 : _cropZoom;
    double tempOffsetX = reset ? 0.0 : _cropOffsetX;
    double tempOffsetY = reset ? 0.0 : _cropOffsetY;
    final targetAspect = _currentTargetAspect();

    String currentSizeLabel() {
      switch (_paperSizeApiValue()) {
        case 'tc':
          return '4x4 cm';
        case 'tap':
          return '9x13 cm';
        default:
          return '2.5x3 cm';
      }
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recortar y rotar imagen',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 360,
                        color: Colors.black12,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fullSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );

                            final maxCropW = fullSize.width * 0.9;
                            final maxCropH = fullSize.height * 0.86;
                            var cropW = maxCropW;
                            var cropH = cropW / targetAspect;

                            if (cropH > maxCropH) {
                              cropH = maxCropH;
                              cropW = cropH * targetAspect;
                            }

                            final cropRect = Rect.fromLTWH(
                              (fullSize.width - cropW) / 2,
                              (fullSize.height - cropH) / 2,
                              cropW,
                              cropH,
                            );

                            final moveX = fullSize.width * 0.25;
                            final moveY = fullSize.height * 0.25;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) {
                                setDialogState(() {
                                  final nx = tempOffsetX +
                                      (details.delta.dx / max(1.0, moveX));
                                  final ny = tempOffsetY +
                                      (details.delta.dy / max(1.0, moveY));
                                  tempOffsetX = nx.clamp(-1.0, 1.0);
                                  tempOffsetY = ny.clamp(-1.0, 1.0);
                                });
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Transform.translate(
                                    offset: Offset(
                                      tempOffsetX * moveX,
                                      tempOffsetY * moveY,
                                    ),
                                    child: Transform.rotate(
                                      angle: tempRotation,
                                      child: Transform.scale(
                                        scale: tempZoom,
                                        child: Image.file(
                                          imageFile,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  CustomPaint(
                                    painter: _CropOverlayPainter(cropRect),
                                  ),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Area impresa: ${currentSizeLabel()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tempRotation =
                                    normalizeAngle(tempRotation - pi / 2);
                              });
                            },
                            icon: const Icon(Icons.rotate_left),
                            label: const Text('Izquierda'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tempRotation =
                                    normalizeAngle(tempRotation + pi / 2);
                              });
                            },
                            icon: const Icon(Icons.rotate_right),
                            label: const Text('Derecha'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Rotación (grados)'),
                    Slider(
                      value: normalizeAngle(tempRotation) * 180 / pi,
                      min: 0,
                      max: 360,
                      divisions: 360,
                      label:
                          '${(normalizeAngle(tempRotation) * 180 / pi).round()}°',
                      onChanged: (value) {
                        setDialogState(() {
                          tempRotation = normalizeAngle(value * pi / 180);
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text('Zoom'),
                    Slider(
                      value: tempZoom,
                      min: 1,
                      max: 3,
                      divisions: 20,
                      label: tempZoom.toStringAsFixed(2),
                      onChanged: (value) {
                        setDialogState(() {
                          tempZoom = value;
                        });
                      },
                    ),
                    const Text('Desplazamiento horizontal'),
                    Slider(
                      value: tempOffsetX,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      label: tempOffsetX.toStringAsFixed(2),
                      onChanged: (value) {
                        setDialogState(() {
                          tempOffsetX = value;
                        });
                      },
                    ),
                    const Text('Desplazamiento vertical'),
                    Slider(
                      value: tempOffsetY,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      label: tempOffsetY.toStringAsFixed(2),
                      onChanged: (value) {
                        setDialogState(() {
                          tempOffsetY = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (accepted == true && mounted) {
      setState(() {
        _rotationAngle = normalizeAngle(tempRotation);
        _cropZoom = tempZoom;
        _cropOffsetX = tempOffsetX;
        _cropOffsetY = tempOffsetY;
        _imageFile = imageFile;
      });
      return true;
    }

    return false;
  }

  Future<void> _removeUpload() async {
    if (!mounted) return;
    setState(() {
      _uploadedFile = null;
      _priceData = null;
      _totalPrice = 0;
    });
  }

  void _showPreview() {
    final previewUrl = _buildPreviewUrl();
    final token = _resolveToken();

    if (previewUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero sube una imagen.')),
      );
      return;
    }

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
                const Text(
                  'Vista Previa Final',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SfPdfViewer.network(
                      previewUrl,
                      headers: {
                        if (token != null) 'Authorization': 'Bearer $token',
                      },
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar Vista Previa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
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

  void _triggerRebuildPdfAndPrice() {
    if (_imageFile != null) {
      _processPickedImage(_imageFile!);
    } else if (_uploadedFile != null) {
      _calculatePriceApi();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 10),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildPriceCard() {
    final perSet = (_priceData?['breakdownPerSet'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        <String, dynamic>{};
    final total = (_priceData?['breakdownTotal'] as Map?)
            ?.map((key, value) => MapEntry(key.toString(), value)) ??
        <String, dynamic>{};

    double parseNum(dynamic value) => double.tryParse('$value') ?? 0;

    final paperCost = parseNum(total['photoPaperCost'] ??
        perSet['photoPaperCost'] ??
        total['paperCost']);
    final inkCost = parseNum(total['inkCost'] ?? perSet['inkCost']);
    final perSetPrice = parseNum(_priceData?['pricePerSet']);
    final totalPrice = parseNum(_priceData?['totalPrice']);
    final paperType = (total['photoPaperType'] ??
            perSet['photoPaperType'] ??
            _paperTypeApiValue())
        .toString();

    return Container(
      padding: const EdgeInsets.all(15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Precios de fotografía',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_priceData == null)
            const Text('Sube una imagen para calcular precio.')
          else ...[
            const Text('Concepto'),
            Text('Tipo papel ($paperType): \$ ${paperCost.toStringAsFixed(2)}'),
            Text('Tinta: \$ ${inkCost.toStringAsFixed(2)}'),
            Text('Precio por set: \$ ${perSetPrice.toStringAsFixed(2)}'),
            Text(
                'Precio total impresi\u00f3n: \$ ${totalPrice.toStringAsFixed(2)}'),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 120,
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _imageFile != null
            ? Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: 150,
                    child: Transform.rotate(
                      angle: _rotationAngle,
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _imageFile == null
                          ? null
                          : () async {
                              final accepted = await _openCropRotateDialog(
                                _imageFile!,
                                reset: false,
                              );
                              if (!accepted) return;
                              _triggerRebuildPdfAndPrice();
                            },
                    ),
                  ),
                ],
              )
            : Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported),
                ),
              ),
      ),
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
                  title: 'Impresión de Foto',
                  backgroundImage: 'assets/imprfoto.png',
                  onBackPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const servicioses(),
                    ),
                  ),
                  previewWidget: _buildImagePreview(),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Subir Imagen',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_uploadedFile != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Archivo cargado: ${_uploadDisplayName(_uploadedFile!)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F0FE),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFF1A73E8)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.picture_as_pdf,
                                            color: Color(0xFF1A73E8)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _uploadDisplayName(_uploadedFile!),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _removeUpload,
                                          icon: const Icon(Icons.close,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      _buildSectionTitle('Cantidad de Fotos'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _quantity,
                            isExpanded: true,
                            items: List.generate(
                              50,
                              (index) => DropdownMenuItem(
                                value: index + 1,
                                child: Text('${index + 1}'),
                              ),
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _quantity = value);
                              _triggerRebuildPdfAndPrice();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildSectionTitle('Tipo de Impresión'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RadioListTile<int>(
                          title: const Text('Impresión Blanco y Negro'),
                          value: 0,
                          groupValue: _selectedType,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedType = val);
                            if (_uploadedFile != null) _calculatePriceApi();
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RadioListTile<int>(
                          title: const Text('Impresión a Color'),
                          value: 1,
                          groupValue: _selectedType,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _selectedType = val);
                            if (_uploadedFile != null) _calculatePriceApi();
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildSectionTitle('Tamaño'),
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
                            items: const [
                              DropdownMenuItem(
                                value: 'Tamaño infantil (2.5x3cm)',
                                child: Text('Tamaño infantil (2.5x3cm)'),
                              ),
                              DropdownMenuItem(
                                value: 'Tamaño carnet (4x4cm)',
                                child: Text('Tamaño carnet (4x4cm)'),
                              ),
                              DropdownMenuItem(
                                value: 'Tamaño album pequeño (9x13cm)',
                                child: Text('Tamaño album pequeño (9x13cm)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _paperSize = val);
                              _triggerRebuildPdfAndPrice();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildSectionTitle('Tipo de Papel'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _photoPaper,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Papel brillante',
                                child: Text('Papel brillante'),
                              ),
                              DropdownMenuItem(
                                value: 'Papel mate',
                                child: Text('Papel mate'),
                              ),
                              DropdownMenuItem(
                                value: 'Papel satinado',
                                child: Text('Papel satinado'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _photoPaper = val);
                              if (_uploadedFile != null) _calculatePriceApi();
                            },
                          ),
                        ),
                      ),
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
                      const SizedBox(height: 15),
                      _buildSectionTitle('Precios'),
                      _buildPriceCard(),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Precio total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1E4FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              '\$ ${_totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showPreview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
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
                                  borderRadius: BorderRadius.circular(20),
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

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter(this.cropRect);

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(0.45);
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRect(cropRect);
    final mask = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(mask, overlay);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;

    for (var i = 1; i <= 2; i++) {
      final x = cropRect.left + thirdW * i;
      final y = cropRect.top + thirdH * i;
      canvas.drawLine(
          Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      canvas.drawLine(
          Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
