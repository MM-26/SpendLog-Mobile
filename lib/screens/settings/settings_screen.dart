import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/backup_service.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';

/// Settings and App Information screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(expenseActionsProvider).exportBackup();
      if (!context.mounted || result == null) return; // User cancelled
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved ${result.count} ${result.count == 1 ? "expense" : "expenses"} to:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? const Color(0xFF151824)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  result.filePath,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Export Failed'),
            ],
          ),
          content: Text('Could not export backup: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    // 1. Prompt user to pick file and strictly validate BEFORE modifying anything
    BackupValidationResult? validation;
    try {
      validation = await ref.read(expenseActionsProvider).pickAndValidateBackup();
      if (!context.mounted || validation == null) return; // User cancelled file picker
    } on BackupException catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Invalid Backup File'),
            ],
          ),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Import Error'),
            ],
          ),
          content: Text('Failed to read selected file: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Fetch current expense count for confirmation dialog
    final currentExpenses = await ref.read(expenseRepositoryProvider).getAllExpenses();

    if (!context.mounted) return;

    // 3. Confirmation Dialog per Bible §3 Decision 10
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Restore Backup?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (validation!.fileName != null) ...[
              Text(
                'File: ${validation.fileName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'Importing this backup will completely replace all existing data in SpendLog.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Text('• Existing expenses to be erased: ${currentExpenses.length}'),
            const SizedBox(height: 4),
            Text('• Expenses to be loaded: ${validation.expenses.length}'),
            const SizedBox(height: 4),
            Text('• Backup version: v${validation.version}'),
            const SizedBox(height: 14),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace All & Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 4. Perform atomic single-transaction restore
    try {
      await ref.read(expenseActionsProvider).restoreBackup(validation.expenses);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully restored ${validation.expenses.length} expenses'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Restore Failed'),
            ],
          ),
          content: Text('Failed to restore backup: $e\nExisting records were not modified.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

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
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF9AA5C4),
                  ),
                  onTap: () => _handleExport(context, ref),
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
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF9AA5C4),
                  ),
                  onTap: () => _handleImport(context, ref),
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
                  'Version 2.0.0 • Offline',
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

