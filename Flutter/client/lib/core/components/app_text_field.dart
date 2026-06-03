import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// AppTextField – egységes beviteli mező
// ============================================================

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
    this.onChanged,
    this.errorText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label.copyWith(
          color: AppColors.onSurface.withValues(alpha: 0.7),
        )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          maxLines: maxLines,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
          onChanged: onChanged,
          onSubmitted: nextFocusNode != null
              ? (_) => nextFocusNode!.requestFocus()
              : null,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18,
                    color: AppColors.onSurface.withValues(alpha: 0.45))
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
