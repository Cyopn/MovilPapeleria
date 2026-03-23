import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:office_teschi/config/app_config.dart';

class TransactionService {
  static Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final url = Uri.parse('${AppConfig.apiUrl}/transactions/details');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      if (AppConfig.bearerToken.isNotEmpty)
        'Authorization': 'Bearer ${AppConfig.bearerToken}',
    });
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
          'Error al obtener transacciones: \\${response.statusCode}');
    }
  }
}
