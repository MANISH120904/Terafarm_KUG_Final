import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locales.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show LocaleProvider;
import '../services/navigation_service.dart';
import '../theme/tera_farm_theme.dart';

/// Buyer/Farmer toggle + language — original “box” shape (r16 / r13),
/// original greens, larger icons, overflow-safe labels.
class ModeLanguageBar extends StatelessWidget {
  final bool isSellerMode;
  final ValueChanged<bool>? onSellerSelected;
  final List<Color> gradientColors;
  final Color activeFg;
  final Color inactiveFg;
  final Color langBorder;

  const ModeLanguageBar({
    super.key,
    required this.isSellerMode,
    this.onSellerSelected,
    this.gradientColors = const [
      TeraFarmColors.farmerGreen,
      TeraFarmColors.farmerGreenDark,
    ],
    this.activeFg = TeraFarmColors.farmerGreen,
    this.inactiveFg = Colors.white,
    this.langBorder = TeraFarmColors.farmerGreen,
  });

  factory ModeLanguageBar.buyerStyle({
    Key? key,
    required bool isSellerMode,
    ValueChanged<bool>? onSellerSelected,
  }) {
    return ModeLanguageBar(
      key: key,
      isSellerMode: isSellerMode,
      onSellerSelected: onSellerSelected,
      // Original buyer greens from home_page
      gradientColors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
      activeFg: const Color(0xFF22C55E),
      inactiveFg: Colors.white,
      langBorder: const Color(0xFF22C55E),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context);
    final languages =
        List<Map<String, dynamic>>.from(AppLocales.dropdownItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final toggle = _ModeToggle(
          isSellerMode: isSellerMode,
          buyerLabel: loc.buyer,
          farmerLabel: loc.farmer,
          gradientColors: gradientColors,
          activeFg: activeFg,
          inactiveFg: inactiveFg,
          compact: compact,
          onBuyer: () =>
              NavigationService.navigateToBuyerSeller(context, false),
          onFarmer: () {
            if (onSellerSelected != null) {
              onSellerSelected!(true);
            } else {
              NavigationService.navigateToBuyerSeller(context, true);
            }
          },
        );
        final lang = _LanguageDropdown(
          languages: languages,
          localeProv: localeProv,
          borderColor: langBorder,
          compact: compact,
        );

        return Row(
          children: [
            Expanded(flex: 3, child: SizedBox(height: 48, child: toggle)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: SizedBox(height: 48, child: lang)),
          ],
        );
      },
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isSellerMode;
  final String buyerLabel;
  final String farmerLabel;
  final List<Color> gradientColors;
  final Color activeFg;
  final Color inactiveFg;
  final bool compact;
  final VoidCallback onBuyer;
  final VoidCallback onFarmer;

  const _ModeToggle({
    required this.isSellerMode,
    required this.buyerLabel,
    required this.farmerLabel,
    required this.gradientColors,
    required this.activeFg,
    required this.inactiveFg,
    required this.compact,
    required this.onBuyer,
    required this.onFarmer,
  });

  @override
  Widget build(BuildContext context) {
    // Original box outer: r16, padding 3, green gradient track
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              selected: !isSellerMode,
              icon: Icons.shopping_cart_outlined,
              label: buyerLabel,
              activeFg: activeFg,
              inactiveFg: inactiveFg,
              compact: compact,
              onTap: onBuyer,
            ),
          ),
          Expanded(
            child: _ModeChip(
              selected: isSellerMode,
              icon: Icons.agriculture,
              label: farmerLabel,
              activeFg: activeFg,
              inactiveFg: inactiveFg,
              compact: compact,
              onTap: onFarmer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color activeFg;
  final Color inactiveFg;
  final bool compact;
  final VoidCallback onTap;

  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.activeFg,
    required this.inactiveFg,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? activeFg : inactiveFg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            // Original selected fill (soft mint), not pure white pill
            color: selected ? const Color(0xFFF0FDF4) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: fg),
              SizedBox(width: compact ? 5 : 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 13,
                    color: fg,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> languages;
  final LocaleProvider localeProv;
  final Color borderColor;
  final bool compact;

  const _LanguageDropdown({
    required this.languages,
    required this.localeProv,
    required this.borderColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final current = languages.firstWhere(
      (lang) =>
          (lang['locale'] as Locale).languageCode ==
          localeProv.locale.languageCode,
      orElse: () => languages[0],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          isDense: true,
          value: current,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: borderColor,
            size: 18,
          ),
          style: TextStyle(
            color: const Color(0xFF1F2937),
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
          items: languages.map((lang) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: lang,
              child: Text(
                lang['name'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            );
          }).toList(),
          onChanged: (newLang) {
            if (newLang != null) {
              localeProv.setLocale(newLang['locale'] as Locale);
            }
          },
        ),
      ),
    );
  }
}
