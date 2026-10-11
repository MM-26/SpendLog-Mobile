import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

/// Settings and App Information screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Adaptive colors
    final surfaceColor = colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF2E3147) : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? const Color(0xFF252837) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? const Color(0xFFF1F3FF) : const Color(0xFF181A2A);
    final textSecondary = isDark ? const Color(0xFF9AA5C4) : const Color(0xFF6B7280);
    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF8F9FE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Branding Header Card ──────────────────────────────────
            _BrandCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 24),

            // ── Section: Appearance ───────────────────────────────────────
            _SectionLabel(label: 'Appearance', textSecondary: textSecondary),
            const SizedBox(height: 10),
            _SettingsGroup(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              children: [
                _ThemeToggleTile(
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: Backup & Export ──────────────────────────────────
            _SectionLabel(label: 'Backup & Export', textSecondary: textSecondary),
            const SizedBox(height: 10),
            _SettingsGroup(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              children: [
                _SettingsTile(
                  icon: Icons.file_upload_outlined,
                  iconColor: const Color(0xFF6366F1),
                  iconBg: const Color(0xFF6366F1),
                  title: 'Export to JSON',
                  subtitle: 'Save expenses to backup file',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  trailing: _VersionBadge(
                    label: 'V1.1',
                    color: const Color(0xFF6366F1),
                    bgColor: isDark ? const Color(0xFF1E2040) : const Color(0xFFEEF2FF),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export feature will be available in V1.1'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: dividerColor),
                _SettingsTile(
                  icon: Icons.file_download_outlined,
                  iconColor: const Color(0xFF0EA5E9),
                  iconBg: const Color(0xFF0EA5E9),
                  title: 'Import from JSON',
                  subtitle: 'Restore expenses from backup file',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  trailing: _VersionBadge(
                    label: 'V1.1',
                    color: const Color(0xFF0EA5E9),
                    bgColor: isDark ? const Color(0xFF0D2233) : const Color(0xFFF0F9FF),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Import feature will be available in V1.1'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: About ────────────────────────────────────────────
            _SectionLabel(label: 'About', textSecondary: textSecondary),
            const SizedBox(height: 10),
            _SettingsGroup(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              children: [
                _SettingsTile(
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBg: const Color(0xFF8B5CF6),
                  title: 'Developer',
                  subtitle: 'Mishael',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF7C72FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/icons/logo_dark.png'
                    : 'assets/icons/logo_light.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/icons/logo_light.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpendLog',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 • Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textSecondary});
  final String label;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
    required this.surfaceColor,
    required this.borderColor,
  });

  final List<Widget> children;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }
}

/// Animated light/dark toggle tile.
class _ThemeToggleTile extends ConsumerWidget {
  const _ThemeToggleTile({
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Container(
          key: ValueKey(isDark),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF635BFF).withValues(alpha: 0.2)
                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: isDark ? const Color(0xFF635BFF) : const Color(0xFFF59E0B),
            size: 20,
          ),
        ),
      ),
      title: Text(
        'Theme',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      subtitle: Text(
        isDark ? 'Dark mode' : 'Light mode',
        style: TextStyle(fontSize: 12, color: textSecondary),
      ),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? const Color(0xFF635BFF) : const Color(0xFFE5E7EB),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: textSecondary),
      ),
      trailing: trailing,
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
