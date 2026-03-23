import 'package:office_teschi/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/services/notifications_sse_client.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/slide_menu.dart';

class PrintServiceHeader extends StatelessWidget {
  final String title;
  final String backgroundImage;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuPressed;
  final Widget? previewWidget;
  final double headerHeight;

  const PrintServiceHeader({
    super.key,
    required this.title,
    required this.backgroundImage,
    this.onBackPressed,
    this.onMenuPressed,
    this.previewWidget,
    this.headerHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    NotificationsSseClient.instance.ensureRunningForSession();

    return SizedBox(
      height: headerHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundImage),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: onBackPressed ?? () => Navigator.pop(context),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none,
                          color: Colors.white),
                      onPressed: () {
                        if (UserSession.idUser == 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Esta opción solo está disponible iniciando sesión'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        if (UserSession.idUser == 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Esta opción solo está disponible iniciando sesión'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (onMenuPressed != null) {
                          onMenuPressed!();
                          return;
                        }
                        showAppSlideMenu(context);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
