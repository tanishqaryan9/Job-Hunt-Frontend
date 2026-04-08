import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── PRIMARY BUTTON ────────────────────────────────────────────
class BrutalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color? textColor;
  final bool isLoading;
  final Widget? icon;
  final double? width;

  const BrutalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppTheme.accent,
    this.textColor,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _isGhost => widget.color == AppTheme.bgElevated || widget.color == AppTheme.bgCard;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null && !widget.isLoading;
    final bg = disabled ? AppTheme.bgMuted : widget.color;
    final fg = widget.textColor ?? (disabled ? AppTheme.textFaint : AppTheme.white);
    final isAccent = widget.color == AppTheme.accent || widget.color == AppTheme.primary;

    return GestureDetector(
      onTapDown: (_) { if (!disabled) _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); },
      onTapCancel: () { _ctrl.reverse(); },
      onTap: (disabled || widget.isLoading) ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            gradient: isAccent && !disabled ? AppTheme.accentGradient : null,
            color: (!isAccent || disabled) ? bg : null,
            borderRadius: BorderRadius.circular(14),
            border: _isGhost ? Border.all(color: AppTheme.bgMuted, width: 1) : null,
            boxShadow: isAccent && !disabled ? AppTheme.accentShadow() : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          child: Row(
            mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else ...[
                if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                Text(widget.label, style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                  fontSize: 15, color: fg, letterSpacing: 0.2,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── CARD ──────────────────────────────────────────────────────
class BrutalCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double shadowOffset;

  const BrutalCard({
    super.key,
    required this.child,
    this.color = AppTheme.bgCard,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadowOffset = 4,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: AppTheme.cardDecoration(color: color),
      padding: padding,
      child: child,
    ),
  );
}

// ── TEXT FIELD ────────────────────────────────────────────────
class BrutalTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final String? hint;
  final void Function(String)? onChanged;

  const BrutalTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w500,
          fontSize: 15, color: AppTheme.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon != null
            ? IconTheme(data: const IconThemeData(color: AppTheme.textMuted), child: suffixIcon!)
            : null,
        prefixIcon: prefixIcon != null
            ? IconTheme(data: const IconThemeData(color: AppTheme.textMuted), child: prefixIcon!)
            : null,
        filled: true,
        fillColor: AppTheme.bgElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.bgMuted, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.bgMuted, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.rose, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.rose, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w500, color: AppTheme.textMuted),
        floatingLabelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, color: AppTheme.accent),
      ),
    );
  }
}

// ── SKILL CHIP ────────────────────────────────────────────────
class SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDelete;
  final Color color;

  const SkillChip({super.key, required this.label, this.onDelete, this.color = AppTheme.bgElevated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color == AppTheme.bgElevated ? AppTheme.bgElevated : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color == AppTheme.bgElevated ? AppTheme.bgMuted : color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
            fontSize: 12, color: AppTheme.textMuted,
          )),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 13, color: AppTheme.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

// ── STATUS BADGE ──────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  (Color, Color) get _colors {
    switch (status.toUpperCase()) {
      case 'APPLIED':     return (AppTheme.blue, AppTheme.blueLight);
      case 'SHORTLISTED': return (AppTheme.amber, AppTheme.amberLight);
      case 'HIRED':       return (AppTheme.green, AppTheme.greenLight);
      case 'REJECTED':    return (AppTheme.rose, AppTheme.roseLight);
      default:            return (AppTheme.textMuted, AppTheme.bgMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(status, style: TextStyle(
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
        fontSize: 10, color: color, letterSpacing: 0.5,
      )),
    );
  }
}

// ── JOB TYPE BADGE ────────────────────────────────────────────
class JobTypeBadge extends StatelessWidget {
  final String type;
  const JobTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1),
      ),
      child: Text(type.replaceAll('_', ' '), style: const TextStyle(
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
        fontSize: 10, color: AppTheme.accentLight, letterSpacing: 0.5,
      )),
    );
  }
}

// ── APP BAR ───────────────────────────────────────────────────
class BrutalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBorder;

  const BrutalAppBar({super.key, required this.title, this.actions, this.leading, this.showBorder = true});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) => Container(
    decoration: showBorder
        ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.bgMuted, width: 1)))
        : null,
    child: AppBar(
      backgroundColor: AppTheme.bg,
      elevation: 0,
      leading: leading,
      title: Text(title, style: const TextStyle(
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
        fontSize: 22, color: AppTheme.text, letterSpacing: -0.5,
      )),
      actions: actions,
    ),
  );
}

// ── SHIMMER ───────────────────────────────────────────────────
class BrutalShimmer extends StatefulWidget {
  final double height;
  final double? width;
  const BrutalShimmer({super.key, required this.height, this.width});

  @override
  State<BrutalShimmer> createState() => _BrutalShimmerState();
}

class _BrutalShimmerState extends State<BrutalShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [AppTheme.bgCard, AppTheme.bgElevated, AppTheme.bgCard],
          ),
        ),
      ),
    );
  }
}

// ── ERROR ─────────────────────────────────────────────────────
class BrutalError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const BrutalError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: BrutalCard(
        color: AppTheme.rose.withOpacity(0.1) as Color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.rose),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
              fontSize: 14, color: AppTheme.text,
            )),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              BrutalButton(label: 'RETRY', onPressed: onRetry),
            ],
          ],
        ),
      ),
    ),
  );
}

// ── GLOW CONTAINER (ambient glow decoration) ──────────────────
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const GlowContainer({super.key, required this.child, this.color = AppTheme.accent, this.radius = 80});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Align(
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.25), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
