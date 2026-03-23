import 'dart:io';
import 'dart:convert';
import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/app_header.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/widgets/app_bottom_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';

void main() {
  runApp(const perfil());
}

class perfil extends StatelessWidget {
  const perfil({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController lastNameController;
  late TextEditingController usernameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  late TextEditingController currentPasswordController;
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;
  bool passwordLoading = false;

  bool passwordModalOpen = false;
  File? selectedImageFile;
  String? currentFormAvatar;
  Map<String, String> originalForm = {};

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    lastNameController = TextEditingController();
    usernameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    currentPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    await UserSession.loadAuthData();
    if (!mounted) return;

    setState(() {
      nameController.text = UserSession.names ?? '';
      lastNameController.text = UserSession.lastnames ?? '';
      usernameController.text = UserSession.username ?? '';
      emailController.text = UserSession.email ?? '';
      phoneController.text = UserSession.phone ?? '';
      currentFormAvatar = UserSession.avatar ?? '';

      originalForm = {
        'name': nameController.text,
        'lastName': lastNameController.text,
        'username': usernameController.text,
        'email': emailController.text,
        'phone': phoneController.text,
        'avatar': currentFormAvatar ?? '',
      };
    });
  }

  String get _username {
    final value = (UserSession.username ?? '').trim();
    return value.isEmpty ? 'Usuario' : value;
  }

  String get _idUser {
    final value = UserSession.idUser;
    if (value == null) return 'N/A';
    return value.toString();
  }

  String? get _avatarUrl {
    if (selectedImageFile != null) {
      return null;
    }
    final raw = (currentFormAvatar ?? '').trim();
    return _resolveAvatarUrl(raw);
  }

  String? _resolveAvatarUrl(String? avatarValue) {
    final value = (avatarValue ?? '').trim();
    if (value.isEmpty || value == 'null' || value == 'undefined') {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('/')) {
      return '${AppConfig.apiUrl}$value';
    }

    return '${AppConfig.apiUrl}/file-manager/download/avatar/${Uri.encodeComponent(value)}';
  }

  List<Map<String, dynamic>> _normalizeUploadItems(dynamic decodedUpload) {
    if (decodedUpload is List) {
      return decodedUpload
          .whereType<Map>()
          .map((item) =>
              item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }
    if (decodedUpload is Map) {
      return [
        decodedUpload.map((key, value) => MapEntry(key.toString(), value))
      ];
    }
    return const [];
  }

  String? _extractAvatarHashFromUploadItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    final first = items.first;
    final hash = (first['storedName'] ?? first['filehash'] ?? first['filename'])
        ?.toString();
    if (hash == null || hash.trim().isEmpty) return null;
    return hash;
  }

  Future<void> _registerAvatarFiles(
      List<Map<String, dynamic>> uploadItems) async {
    if (uploadItems.isEmpty) return;

    final normalizedResList = uploadItems
        .map((raw) => {
              'filename': raw['originalName']?.toString() ??
                  raw['filename']?.toString() ??
                  'avatar.jpg',
              'filehash': raw['storedName']?.toString() ??
                  raw['filehash']?.toString() ??
                  '',
              'type': 'avatar',
            })
        .where((item) =>
            item['filename']!.isNotEmpty && item['filehash']!.isNotEmpty)
        .toList();

    if (normalizedResList.isEmpty) return;

    final payload = {
      'id_user': UserSession.idUser ?? AppConfig.defaultUserId,
      'resList': normalizedResList,
      'files': normalizedResList,
      'file': normalizedResList.first,
      'filename': normalizedResList.first['filename'],
      'filehash': normalizedResList.first['filehash'],
      'type': 'avatar',
    };

    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/files'),
      headers: {
        'Accept': '*/*',
        'Content-Type': 'application/json; charset=utf-8',
        if (UserSession.token != null)
          'Authorization': 'Bearer ${UserSession.token}',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo registrar el avatar en /files.');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isSameForm() {
    return nameController.text == originalForm['name'] &&
        lastNameController.text == originalForm['lastName'] &&
        usernameController.text == originalForm['username'] &&
        emailController.text == originalForm['email'] &&
        phoneController.text == originalForm['phone'] &&
        currentFormAvatar == originalForm['avatar'] &&
        selectedImageFile == null;
  }

  void _showUnsavedChangesSnackBar() {
    if (_isSameForm()) {
      ScaffoldMessenger.of(context).clearSnackBars();
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Expanded(child: Text('Hay cambios sin guardar')),
            TextButton(
              onPressed: _resetToOriginal,
              child: const Text('Reestablecer',
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _handleSave,
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void _resetToOriginal() {
    setState(() {
      nameController.text = originalForm['name'] ?? '';
      lastNameController.text = originalForm['lastName'] ?? '';
      usernameController.text = originalForm['username'] ?? '';
      emailController.text = originalForm['email'] ?? '';
      phoneController.text = originalForm['phone'] ?? '';
      currentFormAvatar = originalForm['avatar'];
      selectedImageFile = null;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _openPasswordModal() {
    setState(() {
      passwordModalOpen = true;
    });
  }

  void _closePasswordModal() {
    setState(() {
      passwordModalOpen = false;
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      showCurrentPassword = false;
      showNewPassword = false;
      showConfirmPassword = false;
      passwordLoading = false;
    });
  }

  Future<void> _handlePasswordConfirm() async {
    if (passwordLoading) return;

    final current = currentPasswordController.text;
    final newPass = newPasswordController.text;
    final confirm = confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnackBar('Completa todos los campos de contraseña', isError: true);
      return;
    }

    if (newPass != confirm) {
      _showSnackBar('Las contraseñas no coinciden', isError: true);
      return;
    }

    if (UserSession.idUser == null) {
      _showSnackBar('No se encontró id de usuario', isError: true);
      return;
    }

    setState(() => passwordLoading = true);

    try {
      final response = await http.put(
        Uri.parse(
            '${AppConfig.apiUrl}/users/${UserSession.idUser}/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession.token}',
        },
        body: jsonEncode({
          'currentPassword': current,
          'newPassword': newPass,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Contraseña actualizada');
        _closePasswordModal();
      } else {
        _showSnackBar('No se pudo cambiar la contraseña', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error al cambiar la contraseña: $e', isError: true);
    } finally {
      setState(() => passwordLoading = false);
    }
  }

  Future<void> _seleccionarFoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final cropped = await ImageCropper().cropImage(
          sourcePath: path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Ajustar imagen',
              toolbarColor: Colors.blue,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Ajustar imagen',
              cancelButtonTitle: 'Cancelar',
              doneButtonTitle: 'Aplicar',
            ),
          ],
        );

        if (cropped != null) {
          setState(() {
            selectedImageFile = File(cropped.path);
          });
          _showUnsavedChangesSnackBar();
        }
      }
    } catch (e) {
      _showSnackBar('No se pudo abrir el recortador de imagen', isError: true);
    }
  }

  Future<void> _handleSave() async {
    if (UserSession.idUser == null) {
      _showSnackBar('No se encontró id de usuario', isError: true);
      return;
    }

    try {
      String? avatarValue = currentFormAvatar;
      List<Map<String, dynamic>> uploadedAvatarItems = const [];

      if (selectedImageFile != null) {
        final avatarFilename =
            'avatar-${UserSession.idUser}-${DateTime.now().millisecondsSinceEpoch}.jpg';
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.apiUrl}/file-manager?service=avatar'),
        );

        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            selectedImageFile!.path,
            filename: avatarFilename,
          ),
        );

        request.fields['username'] = UserSession.username ?? '';

        if (UserSession.token != null) {
          request.headers['Authorization'] = 'Bearer ${UserSession.token}';
        }

        final uploadResponse = await request.send();

        if (uploadResponse.statusCode == 200) {
          final responseBody = await uploadResponse.stream.bytesToString();
          if (responseBody.isNotEmpty) {
            try {
              final decodedUpload = jsonDecode(responseBody);
              uploadedAvatarItems = _normalizeUploadItems(decodedUpload);
              avatarValue =
                  _extractAvatarHashFromUploadItems(uploadedAvatarItems) ??
                      avatarValue;
              await _registerAvatarFiles(uploadedAvatarItems);
            } catch (_) {
              avatarValue = responseBody;
            }
          }
        } else {
          throw Exception('No se pudo subir el avatar a file-manager.');
        }
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/users/${UserSession.idUser}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession.token}',
        },
        body: jsonEncode({
          'names': nameController.text,
          'lastnames': lastNameController.text,
          'username': usernameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'avatar': avatarValue,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? responseMap;
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            responseMap = decoded;
          } else if (decoded is Map) {
            responseMap =
                decoded.map((key, value) => MapEntry(key.toString(), value));
          }
        }

        responseMap ??= {
          'user': {
            'id_user': UserSession.idUser,
            'names': nameController.text,
            'lastnames': lastNameController.text,
            'username': usernameController.text,
            'email': emailController.text,
            'phone': phoneController.text,
            'avatar': avatarValue,
          },
        };

        await UserSession.applyUserUpdateResponse(responseMap);

        setState(() {
          nameController.text = UserSession.names ?? nameController.text;
          lastNameController.text =
              UserSession.lastnames ?? lastNameController.text;
          usernameController.text =
              UserSession.username ?? usernameController.text;
          emailController.text = UserSession.email ?? emailController.text;
          phoneController.text = UserSession.phone ?? phoneController.text;
          currentFormAvatar = UserSession.avatar ?? avatarValue;
          selectedImageFile = null;
          originalForm = {
            'name': nameController.text,
            'lastName': lastNameController.text,
            'username': usernameController.text,
            'email': emailController.text,
            'phone': phoneController.text,
            'avatar': currentFormAvatar ?? '',
          };
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        _showSnackBar('Perfil actualizado');
      } else {
        _showSnackBar('Error actualizando usuario', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Widget _buildTextFieldSection(
      String label, TextEditingController controller, VoidCallback onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool showPassword,
    Function(bool) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            suffixIcon: IconButton(
              icon:
                  Icon(showPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => onToggle(!showPassword),
            ),
          ),
          style: const TextStyle(color: Colors.black),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  title: 'Perfil',
                  showBackButton: false,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            child: const Center(
                              child: Text(
                                'Administración de cuenta',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: _seleccionarFoto,
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: const Color(0xFF006064),
                                      backgroundImage: selectedImageFile != null
                                          ? FileImage(selectedImageFile!)
                                              as ImageProvider
                                          : (_avatarUrl != null
                                              ? NetworkImage(_avatarUrl!)
                                                  as ImageProvider
                                              : const AssetImage(
                                                  'assets/logof.jpg')),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                _username,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Numero de cliente: " + _idUser,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          _buildTextFieldSection('Nombre', nameController, () {
                            _showUnsavedChangesSnackBar();
                          }),
                          _buildTextFieldSection('Apellido', lastNameController,
                              () {
                            _showUnsavedChangesSnackBar();
                          }),
                          _buildTextFieldSection(
                              'Nombre de usuario', usernameController, () {
                            _showUnsavedChangesSnackBar();
                          }),
                          _buildTextFieldSection('Correo', emailController, () {
                            _showUnsavedChangesSnackBar();
                          }),
                          _buildTextFieldSection('Teléfono', phoneController,
                              () {
                            _showUnsavedChangesSnackBar();
                          }),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openPasswordModal,
                              icon: const Icon(Icons.lock),
                              label: const Text('Cambiar contraseña'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
        ),
        if (passwordModalOpen)
          GestureDetector(
            onTap: _closePasswordModal,
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 15),
                            decoration: const BoxDecoration(
                              color: Colors.lightBlue,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Cambiar contraseña',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            'Contraseña actual',
                            currentPasswordController,
                            showCurrentPassword,
                            (value) {
                              setState(() => showCurrentPassword = value);
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildPasswordField(
                            'Contraseña nueva',
                            newPasswordController,
                            showNewPassword,
                            (value) {
                              setState(() => showNewPassword = value);
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildPasswordField(
                            'Confirmación de contraseña',
                            confirmPasswordController,
                            showConfirmPassword,
                            (value) {
                              setState(() => showConfirmPassword = value);
                            },
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: passwordLoading
                                    ? null
                                    : _handlePasswordConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30, vertical: 10),
                                ),
                                child: Text(
                                  passwordLoading ? 'Guardando...' : 'Guardar',
                                ),
                              ),
                              TextButton(
                                onPressed: _closePasswordModal,
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
