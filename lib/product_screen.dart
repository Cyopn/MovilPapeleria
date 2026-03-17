import 'package:office_teschi/product_art_and_design_screen.dart';
import 'package:office_teschi/product_other_screen.dart';
import 'package:office_teschi/product_office_screen.dart'; // Asegúrate que el archivo se llame así
import 'package:office_teschi/product_stationery_screen.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/main_screen.dart';

import 'package:office_teschi/widgets/product_search_bar.dart';

void main() {
  runApp(const productos());
}

class productos extends StatelessWidget {
  const productos({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProductosScreen(),
    );
  }
}

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              showBackButton: true,
              onBackPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const principal()),
                );
              },
            ),

            // --- CONTENIDO ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const ProductSearchBar(),
                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Center(
                          child: Text('Productos',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(height: 20),

                    // 1. Banner
                    _CategoryCard(
                      imagePath: 'assets/fondopro.png',
                      title: null,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),

                    // 2. Oficina - CORREGIDO (Sin const)
                    _CategoryCard(
                      imagePath: 'assets/presentacionoficina.png',
                      title: 'Oficina',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ventana_oficina()));
                        print("Navegando a Oficina");
                      },
                    ),
                    const SizedBox(height: 20),

                    // 3. Papelería - CORREGIDO (Sin const)
                    _CategoryCard(
                      imagePath: 'assets/iprodcutos.png',
                      title: 'Papelería',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ventana_papeleria()));
                        print("Navegando a Papelería");
                      },
                    ),
                    const SizedBox(height: 20),

                    // 4. Arte y diseño - CORREGIDO (Sin const)
                    _CategoryCard(
                      imagePath: 'assets/artediseño.png',
                      title: 'Arte y diseño',
                      onTap: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => arte()));
                        print("Navegando a Arte");
                      },
                    ),
                    const SizedBox(height: 20),

                    // 5. Otros - CORREGIDO (Sin const)
                    _CategoryCard(
                      imagePath: 'assets/otros.png',
                      title: 'Otros',
                      onTap: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => otros()));
                        print("Navegando a Otros");
                      },
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
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String imagePath;
  final String? title;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.imagePath, this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 5, offset: Offset(0, 4))
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
            colorFilter: title != null
                ? ColorFilter.mode(
                    Colors.black.withOpacity(0.3), BlendMode.darken)
                : null,
          ),
        ),
        child: title != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(title!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ),
              )
            : null,
      ),
    );
  }
}
