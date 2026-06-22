import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/claude_theme.dart';
import 'login_webview.dart';
import 'widgets/grid_background.dart';
import 'widgets/window_scaffold.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _field = TextEditingController();
  bool _obscure = true;
  bool _showPaste = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  // coverage:ignore-start
  // Pushes the platform LoginWebView (see login_webview.dart) and signs in with
  // the captured key. Excluded for the same reason: it depends on the live
  // WebView/cookie platform, which can't be driven in a unit test.
  Future<void> _login() async {
    final key = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const LoginWebView(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    if (key != null && key.isNotEmpty) {
      await widget.controller.signIn(key);
    }
  }
  // coverage:ignore-end

  Future<void> _connectPasted() async {
    FocusScope.of(context).unfocus();
    await widget.controller.signIn(_field.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return WindowScaffold(
      background: const GridBackground(),
      showBorder: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 372),
            child: _card(c),
          ),
        ),
      ),
    );
  }

  Widget _card(AppController c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 40, spreadRadius: -8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CONNECT', style: AppText.mono(AppColors.textFaint, size: 11)),
          const SizedBox(height: 10),
          Text(
            'Monitor your\nClaude usage.',
            style: AppText.display(AppColors.textPrimary).copyWith(fontSize: 30),
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in with your Claude account. The session is captured for you '
            'and stored privately on your Mac — never sent anywhere but '
            'claude.ai.',
            style: AppText.body(AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: _PrimaryButton(
              label: c.signingIn ? 'Verifying…' : 'Log in with Claude',
              busy: c.signingIn,
              icon: Icons.arrow_forward_rounded,
              onTap: c.signingIn ? null : _login,
            ),
          ),
          if (c.signInError != null) ...[
            const SizedBox(height: 12),
            _errorBox(c.signInError!),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _GhostButton(
                  label: 'Try demo data',
                  onTap: c.signingIn ? null : c.enterDemo),
              const Spacer(),
              _GhostButton(
                label: _showPaste ? 'Hide' : 'Paste a key instead',
                onTap: () => setState(() => _showPaste = !_showPaste),
              ),
            ],
          ),
          if (_showPaste) ...[
            const SizedBox(height: 14),
            _pasteSection(c),
          ],
        ],
      ),
    );
  }

  Widget _pasteSection(AppController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _keyField(),
        const SizedBox(height: 8),
        Text(
          'Advanced: claude.ai → DevTools → Application → Cookies → '
          'copy the “sessionKey” value.',
          style: AppText.label(AppColors.textFaint).copyWith(height: 1.35),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: _PrimaryButton(
            label: 'Connect with key',
            busy: false,
            onTap: c.signingIn ? null : _connectPasted,
          ),
        ),
      ],
    );
  }

  Widget _keyField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _field,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _connectPasted(),
              style: AppText.mono(AppColors.textPrimary, size: 12),
              cursorColor: AppColors.textSecondary,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: InputBorder.none,
                hintText: 'sk-ant-sid01-…',
                hintStyle: AppText.mono(AppColors.textFaint, size: 12),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16,
              color: AppColors.textFaint,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: AppText.label(AppColors.textPrimary).copyWith(height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    this.onTap,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Monochrome CTA: cream fill + dark ink text, to match the app's restrained
    // warm-grey palette (clay is reserved for sparse accents, not a big fill).
    const fg = AppColors.ink;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            color: enabled
                ? (_hover ? const Color(0xFFFFFFFF) : AppColors.textPrimary)
                : AppColors.textPrimary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDims.radiusSm),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 10),
              ],
              Text(widget.label, style: AppText.title(fg)),
              if (widget.icon != null && !widget.busy) ...[
                const SizedBox(width: 8),
                Icon(widget.icon, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: AppText.label(
              _hover ? AppColors.textPrimary : AppColors.textFaint),
        ),
      ),
    );
  }
}
