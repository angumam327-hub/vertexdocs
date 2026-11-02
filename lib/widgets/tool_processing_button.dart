import 'package:flutter/material.dart';
import 'gradient_button.dart';

class ToolProcessingButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const ToolProcessingButton({
    super.key,
    required this.text,
    this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GradientButton(
          text: text,
          icon: icon,
          isLoading: isLoading,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
