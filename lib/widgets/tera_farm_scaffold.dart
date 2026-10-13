import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../menu_page.dart';
import '../theme/tera_farm_theme.dart';
import 'tera_farm_hub_app_bar.dart';

enum TeraFarmScaffoldMode {
  /// Tab/root hubs: top_bar.png hero + hamburger drawer.
  hub,

  /// Pushed pages: branded gradient AppBar + back (optional drawer).
  inner,
}

/// Shared chrome so hubs and inner pages match Buyer/Farmer homes.
class TeraFarmScaffold extends StatelessWidget {
  final TeraFarmScaffoldMode mode;
  final String title;
  final String? subtitle;
  final Widget body;
  final bool showDrawer;
  final bool showBottomBarAsset;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;

  /// When [mode] is hub and true, body is placed under the hero in a Column
  /// (caller body should expand / scroll itself). When false, [body] replaces
  /// the full scaffold body and must include its own header if needed.
  final bool includeHubHeader;

  /// Extra widgets stacked under the hub hero (location row, toggles, etc.).
  final List<Widget> hubExtras;

  const TeraFarmScaffold({
    super.key,
    required this.mode,
    required this.title,
    required this.body,
    this.subtitle,
    this.showDrawer = false,
    this.showBottomBarAsset = false,
    this.actions,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.bottomNavigationBar,
    this.includeHubHeader = true,
    this.hubExtras = const [],
  });

  bool get _useDrawer =>
      mode == TeraFarmScaffoldMode.hub || showDrawer;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? TeraFarmColors.surface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: TeraFarmColors.olive,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: bg,
        drawer: _useDrawer ? const MenuPage() : null,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        appBar: mode == TeraFarmScaffoldMode.inner ? _innerAppBar(context) : null,
        body: mode == TeraFarmScaffoldMode.hub && includeHubHeader
            ? SafeArea(
                child: Column(
                  children: [
                    TeraFarmHubAppBar(
                      title: title,
                      subtitle: subtitle,
                      showMenu: _useDrawer,
                      actions: actions,
                    ),
                    ...hubExtras,
                    Expanded(child: body),
                    if (showBottomBarAsset) const _BottomBarAsset(),
                  ],
                ),
              )
            : mode == TeraFarmScaffoldMode.hub
                ? body
                : SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(child: body),
                        if (showBottomBarAsset) const _BottomBarAsset(),
                      ],
                    ),
                  ),
      ),
    );
  }

  PreferredSizeWidget _innerAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        ...?actions,
        if (showDrawer)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: TeraFarmColors.gradientSecondary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _BottomBarAsset extends StatelessWidget {
  const _BottomBarAsset();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/bottom_bar.png',
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Sage gradient card used on location rows and filter panels.
class TeraFarmSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const TeraFarmSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TeraFarmColors.sageLight, TeraFarmColors.sage],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
