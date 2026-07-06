import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

class ProfileLoading extends StatelessWidget {
  const ProfileLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
      children: const <Widget>[
        PrismSkeleton(height: 88),
        SizedBox(height: 16),
        PrismSkeleton(height: 96),
        SizedBox(height: 24),
        PrismSkeleton(width: 120, height: 20),
        SizedBox(height: 12),
        PrismSkeleton(height: 90),
      ],
    );
  }
}
