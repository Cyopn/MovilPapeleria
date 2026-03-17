import 'package:office_teschi/ss_spiral_screen.dart';
import 'package:office_teschi/ss_documents_screen.dart';
import 'package:office_teschi/ss_bound_screen.dart';
import 'package:office_teschi/ss_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:office_teschi/main_screen.dart';

// Importa aquí tus archivos de destino si ya los tienes creados
// import 'package:office_teschi/encuadernado_detalle.dart';

void main() {
  runApp(const servicioses());
}

class servicioses extends StatelessWidget {
  const servicioses({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ServiciosScreen(),
    );
  }
}

class ServiciosScreen extends StatelessWidget {
  const ServiciosScreen({super.key});

  // Hemos cambiado el tipo a dynamic para poder guardar el Widget de destino
  static final List<Map<String, dynamic>> servicios = [
    {
      'titulo': 'Encuadernado\ne Impresión',
      'imagen': 'assets/encuadernado.png',
      'destino': const encuadernado(), // Reemplaza con tu clase real
    },
    {
      'titulo': 'Impresión\nde Fotografía',
      'imagen': 'assets/imprfoto.png',
      'destino': const fotografia(), // Reemplaza con tu clase real
    },
    {
      'titulo': 'Anillado\ne Impresión',
      'imagen': 'assets/anillado.png',
      'destino': const anillado(),
    },
    {
      'titulo': 'Documentos\nEspeciales',
      'imagen': 'assets/docespecial.png',
      'destino': const documento(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Servicios Especiales',
              showBackButton: true,
              onBackPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const principal()),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar servicio...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.black),
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('Nuestros Servicios',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: servicios.length,
                      itemBuilder: (context, index) {
                        final servicio = servicios[index];
                        return GestureDetector(
                          onTap: () {
                            // NAVEGACIÓN DINÁMICA
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => servicio['destino']),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: AssetImage(servicio['imagen']!),
                                fit: BoxFit.cover,
                              ),
                              border: index == servicios.length - 1
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7)
                                  ],
                                  stops: const [0.6, 1.0],
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.bottomCenter,
                              child: Text(
                                servicio['titulo']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
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

// ===== PANTALLAS TEMPORALES (Crea archivos separados para estas) =====

class EncuadernadoScreen extends StatelessWidget {
  const EncuadernadoScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Encuadernado")),
      body: const Center(child: Text("Ventana de Encuadernado")));
}

class FotografiaScreen extends StatelessWidget {
  const FotografiaScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Fotografía")),
      body: const Center(child: Text("Ventana de Fotografía")));
}

class AnilladoScreen extends StatelessWidget {
  const AnilladoScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Anillado")),
      body: const Center(child: Text("Ventana de Anillado")));
}

class DocumentosScreen extends StatelessWidget {
  const DocumentosScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Documentos")),
      body: const Center(child: Text("Ventana de Documentos")));
}
