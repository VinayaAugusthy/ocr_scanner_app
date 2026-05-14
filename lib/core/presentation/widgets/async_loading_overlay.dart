import 'package:flutter/material.dart';

class AsyncLoadingOverlay extends StatelessWidget {
  const AsyncLoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
  });

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (loading)
          Positioned.fill(
            child: AbsorbPointer(
              child: const ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}
