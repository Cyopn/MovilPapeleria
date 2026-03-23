import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:provider/provider.dart';
import 'package:office_teschi/cart_provider.dart';
import 'package:office_teschi/widgets/payment_modal.dart';

class carrito extends StatelessWidget {
  const carrito({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Carrito',
              showBackButton: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildSectionTitle('Pedidos', cart.totalItems),

                    cart.items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(50),
                            child: Text("Tu carrito está vacío"))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cart.items.length,
                            itemBuilder: (context, index) => _buildCartCard(
                                context, cart.items[index], index),
                          ),

                    const SizedBox(height: 20),
                    _buildActionButtons(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildSectionTitle(String text, int itemCount) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: text,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              TextSpan(
                text: ' ($itemCount)',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartCard(BuildContext context, CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Image.network(item.image,
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.image)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text('\$ ${item.price.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Cantidad: ${item.quantity}',
                    style: const TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 28),
            onPressed: () => context.read<CartProvider>().removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF90CAF9),
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: cart.items.isEmpty
            ? null
            : () async {
                await PaymentModal.open(
                  context,
                  amount: cart.total,
                  cartItems: List<CartItem>.from(cart.items),
                  onPaymentSuccess: () {
                    context.read<CartProvider>().clear();
                  },
                );
              },
        child: const Text('Continuar compra',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
