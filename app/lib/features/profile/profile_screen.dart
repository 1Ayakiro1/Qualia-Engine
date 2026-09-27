import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A dedicated profile workspace opened from the account button in the rail.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
          child: Row(
            children: [
              _ProfileAction(
                icon: Icons.arrow_back,
                label: 'Back to app',
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profile',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 80),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 330;
                        final identity = const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ayakiro',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Local offline profile',
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                        final avatar = Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            size: 42,
                            color: AppTheme.text,
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    avatar,
                                    const SizedBox(height: 14),
                                    identity,
                                  ],
                                )
                              : Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 18),
                                    identity,
                                  ],
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Account 1',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileAction extends StatefulWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_ProfileAction> createState() => _ProfileActionState();
}

class _ProfileActionState extends State<_ProfileAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 17, color: AppTheme.text),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
