import 'package:office_teschi/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:office_teschi/services/notifications_sse_client.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:office_teschi/widgets/slide_menu.dart';

class AppHeader extends StatelessWidget {
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? centerWidget;

  const AppHeader({
    super.key,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    NotificationsSseClient.instance.ensureRunningForSession();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: onBackPressed ?? () => Navigator.pop(context),
                )
              else
                const SizedBox(width: 48),
              centerWidget ??
                  (title != null
                      ? Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const SizedBox.shrink()),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                    ),
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
                    icon: const Icon(
                      Icons.menu,
                    ),
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
                      showAppSlideMenu(context);
                    },
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}
