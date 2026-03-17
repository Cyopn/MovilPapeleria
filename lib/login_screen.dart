import 'dart:convert';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/main_screen.dart';
import 'package:office_teschi/register_screen.dart';
import 'package:office_teschi/services/notifications_sse_client.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> login() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${AppConfig.apiUrl}/users/login');
    final headers = {'Content-Type': 'application/json', 'Accept': '*/*'};
    final body = {
      'identifier': _identifierController.text,
      'password': _passwordController.text,
    };

    try {
      final response =
          await http.post(url, headers: headers, body: jsonEncode(body));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        final responseToken = responseData['token']?.toString();
        final responseUser = responseData['user'];

        if (responseToken == null || responseUser is! Map<String, dynamic>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Respuesta de inicio de sesión inválida'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        await UserSession.saveAuthData(
          token: responseToken,
          user: responseUser,
          authResponse: responseData,
        );

        // Inicia la escucha inmediatamente al iniciar sesión.
        await NotificationsSseClient.instance.ensureRunningForSession();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const principal()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credenciales incorrectas'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.white)),
          ClipPath(
            clipper: TopRectCircleClipper(),
            child: Image.asset(
              'assets/fondor.png',
              width: size.width,
              height: size.height * 0.5,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.brown),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: size.height * 0.15),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bienvenido',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.person, size: 80, color: Colors.black),
                    const SizedBox(height: 30),
                    _buildTextField(
                      Icons.person,
                      'Correo',
                      controller: _identifierController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      Icons.lock,
                      'Contraseña',
                      obscure: _obscurePassword,
                      controller: _passwordController,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const registro(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size(double.maxFinite, 55),
                        side:
                            BorderSide(color: Colors.grey.shade400, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Registrarse',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton(
                      onPressed: () async {
                        await NotificationsSseClient.instance.stop();
                        UserSession.token = null;
                        UserSession.user = null;
                        UserSession.authResponse = null;
                        UserSession.idUser = 1;
                        UserSession.guestCount++;
                        UserSession.username =
                            'Cliente ${UserSession.guestCount}';

                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const principal()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size(double.maxFinite, 55),
                        side:
                            BorderSide(color: Colors.grey.shade400, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Ingresar como invitado',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool obscure = false,
    required TextEditingController controller,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
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
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(oldClipper) => false;
}
