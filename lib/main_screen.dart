import 'package:office_teschi/prints_screen.dart';
import 'package:office_teschi/login_screen.dart';
import 'package:office_teschi/product_screen.dart';
import 'package:office_teschi/services/notifications_sse_client.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/special_services_screen.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';

class principal extends StatelessWidget {
  const principal({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: UserSession.idUser != 1,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Solo navegar a LoginScreen si el usuario no está loggueado
        if (UserSession.idUser == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: const MenuDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                centerWidget: Text(
                  "Hola, ${UserSession.username ?? 'Usuario'}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                showBackButton: false,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const FeaturedBanner(imagePath: 'assets/ent1.png'),
                      const SizedBox(height: 16),
                      CategoryCard(
                        title: 'Impresiones',
                        imagePath: 'assets/impresiones.png',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const impresiones(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CategoryCard(
                        title: 'Productos',
                        imagePath: 'assets/productos.png',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const productos(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CategoryCard(
                        title: 'Servicios Especiales',
                        imagePath: 'assets/servicios.png',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const servicioses(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      ),
    );
  }
}

class FeaturedBanner extends StatelessWidget {
  final String imagePath;

  const FeaturedBanner({required this.imagePath, super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            Container(height: 150, color: Colors.blueGrey),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  const CategoryCard({
    required this.title,
    required this.imagePath,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image:
              DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black38,
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.brown),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 60, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  UserSession.username ?? 'Invitado',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar Sesión'),
            onTap: () async {
              await NotificationsSseClient.instance.stop();
              await UserSession.clearAuthData();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBottomNavBar(currentIndex: 0);
  }
}
