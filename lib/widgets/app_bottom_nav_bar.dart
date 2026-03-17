import 'package:office_teschi/cart_screen.dart';
import 'package:office_teschi/profile_screen.dart';
import 'package:office_teschi/main_screen.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final int count = cart.totalItems;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          label: 'Carrito',
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Perfil'),
      ],
      onTap: (index) {
        if (index == currentIndex) return;

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const principal()),
          );
        }
        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const carrito()),
          );
        }
        if (index == 2) {
          // Verificar si hay usuario loggeado
          if (UserSession.idUser == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Esta opción solo está disponible iniciando sesión'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const perfil()),
          );
        }
      },
    );
  }
}
