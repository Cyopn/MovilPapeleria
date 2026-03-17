import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:office_teschi/cart_provider.dart';
import 'package:office_teschi/widgets/payment_modal.dart';
import 'package:office_teschi/config/app_config.dart';

class arte extends StatefulWidget {
  final Map<String, dynamic>? selectedProduct;
  const arte({super.key, this.selectedProduct});

  @override
  State<arte> createState() => _arteState();
}

class _arteState extends State<arte> {
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
                              final cartItem = CartItem(
                                id: producto['id'].toString(),
                                name: producto['name'],
                                description: producto['description'],
                                image: producto['image'] ?? '',
                                price: double.parse(producto['price']),
                                quantity: cantidad,
                              );
                              await PaymentModal.open(
                                context,
                                amount: cartItem.price * cartItem.quantity,
                                cartItems: [cartItem],
                              );
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

  final String apiUrl = AppConfig.apiUrl;
  final String bearerToken = AppConfig.bearerToken;

  List<dynamic> productItems = [];
  bool isLoading = true;

  bool _detalleMostrado = false;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    // Si hay un producto seleccionado, mostrar el detalle después de que se construya el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedProduct != null && !_detalleMostrado) {
        _detalleMostrado = true;
        _mostrarDetalleProducto(context, producto: widget.selectedProduct!);
      }
    });
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
                  'category':
                      itemInfo['category']?.toString().toLowerCase() ?? '',
                  'image': firstFile != null
                      ? '$apiUrl/file-manager/download/${firstFile['type']}/${firstFile['filehash']}'
                      : null,
                };
              })
              // FILTRO ESPECÍFICO: arte_y_diseno
              .where((mi) => mi['category'] == 'arte_y_diseno')
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error cargando arte: $e");
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
            // 1. ENCABEZADO
            AppHeader(
              title: 'Arte y Diseño',
              showBackButton: true,
            ),

            // 2. CONTENIDO SCROLLABLE
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
                            _buildBanner(),
                            const SizedBox(height: 20),

                            // GRID DINÁMICO
                            productItems.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.only(top: 50),
                                    child: Text(
                                        "No hay productos de Arte y Diseño"),
                                  )
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
                                          product: productItems[index]);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
          color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
      child: const TextField(
          decoration: InputDecoration(
              border: InputBorder.none,
              suffixIcon: Icon(Icons.search, size: 30))),
    );
  }

  Widget _buildCategoryTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
      child: const Center(
          child: Text('Arte y Diseño',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildBanner() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
            image: AssetImage('assets/artediseño.png'), fit: BoxFit.cover),
      ),
    );
  }
}

// --- PRODUCT CARD CON VENTANA FLOTANTE ---

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductCard({super.key, required this.product});

  // Llama al método de la pantalla principal pasando el producto
  void _mostrarDetalleProducto(BuildContext context) {
    final arteState = context.findAncestorStateOfType<_arteState>();
    if (arteState != null) {
      arteState._mostrarDetalleProducto(context, producto: product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: product['image'] != null
                      ? Image.network(
                          product['image'],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Center(child: Icon(Icons.broken_image)),
                        )
                      : Image.asset('assets/no-image.png', fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(15)),
                      onTap: () => _mostrarDetalleProducto(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Producto',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${product['price']}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final cartItem = CartItem(
                        id: product['id'].toString(),
                        name: product['name'],
                        description: product['description'],
                        image: product['image'] ?? '',
                        price: double.parse(product['price']),
                        quantity: 1,
                      );
                      context.read<CartProvider>().addItem(cartItem);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Se agregó 1 ${product['name']} al carrito'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF90CAF9),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                    label: const Text('Añadir', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarDetalleProducto(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF90CAF9),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                    label: const Text('Comprar ahora',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
