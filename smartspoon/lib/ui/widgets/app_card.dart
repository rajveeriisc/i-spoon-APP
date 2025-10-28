import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.padding,
    this.gradient,
    this.color,
    this.child,
    this.constraints,
  });

  final EdgeInsets? padding;
  final Gradient? gradient;
  final Color? color;
  final Widget? child;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      constraints: constraints,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withAlpha(100)
                : Colors.grey.withAlpha(30),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
