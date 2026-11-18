import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_entry.dart';
import '../../core/theme/app_palette.dart';

/// Account workspace with GitHub OAuth through Supabase Auth.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGitHub();
      logI(LogSource.profile, 'запущена OAuth-аутентификация через GitHub');
    } catch (error) {
      logE(LogSource.profile, 'ошибка входа через GitHub: $error');
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signOut();
      logI(LogSource.profile, 'выход из пользовательской сессии');
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Sign in with GitHub')) {
      return 'GitHub вход не завершён. Вернитесь в приложение после авторизации.';
    }
    return 'Не удалось выполнить действие. Проверьте подключение и настройки OAuth.';
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
          child: Row(
            children: [
              _ProfileAction(
                icon: AppIcons.arrowBack,
                label: context.l10n.textBackToApp370,
                onTap: widget.onBack,
              ),
              const Spacer(),
              Text(
                context.l10n.textProfile75,
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ref
                    .watch(authUserProvider)
                    .when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, _) => _buildSignedOut(context),
                      data: (user) => user == null
                          ? _buildSignedOut(context)
                          : _buildSignedIn(context, user),
                    ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSignedOut(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.textLogInWith400,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.palette.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      _LoginProviderButton(
        label: _busy ? context.l10n.textConnectingToGitHub401 : 'GitHub',
        icon: AppIcons.code,
        onPressed: _busy ? null : _signIn,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          context.hostLabel(_error!),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );

  Widget _buildSignedIn(BuildContext context, dynamic user) {
    final metadata = user.userMetadata as Map<String, dynamic>? ?? const {};
    final name = metadata['name'] ?? metadata['full_name'] ?? user.email;
    final username = metadata['user_name'] ?? metadata['preferred_username'];
    final avatar = metadata['avatar_url'] ?? metadata['picture'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: context.palette.panel,
          foregroundImage: avatar is String && avatar.isNotEmpty
              ? NetworkImage(avatar)
              : null,
          child: const Icon(AppIcons.user, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          '$name',
          style: TextStyle(
            color: context.palette.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (username is String && username.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '@$username',
              style: TextStyle(color: context.palette.mutedText),
            ),
          ),
        if (user.email is String)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              user.email as String,
              style: TextStyle(color: context.palette.mutedText),
            ),
          ),
        const SizedBox(height: 24),
        _LoginProviderButton(
          label: _busy
              ? context.l10n.textSigningOut402
              : context.l10n.textSignOut403,
          icon: AppIcons.logout,
          onPressed: _busy ? null : _signOut,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            context.hostLabel(_error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _LoginProviderButton extends StatelessWidget {
  const _LoginProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.palette.text,
        backgroundColor: context.palette.panel,
        side: BorderSide.none,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: context.palette.text,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
