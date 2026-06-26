import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../theme/claude_theme.dart';
import 'app_card.dart';

/// A leading glyph that hints at the org's kind.
IconData accountIcon(Account a) {
  switch (a.type?.trim().toLowerCase()) {
    case 'team':
      return Icons.groups_outlined;
    case 'enterprise':
      return Icons.business_outlined;
    default:
      return Icons.person_outline;
  }
}

/// A compact pill that shows the active org and, on tap, drops down a menu of
/// every reachable org so the user can switch which account's usage is shown.
/// Rendered only when more than one org exists.
class AccountSwitcher extends StatelessWidget {
  const AccountSwitcher({
    super.key,
    required this.accounts,
    required this.activeId,
    required this.onSelect,
  });

  final List<Account> accounts;
  final String? activeId;
  final ValueChanged<String> onSelect;

  /// The active org, falling back to the first when [activeId] isn't (yet) one
  /// of the known orgs.
  Account? get _active {
    for (final a in accounts) {
      if (a.id == activeId) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Switch account',
      onSelected: onSelect,
      color: AppColors.surfaceRaised,
      elevation: 8,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        side: BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        for (final a in accounts)
          PopupMenuItem<String>(
            value: a.id,
            height: 46,
            child: _MenuRow(account: a, selected: a.id == active.id),
          ),
      ],
      child: _Anchor(active: active),
    );
  }
}

class _Anchor extends StatelessWidget {
  const _Anchor({required this.active});
  final Account active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(accountIcon(active), size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                SectionLabel(active.typeLabel),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.unfold_more_rounded,
              size: 18, color: AppColors.textFaint),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.account, required this.selected});
  final Account account;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.accent : AppColors.textSecondary;
    return Row(
      children: [
        Icon(accountIcon(account), size: 16, color: tint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                    selected ? AppColors.textPrimary : AppColors.textSecondary),
              ),
              Text(account.typeLabel,
                  style: AppText.mono(AppColors.textFaint, size: 9)),
            ],
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 10),
          Icon(Icons.check_rounded, size: 16, color: AppColors.accent),
        ],
      ],
    );
  }
}
