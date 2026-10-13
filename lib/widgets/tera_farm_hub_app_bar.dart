import 'package:flutter/material.dart';

/// Canonical hub top bar (Buyer home). Use on every tab hub so menu + title
/// stay pixel-aligned when switching Buyer ↔ Farmer tabs.
class TeraFarmHubAppBar extends StatelessWidget {
  /// Large title (e.g. app name). Defaults handled by caller.
  final String title;

  /// Optional line above [title] (e.g. "Welcome to").
  final String? subtitle;

  final bool showMenu;
  final List<Widget>? actions;

  static const double height = 112;

  const TeraFarmHubAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showMenu = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/top_bar.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 2,
          left: 24,
          right: 24,
        ),
        child: Stack(
          children: [
            // Nudge title up so "TeraFarm" sits on the shelf line in top_bar.png
            Align(
              alignment: const Alignment(0, -0.32),
              child: Transform.translate(
                offset: const Offset(0, -2),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ),
            ),
            if (showMenu)
              Positioned(
                left: -8,
                top: 18,
                child: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            if (actions != null && actions!.isNotEmpty)
              Positioned(
                right: -8,
                top: 18,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
