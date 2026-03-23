import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:office_teschi/cart_provider.dart';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/widgets/product_search_bar.dart';

class ventana_oficina extends StatefulWidget {
  final Map<String, dynamic>? selectedProduct;
  const ventana_oficina({super.key, this.selectedProduct});

  @override
  State<ventana_oficina> createState() => _ventana_oficinaState();
}

class _ventana_oficinaState extends State<ventana_oficina> {
  final String apiUrl = AppConfig.apiUrl;
  final String bearerToken = AppConfig.bearerToken;
  bool _detalleMostrado = false;

  List<dynamic> productItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedProduct != null && !_detalleMostrado) {
        _detalleMostrado = true;
        _mostrarDetalleProducto(context, producto: widget.selectedProduct!);
      }
    });
  }

  void _mostrarDetalleProducto(BuildContext context,
      {required Map<String, dynamic> producto}) {
    int cantidad = 1;
    final outerContext = context;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: const Color(0xFFEFEFEF),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.black),
                      ),
                    ),
                    Text(
                      '${producto['name']}',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: producto['image'] != null
                            ? Image.network(producto['image'],
                                height: 140, fit: BoxFit.contain)
                            : const Icon(Icons.image, size: 100),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '\$${producto['price']}',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              const Text("Cantidad: ",
                                  style: TextStyle(fontSize: 16)),
                              GestureDetector(
                                onTap: () => setState(() {
                                  if (cantidad > 1) cantidad--;
                                }),
                                child: const Icon(Icons.remove, size: 24),
                              ),
                              const SizedBox(width: 4),
                              Text("$cantidad ",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => cantidad++),
                                child: const Icon(Icons.add, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7CC8F8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Comprar Ahora',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final cartItem = CartItem(
                                id: producto['id'].toString(),
                                name: producto['name'],
                                description: producto['description'],
                                image: producto['image'] ?? '',
                                price: double.parse(producto['price']),
                                quantity: cantidad,
                              );
                              context.read<CartProvider>().addItem(cartItem);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Se agregó $cantidad ${producto['name']} al carrito'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF90D878),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 4),
                                Flexible(
                                    child: Text('Añadir al carrito',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/products/type/item'),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Bearer $bearerToken",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List productsRaw = data['products'] ?? [];

        setState(() {
          productItems = productsRaw
              .where((p) => p['item'] != null)
              .map((p) {
                final itemInfo = p['item'];
                final List filesList = p['files'] ?? [];
                final firstFile = filesList.isNotEmpty ? filesList[0] : null;

                return {
                  'id': itemInfo['id_item'],
                  'name': itemInfo['name'],
                  'description': p['description'] ?? '',
                  'price': p['price']?.toString() ?? '0',
                  'category': itemInfo['category'],
                  'image': firstFile != null
                      ? '$apiUrl/file-manager/download/${firstFile['type']}/${firstFile['filehash']}'
                      : null,
                };
              })
              .where((mi) => mi['category'] == 'oficina')
              .toList();

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error cargando productos: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Oficina',
              showBackButton: true,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: fetchProducts,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildSearchField(),
                            const SizedBox(height: 20),
                            _buildCategoryTitle(),
                            const SizedBox(height: 20),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: const DecorationImage(
                                  image: AssetImage(
                                      'assets/presentacionoficina.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            productItems.isEmpty
                                ? const Text(
                                    "No hay productos de oficina disponibles")
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: productItems.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.65,
                                      crossAxisSpacing: 15,
                                      mainAxisSpacing: 15,
                                    ),
                                    itemBuilder: (context, index) {
                                      return ProductCard(
                                        product: productItems[index],
                                        onShowDetail: (ctx, prod) =>
                                            _mostrarDetalleProducto(ctx,
                                                producto: prod),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildSearchField() {
    return const ProductSearchBar();
  }

  Widget _buildCategoryTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
      child: const Center(
          child:
              Text('Oficina', style: TextStyle(fontWeight: FontWeight.bold))),
    );
  }

}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final void Function(BuildContext, Map<String, dynamic>) onShowDetail;
  const ProductCard(
      {super.key, required this.product, required this.onShowDetail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onShowDetail(context, product),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: product['image'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product['image'],
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Icon(Icons.image, size: 80),
              ),
              const SizedBox(height: 8),
              Text(
                product['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '\$${product['price']}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
