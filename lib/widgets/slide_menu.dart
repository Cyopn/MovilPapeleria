import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/login_screen.dart';
import 'package:office_teschi/my_orders_screen.dart';
import 'package:office_teschi/notifications_screen.dart';
import 'package:office_teschi/order_history_screen.dart';
import 'package:office_teschi/profile_screen.dart';
import 'package:office_teschi/services/notifications_sse_client.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:flutter/material.dart';

Future<void> showAppSlideMenu(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'SlideMenu',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, _, __) {
      return _SlideMenuOverlay(parentContext: context);
    },
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SlideMenuOverlay extends StatelessWidget {
  final BuildContext parentContext;

  const _SlideMenuOverlay({required this.parentContext});

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

  ImageProvider _buildAvatarImage() {
    if (UserSession.profileImage != null) {
      return FileImage(UserSession.profileImage!);
    }

    final avatarUrl = _resolveAvatarUrl(UserSession.avatar);
    if (avatarUrl != null) {
      return NetworkImage(avatarUrl);
    }

    return const AssetImage('assets/logof.jpg');
  }

  void _showUnavailable(BuildContext context,
      {String message = 'Opcion no disponible'}) {
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.of(parentContext).pop();
    await NotificationsSseClient.instance.stop();
    await UserSession.clearAuthData();
    if (!parentContext.mounted) return;
    Navigator.pushAndRemoveUntil(
      parentContext,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E6E6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black87),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = (UserSession.username ?? '').trim().isEmpty
        ? 'Nombre de usuario'
        : UserSession.username!.trim();
    final clientId = UserSession.idUser?.toString() ?? 'N/A';
    final fullName =
        '${UserSession.names ?? ''} ${UserSession.lastnames ?? ''}'.trim();
    final email = (UserSession.email ?? '').trim();
    final phone = (UserSession.phone ?? '').trim();

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: FractionallySizedBox(
            widthFactor: 0.9,
            heightFactor: 1,
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(28)),
                      gradient: LinearGradient(
                        colors: [Color(0xFF8AD8F2), Color(0xFF318BEF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.black),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundImage: _buildAvatarImage(),
                            backgroundColor: const Color(0xFFBFE9F7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            username,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Numero de cliente: $clientId',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      parentContext,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const MisPedidosScreen(),
                                      ),
                                    );
                                  },
                                  child: const Column(
                                    children: [
                                      Icon(Icons.inventory_2_outlined,
                                          size: 28),
                                      SizedBox(height: 6),
                                      Text('Mis pedidos'),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      parentContext,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Column(
                                    children: [
                                      Icon(Icons.notifications_none, size: 28),
                                      SizedBox(height: 6),
                                      Text('Notificaciones'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildReadOnlyField(
                              'Nombre', fullName.isEmpty ? 'Nombre' : fullName),
                          _buildReadOnlyField(
                              'Correo', email.isEmpty ? 'Sin correo' : email),
                          _buildReadOnlyField('Numero de telefono',
                              phone.isEmpty ? 'Sin telefono' : phone),
                          const SizedBox(height: 8),
                          _buildMenuOption(
                            context: context,
                            icon: Icons.settings,
                            label: 'Administrador de cuenta',
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                parentContext,
                                MaterialPageRoute(
                                    builder: (_) => const perfil()),
                              );
                            },
                          ),
                          _buildMenuOption(
                            context: context,
                            icon: Icons.history,
                            label: 'Historial de pedidos',
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                parentContext,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HistorialPedidosScreen(),
                                ),
                              );
                            },
                          ),
                          _buildMenuOption(
                            context: context,
                            icon: Icons.support_agent,
                            label: 'Soporte y ayuda',
                            onTap: () => _showUnavailable(context),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _handleLogout,
                            child: const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
