import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/product_art_and_design_screen.dart';
import 'package:office_teschi/product_office_screen.dart';
import 'package:office_teschi/product_other_screen.dart';
import 'package:office_teschi/product_stationery_screen.dart';

class ProductSearchBar extends StatefulWidget {
  const ProductSearchBar({super.key});

  @override
  State<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends State<ProductSearchBar> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _allProducts = [];
  List<dynamic> _results = [];
  bool _loading = false;
  String _error = '';

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }
    if (_allProducts.isEmpty) {
      _fetchAllProductsAndFilter(query);
    } else {
      final q = _normalize(query);
      setState(() {
        _results = _allProducts.where((product) {
          final name = _normalize((product['item']?['name'] ?? '').toString());
          final desc = _normalize((product['description'] ?? '').toString());
          return name.contains(q) || desc.contains(q);
        }).toList();
      });
    }
  }

  Future<void> _fetchAllProductsAndFilter(String query) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products/type/item'),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Bearer ${AppConfig.bearerToken}",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final products = data['products'] ?? [];
        setState(() {
          _allProducts = products;
        });
        final q = _normalize(query);
        setState(() {
          _results = products.where((product) {
            final name =
                _normalize((product['item']?['name'] ?? '').toString());
            final desc = _normalize((product['description'] ?? '').toString());
            return name.contains(q) || desc.contains(q);
          }).toList();
        });
      } else {
        setState(() {
          _error = 'Error al cargar productos';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _goToProductDetail(BuildContext context, Map<String, dynamic> product) {
    final category =
        product['item']?['category']?.toString().toLowerCase() ?? '';
    Widget? screen;
    switch (category) {
      case 'arte_y_diseno':
        screen = arte(selectedProduct: _mapProductForDetail(product));
        break;
      case 'oficina':
        screen =
            ventana_oficina(selectedProduct: _mapProductForDetail(product));
        break;
      case 'papeleria':
        screen =
            ventana_papeleria(selectedProduct: _mapProductForDetail(product));
        break;
      case 'otros':
        screen = otros(selectedProduct: _mapProductForDetail(product));
        break;
      default:
        screen = null;
    }
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => screen!,
        ),
      );
    }
  }

  Map<String, dynamic> _mapProductForDetail(Map<String, dynamic> product) {
    final item = product['item'] ?? {};
    final List filesList = product['files'] ?? [];
    final firstFile = filesList.isNotEmpty ? filesList[0] : null;
    return {
      'id': item['id_item'],
      'name': item['name'],
      'description': product['description'] ?? '',
      'price': product['price']?.toString() ?? '0',
      'category': item['category']?.toString().toLowerCase() ?? '',
      'image': firstFile != null
          ? '${AppConfig.apiUrl}/file-manager/download/${firstFile['type']}/${firstFile['filehash']}'
          : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(30),
          ),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Buscar...',
              border: InputBorder.none,
              suffixIcon: Icon(Icons.search),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
            ),
            onChanged: (value) {
              if (value.length > 2) {
                _filterProducts(value);
              } else if (value.isEmpty) {
                setState(() => _results = []);
              }
            },
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Buscando productos...'),
              ],
            ),
          ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_error, style: const TextStyle(color: Colors.red)),
          ),
        if (!_loading && _controller.text.length > 2 && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: const [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 10),
                Text('No se encontraron productos',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        if (_results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final product = _results[index];
                final name = product['item']?['name'] ?? 'Producto';
                final price = product['price']?.toString() ?? '';
                final category = product['item']?['category'] ?? '';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('Categoría: $category'),
                  trailing: Text('$price'),
                  onTap: () => _goToProductDetail(context, product),
                );
              },
            ),
          ),
      ],
    );
  }
}
