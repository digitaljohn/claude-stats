import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../theme/claude_theme.dart';
import 'widgets/window_scaffold.dart';

// coverage:ignore-start
// Excluded from coverage: this widget is a thin shell around the
// flutter_inappwebview WKWebView platform view + native cookie store. It can't
// be constructed in a unit test (CookieManager.instance() asserts a live
// InAppWebViewPlatform), and its logic only runs in response to real WebView
// navigation/cookie events.
//
/// Embedded claude.ai login. Loads the real login page in a WKWebView and
/// polls the cookie store for the `sessionKey` cookie; as soon as it appears
/// (i.e. the user has signed in) it pops with that value. Mirrors the
/// reference widget's "Log in to Claude" flow — no DevTools required.
class LoginWebView extends StatefulWidget {
  const LoginWebView({super.key});

  @override
  State<LoginWebView> createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<LoginWebView> {
  final _cookies = CookieManager.instance();
  Timer? _poll;
  bool _done = false;
  bool _loading = true;
  String _url = 'https://claude.ai/login';

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 1200), (_) => _check());
  }

  Future<void> _check() async {
    if (_done) return;
    try {
      final cookies = await _cookies.getCookies(url: WebUri('https://claude.ai'));
      for (final c in cookies) {
        // `Cookie.value` is dynamic and may be null; guard before stringifying
        // so a missing value can't be captured as the literal string "null".
        final value = c.value?.toString();
        if (c.name == 'sessionKey' && value != null && value.isNotEmpty) {
          _done = true;
          _poll?.cancel();
          if (mounted) Navigator.of(context).pop(value);
          return;
        }
      }
    } catch (_) {/* keep polling */}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WindowScaffold(
      titleBarColor: AppColors.ink,
      actions: [
        TitleBarButton(
          icon: Icons.close,
          tooltip: 'Cancel',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        children: [
          _urlBar(),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest:
                      URLRequest(url: WebUri('https://claude.ai/login')),
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    incognito: false,
                  ),
                  onLoadStart: (c, url) {
                    if (mounted) {
                      setState(() {
                        _loading = true;
                        _url = url?.toString() ?? _url;
                      });
                    }
                  },
                  onLoadStop: (c, url) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                        _url = url?.toString() ?? _url;
                      });
                    }
                    _check();
                  },
                  onUpdateVisitedHistory: (c, url, _) {
                    if (mounted) setState(() => _url = url?.toString() ?? _url);
                    _check();
                  },
                ),
                if (_loading)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.accent,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _urlBar() {
    final secure = _url.startsWith('https://');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(secure ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 13, color: secure ? AppColors.good : AppColors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(AppColors.textSecondary, size: 11),
            ),
          ),
          const SizedBox(width: 10),
          Text('SIGN IN TO CAPTURE SESSION',
              style: AppText.mono(AppColors.textFaint, size: 9)),
        ],
      ),
    );
  }
}
// coverage:ignore-end
