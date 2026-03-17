import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:office_teschi/main.dart'; // IMPORTANTE: Asegúrate de que esto apunte a tu archivo main.dart
import 'package:office_teschi/config/app_config.dart';

class registro extends StatelessWidget {
  const registro({super.key});

  @override
  Widget build(BuildContext context) {
    // Nota: Quitamos el MaterialApp aquí para que la navegación funcione correctamente
    // si vienes desde otra pantalla. Devolvemos solo el Scaffold o Screen.
    return const Scaffold(
      body: RegisterScreen(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores
  final TextEditingController _namesController = TextEditingController();
  final TextEditingController _lastnamesController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Variables para controlar si se ve la contraseña o no
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> registrarUsuario() async {
    if (_passwordController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    var url = Uri.parse('${AppConfig.apiUrl}/users');

    var headersList = {'Accept': '*/*', 'Content-Type': 'application/json'};

    var body = {
      "username": _usernameController.text,
      "names": _namesController.text,
      "lastnames": _lastnamesController.text,
      "email": _emailController.text,
      "password": _passwordController.text,
      "phone": _phoneController.text,
      "role": "student"
    };

    try {
      var req = http.Request('POST', url);
      req.headers.addAll(headersList);
      req.body = json.encode(body);

      var res = await req.send();
      final resBody = await res.stream.bytesToString();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('¡Usuario registrado con éxito!'),
                backgroundColor: Colors.green),
          );

          // 1. LIMPIAR LOS CAMPOS
          _namesController.clear();
          _lastnamesController.clear();
          _usernameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _confirmPassController.clear();
          _phoneController.clear();

          // 2. NAVEGAR A LA VENTANA MAIN (LandingPage)
          // Usamos pushAndRemoveUntil para borrar el historial y que no pueda volver atrás al registro
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MyApp()),
            (route) => false,
          );
        }
        print(resBody);
      } else {
        print("Error: ${res.statusCode} - ${res.reasonPhrase}");

        if (mounted) {
          String mensaje = 'Error del servidor: ${res.reasonPhrase}';

          if (res.statusCode == 500) {
            mensaje = 'Error: Posible dato duplicado o error de código';
          } else if (res.statusCode == 405) {
            mensaje = 'Error: URL incorrecta';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error de conexión'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _namesController.dispose();
    _lastnamesController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo blanco
          Positioned.fill(child: Container(color: Colors.white)),

          // Imagen decorativa superior
          ClipPath(
            clipper: TopRectCircleClipper(),
            child: Image.asset(
              'assets/fondor1.png',
              width: size.width,
              height: size.height * 0.5,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey),
            ),
          ),

          // Formulario con Scroll
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: size.height * 0.1),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Regístrate',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Icon(Icons.person, size: 60, color: Colors.black),
                    const SizedBox(height: 20),

                    // Campos de texto normales
                    _buildTextField(Icons.person, 'Nombre',
                        controller: _namesController),
                    const SizedBox(height: 15),

                    _buildTextField(Icons.person_outline, 'Apellidos',
                        controller: _lastnamesController),
                    const SizedBox(height: 15),

                    _buildTextField(Icons.account_circle, 'Usuario',
                        controller: _usernameController),
                    const SizedBox(height: 15),

                    _buildTextField(Icons.email, 'Correo',
                        controller: _emailController),
                    const SizedBox(height: 15),

                    // --- CAMPO CONTRASEÑA CON OJO ---
                    _buildTextField(Icons.lock, 'Contraseña',
                        obscure: _obscurePassword,
                        controller: _passwordController,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        )),
                    const SizedBox(height: 15),

                    // --- CAMPO CONFIRMAR CONTRASEÑA CON OJO ---
                    _buildTextField(Icons.lock_outline, 'Confirmar contraseña',
                        obscure: _obscureConfirmPassword,
                        controller: _confirmPassController,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        )),
                    const SizedBox(height: 15),

                    _buildTextField(Icons.phone, 'Teléfono',
                        controller: _phoneController, isNumber: true),
                    const SizedBox(height: 25),

                    // Botón
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Colors.yellow, Colors.orange],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          registrarUsuario();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modificado para aceptar suffixIcon (el ojito)
  Widget _buildTextField(IconData icon, String hint,
      {bool obscure = false,
      bool isNumber = false,
      required TextEditingController controller,
      Widget? suffixIcon // Nuevo parámetro opcional
      }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[700]),
        suffixIcon: suffixIcon, // Aquí ponemos el icono del ojo si existe
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade200,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class TopRectCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height * 0.6,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
